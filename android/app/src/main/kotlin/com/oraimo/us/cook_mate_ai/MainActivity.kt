package com.oraimo.us.cook_mate_ai

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

import android.media.AudioTrack
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioRouting
import android.media.AudioRecordingConfiguration
import android.os.Build
import android.content.Context
import java.util.concurrent.LinkedBlockingQueue
import java.nio.ByteBuffer
import java.nio.ByteOrder

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.oraimo.us.cook_mate_ai/audio_stream"
    private val TAG = "NativeAudioStream"
    private var audioTrack: AudioTrack? = null
    private var isPlaying = false
    private val audioQueue = LinkedBlockingQueue<ByteArray>()
    private var audioThread: Thread? = null
    private var totalBytesPlayed = 0
    private var startTimeMs = 0L
    private var audioManager: AudioManager? = null
    private var isSpeakerphoneOn = false
    private var audioFocusRequest: AudioFocusRequest? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize AudioManager
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        Log.d(TAG, "Registering audio streaming method channel")
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initAudioStream" -> {
                    val sampleRate = call.argument<Int>("sampleRate") ?: 24000
                    val enableCommunicationMode = call.argument<Boolean>("enableCommunicationMode") ?: false
                    Log.d(TAG, "Initializing audio stream with sample rate: $sampleRate Hz, communication mode: $enableCommunicationMode")
                    
                    if (enableCommunicationMode) {
                        enableCommunicationMode()
                    }
                    
                    initAudioTrack(sampleRate)
                    result.success(true)
                }
                "writeAudioData" -> {
                    val data = call.argument<ByteArray>("data")
                    if (data != null) {
                        Log.v(TAG, "Received audio data: ${data.size} bytes")
                        addAudioData(data)
                        result.success(true)
                    } else {
                        Log.e(TAG, "Received null audio data")
                        result.error("INVALID_DATA", "Audio data is null or invalid", null)
                    }
                }
                "stopAudioStream" -> {
                    Log.d(TAG, "Stopping audio stream")
                    stopAudioTrack()
                    disableCommunicationMode()
                    result.success(true)
                }
                "getAudioStats" -> {
                    val stats = mapOf(
                        "isPlaying" to isPlaying,
                        "totalBytesPlayed" to totalBytesPlayed,
                        "latencyMs" to calculateLatency()
                    )
                    result.success(stats)
                }
                "enableCommunicationMode" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    if (enabled) {
                        enableCommunicationMode()
                    } else {
                        disableCommunicationMode()
                    }
                    result.success(true)
                }
                else -> {
                    Log.w(TAG, "Method not implemented: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }
    
    /**
     * Enable communication mode for simultaneous playback and recording
     * This configures the audio system for full-duplex audio, similar to a phone call,
     * but with optimizations for better audio quality
     */
    private fun enableCommunicationMode() {
        Log.d(TAG, "Enabling communication mode for full-duplex audio")
        
        try {
            // Request audio focus for communication
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            // Still use MEDIA for better audio quality but enable full duplex
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
                    .setAcceptsDelayedFocusGain(true)
                    .setOnAudioFocusChangeListener { focusChange ->
                        Log.d(TAG, "Audio focus changed: $focusChange")
                    }
                    .build()
                
                audioFocusRequest = focusRequest
                val result = audioManager?.requestAudioFocus(focusRequest)
                Log.d(TAG, "Audio focus request result: $result")
            } else {
                @Suppress("DEPRECATION")
                val result = audioManager?.requestAudioFocus(
                    null, 
                    // Use STREAM_MUSIC instead of STREAM_VOICE_CALL for better quality
                    AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN
                )
                Log.d(TAG, "Audio focus request result: $result")
            }
            
            // Set audio mode for simultaneous recording and playback
            // MODE_IN_COMMUNICATION enables echo cancellation but lowers quality
            // For better audio quality with continuous recording, we'll use a hybrid approach
            audioManager?.mode = AudioManager.MODE_NORMAL
            
            // On devices with good AEC, we can use speakerphone mode
            // but we'll disable it if audio quality suffers
            audioManager?.isSpeakerphoneOn = true
            isSpeakerphoneOn = true
            
            // Set the microphone mode for continuous recording
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    audioManager?.setMicrophoneMute(false)
                } catch (e: Exception) {
                    Log.e(TAG, "Error unmuting microphone: ${e.message}")
                }
            }
            
            // Enable AEC (Acoustic Echo Cancellation) if available
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try {
                    audioManager?.getProperty(AudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED)
                    Log.d(TAG, "Device supports unprocessed audio source")
                } catch (e: Exception) {
                    Log.e(TAG, "Error checking audio properties: ${e.message}")
                }
            }
            
            // Check if we successfully configured audio
            val currentMode = audioManager?.mode
            Log.d(TAG, "Current audio mode: $currentMode (MODE_NORMAL=${AudioManager.MODE_NORMAL})")
            Log.d(TAG, "Speakerphone on: ${audioManager?.isSpeakerphoneOn}")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error enabling communication mode: ${e.message}")
            e.printStackTrace()
        }
    }
    
    /**
     * Disable communication mode and return to normal audio mode
     */
    private fun disableCommunicationMode() {
        Log.d(TAG, "Disabling communication mode")
        
        try {
            // Abandon audio focus
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
                audioFocusRequest = null
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(null)
            }
            
            // Turn off speakerphone
            if (isSpeakerphoneOn) {
                audioManager?.isSpeakerphoneOn = false
                isSpeakerphoneOn = false
            }
            
            // Return to normal mode
            audioManager?.mode = AudioManager.MODE_NORMAL
            
            Log.d(TAG, "Current audio mode: ${audioManager?.mode} (MODE_NORMAL=${AudioManager.MODE_NORMAL})")
            Log.d(TAG, "Speakerphone on: ${audioManager?.isSpeakerphoneOn}")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error disabling communication mode: ${e.message}")
            e.printStackTrace()
        }
    }
    
    private fun initAudioTrack(sampleRate: Int) {
        // Release any existing AudioTrack
        stopAudioTrack()
        
        // Calculate optimal buffer size
        val minBufferSize = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        
        // Use a MUCH larger buffer for stability
        // This is critical to prevent audio dropouts with streaming data
        val bufferSize = minBufferSize * 8
        
        Log.d(TAG, "Creating AudioTrack with buffer size: $bufferSize bytes (min: $minBufferSize)")
        
        try {
            audioTrack = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Log.d(TAG, "Using modern AudioTrack API")
                
                // Create audio attributes optimized for voice playback
                // For full-duplex mode, we need a balanced configuration
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
                
                // Configure AudioTrack for optimal full-duplex performance
                val track = AudioTrack.Builder()
                    .setAudioAttributes(audioAttributes)
                    .setAudioFormat(AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build())
                    .setBufferSizeInBytes(bufferSize)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    // Balance between latency and stability
                    .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                    .build()
                
                // Set the allowed deep buffer duration if available
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    try {
                        track.setAllowedDeepBufferingSuspendMs(500)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error setting deep buffering: ${e.message}")
                    }
                }
                
                track
            } else {
                Log.d(TAG, "Using legacy AudioTrack API")
                // Always use STREAM_MUSIC for consistent audio quality
                val streamType = AudioManager.STREAM_MUSIC
                
                AudioTrack(
                    streamType,
                    sampleRate,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize,
                    AudioTrack.MODE_STREAM
                )
            }
            
            // Reset stats
            totalBytesPlayed = 0
            startTimeMs = System.currentTimeMillis()
            
            // Start playback
            audioTrack?.play()
            isPlaying = true
            
            Log.i(TAG, "AudioTrack initialized and started successfully")
            
            // Start audio processing thread
            audioThread = Thread {
                Log.d(TAG, "Audio processing thread started")
                
                // Create a buffer to collect small audio chunks
                val accumulatedBuffer = ByteArray(24000) // 0.5 second buffer at 24kHz, 16-bit mono
                var accumulatedSize = 0
                val minWriteSize = 3200 // About 1/15th of a second, good compromise for responsiveness

                while (isPlaying) {
                    try {
                        // Take from queue with timeout to allow clean shutdown
                        val data = try {
                            audioQueue.poll(500, java.util.concurrent.TimeUnit.MILLISECONDS) ?: continue
                        } catch (e: InterruptedException) {
                            Log.w(TAG, "Audio thread interrupted while waiting for data")
                            break
                        }
                        
                        if (data.isEmpty()) {
                            Log.d(TAG, "Received empty buffer - stopping thread")
                            break
                        }
                        
                        // Process the data - we have two strategies:
                        // 1. If we get a large chunk, write it directly
                        // 2. For small chunks, collect them until we have enough to write
                        
                        if (data.size >= minWriteSize) {
                            // Write any accumulated data first
                            if (accumulatedSize > 0) {
                                writeAudioData(accumulatedBuffer, accumulatedSize)
                                accumulatedSize = 0
                            }
                            
                            // Then write this larger chunk directly
                            writeAudioData(data, data.size)
                            
                        } else {
                            // If adding this data would overflow our buffer, write what we have first
                            if (accumulatedSize + data.size > accumulatedBuffer.size) {
                                writeAudioData(accumulatedBuffer, accumulatedSize)
                                accumulatedSize = 0
                            }
                            
                            // Copy this chunk into our accumulated buffer
                            System.arraycopy(data, 0, accumulatedBuffer, accumulatedSize, data.size)
                            accumulatedSize += data.size
                            
                            // If we've collected enough data, write it now
                            if (accumulatedSize >= minWriteSize) {
                                writeAudioData(accumulatedBuffer, accumulatedSize)
                                accumulatedSize = 0
                            }
                        }
                        
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in audio processing thread: ${e.message}")
                        e.printStackTrace()
                    }
                }
                
                // Write any remaining accumulated data before exiting
                if (accumulatedSize > 0) {
                    try {
                        writeAudioData(accumulatedBuffer, accumulatedSize)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error writing final audio buffer: ${e.message}")
                    }
                }
                
                Log.d(TAG, "Audio processing thread exiting")
            }
            
            // Helper function to write to AudioTrack
            fun writeAudioData(buffer: ByteArray, size: Int) {
                val track = audioTrack ?: return
                
                try {
                    val bytesWritten = track.write(buffer, 0, size)
                    
                    if (bytesWritten > 0) {
                        totalBytesPlayed += bytesWritten
                        if (bytesWritten >= 1000) {
                            Log.d(TAG, "Wrote $bytesWritten bytes to AudioTrack (total: $totalBytesPlayed)")
                        }
                    } else {
                        Log.w(TAG, "Failed to write data to AudioTrack: $bytesWritten")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error writing to AudioTrack: ${e.message}")
                }
            }
            
            audioThread?.start()
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize AudioTrack: ${e.message}")
            e.printStackTrace()
            stopAudioTrack()
        }
    }
    
    private fun addAudioData(data: ByteArray) {
        if (!isPlaying) {
            Log.w(TAG, "Ignoring audio data - not playing")
            return
        }
        
        try {
            // Only log large packets to reduce log noise
            if (data.size > 1000) {
                Log.d(TAG, "Adding ${data.size} bytes to audio queue")
            }
            
            // For Deepgram's audio data, make sure we have valid PCM data
            if (data.size >= 4) {
                // Validate that we have sensible data (non-zero)
                var hasNonZero = false
                for (i in 0 until minOf(20, data.size)) {
                    if (data[i].toInt() != 0) {
                        hasNonZero = true
                        break
                    }
                }
                
                if (!hasNonZero) {
                    Log.w(TAG, "Received all-zero audio data, may cause playback issues")
                }
                
                // Add the data to the queue for playback
                audioQueue.add(data)
            } else {
                Log.w(TAG, "Received very small audio packet (${data.size} bytes), ignoring")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error adding audio data to queue: ${e.message}")
        }
    }
    
    private fun calculateLatency(): Int {
        if (totalBytesPlayed <= 0 || startTimeMs <= 0) return 0
        
        // Calculate how many milliseconds of audio we've played
        // For 16-bit mono at 24kHz:
        // 24,000 samples per second, 2 bytes per sample = 48,000 bytes per second
        // 1ms = 48 bytes
        val audioMs = (totalBytesPlayed / 48)
        
        // Calculate how many milliseconds have passed since we started
        val elapsedMs = System.currentTimeMillis() - startTimeMs
        
        // Prevent negative latency reports which can happen if the calculations are off
        if (audioMs > elapsedMs) {
            Log.w(TAG, "Calculated audio duration ($audioMs ms) exceeds elapsed time ($elapsedMs ms)")
            return 0
        }
        
        // Latency is the difference
        return (elapsedMs - audioMs).toInt()
    }
    
    private fun stopAudioTrack() {
        Log.d(TAG, "Stopping AudioTrack (played $totalBytesPlayed bytes)")
        
        isPlaying = false
        
        // Add empty buffer to unblock the queue
        try {
            audioQueue.add(ByteArray(0))
        } catch (e: Exception) {
            Log.w(TAG, "Error adding stop signal to queue: ${e.message}")
        }
        
        try {
            audioThread?.join(1000)
            if (audioThread?.isAlive == true) {
                Log.w(TAG, "Audio thread did not exit cleanly - interrupting")
                audioThread?.interrupt()
            }
        } catch (e: InterruptedException) {
            Log.w(TAG, "Interrupted while waiting for audio thread: ${e.message}")
        }
        
        try {
            audioTrack?.pause()
            audioTrack?.flush()
            audioTrack?.stop()
            audioTrack?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing AudioTrack: ${e.message}")
        }
        
        audioTrack = null
        
        // Clear queue
        audioQueue.clear()
        
        Log.i(TAG, "AudioTrack stopped and resources released")
    }
    
    override fun onDestroy() {
        Log.d(TAG, "Activity being destroyed - cleaning up audio resources")
        stopAudioTrack()
        disableCommunicationMode()
        super.onDestroy()
    }
}
