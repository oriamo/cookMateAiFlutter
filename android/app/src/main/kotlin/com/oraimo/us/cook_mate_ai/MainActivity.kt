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
     * This configures the audio system similar to a phone call
     */
    private fun enableCommunicationMode() {
        Log.d(TAG, "Enabling communication mode")
        
        try {
            // Request audio focus for communication
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
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
                    AudioManager.STREAM_VOICE_CALL,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
                )
                Log.d(TAG, "Audio focus request result: $result")
            }
            
            // Turn on speakerphone to enable AEC
            audioManager?.mode = AudioManager.MODE_IN_COMMUNICATION
            audioManager?.isSpeakerphoneOn = true
            isSpeakerphoneOn = true
            
            // Check if we successfully entered communication mode
            val currentMode = audioManager?.mode
            Log.d(TAG, "Current audio mode: $currentMode (MODE_IN_COMMUNICATION=${AudioManager.MODE_IN_COMMUNICATION})")
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
        
        // Use a larger buffer for stability
        val bufferSize = minBufferSize * 2
        
        Log.d(TAG, "Creating AudioTrack with buffer size: $bufferSize bytes (min: $minBufferSize)")
        
        try {
            audioTrack = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Log.d(TAG, "Using modern AudioTrack API with low latency mode")
                
                // Create audio attributes for communication
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
                
                AudioTrack.Builder()
                    .setAudioAttributes(audioAttributes)
                    .setAudioFormat(AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build())
                    .setBufferSizeInBytes(bufferSize)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                    .build()
            } else {
                Log.d(TAG, "Using legacy AudioTrack API")
                // Use STREAM_VOICE_CALL instead of STREAM_MUSIC for communication mode
                val streamType = if (isSpeakerphoneOn) {
                    AudioManager.STREAM_VOICE_CALL
                } else {
                    AudioManager.STREAM_MUSIC
                }
                
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
                
                while (isPlaying) {
                    try {
                        val data = audioQueue.take()
                        
                        if (data.isEmpty()) {
                            Log.d(TAG, "Received empty buffer - stopping thread")
                            break
                        }
                        
                        val bytesWritten = audioTrack?.write(data, 0, data.size) ?: 0
                        
                        if (bytesWritten > 0) {
                            totalBytesPlayed += bytesWritten
                            Log.v(TAG, "Wrote $bytesWritten bytes to AudioTrack (total: $totalBytesPlayed)")
                        } else {
                            Log.w(TAG, "Failed to write data to AudioTrack: $bytesWritten")
                        }
                        
                    } catch (e: InterruptedException) {
                        Log.w(TAG, "Audio thread interrupted: ${e.message}")
                        break
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in audio processing thread: ${e.message}")
                        e.printStackTrace()
                    }
                }
                
                Log.d(TAG, "Audio processing thread exiting")
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
            // Check if we need to convert PCM format
            // Deepgram sends 16-bit PCM, which is what AudioTrack expects
            audioQueue.add(data)
        } catch (e: Exception) {
            Log.e(TAG, "Error adding audio data to queue: ${e.message}")
        }
    }
    
    private fun calculateLatency(): Int {
        if (totalBytesPlayed <= 0 || startTimeMs <= 0) return 0
        
        // Calculate how many milliseconds of audio we've played
        // 16-bit mono = 2 bytes per sample at 24kHz
        val audioMs = (totalBytesPlayed / 2) * 1000 / 24000
        
        // Calculate how many milliseconds have passed since we started
        val elapsedMs = System.currentTimeMillis() - startTimeMs
        
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
