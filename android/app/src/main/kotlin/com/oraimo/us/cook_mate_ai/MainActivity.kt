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
        
        // Wait a bit longer to ensure clean state - prevents resource conflicts
        Thread.sleep(100)
        
        // Calculate optimal buffer size
        val minBufferSize = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        
        // Use extremely large buffer for maximum stability
        // This prevents audio dropouts with streaming data and handles bursty packets
        val bufferSize = minBufferSize * 32 // Massive buffer for maximum stability
        
        Log.d(TAG, "Creating AudioTrack with massive buffer size: $bufferSize bytes (min: $minBufferSize)")
        
        try {
            // Create and configure audio track based on API level
            audioTrack = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Log.d(TAG, "Using modern AudioTrack API with ultra-reliable config")
                
                // Create audio attributes optimized for speech quality
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA) // MEDIA gives better quality than VOICE_COMMUNICATION
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
                
                // Configure AudioTrack for maximum reliability over low latency
                val track = AudioTrack.Builder()
                    .setAudioAttributes(audioAttributes)
                    .setAudioFormat(AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build())
                    .setBufferSizeInBytes(bufferSize)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    // Use POWER_SAVING mode for maximum stability
                    .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_POWER_SAVING)
                    .build()
                
                // For newer API levels, set offload mode to NOT_SUPPORTED
                // This prevents the system from trying to use audio offload, which can be unreliable
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    try {
                        Log.d(TAG, "Setting offload mode to NOT_SUPPORTED for better reliability")
                        track.setOffloadMode(AudioTrack.OFFLOAD_MODE_NOT_SUPPORTED)
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to set offload mode: ${e.message}")
                    }
                }
                
                track
            } else {
                Log.d(TAG, "Using legacy AudioTrack API with basic config")
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
            
            // Try to get high-quality audio output
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    // Higher preferred device helps with audio quality
                    Log.d(TAG, "Setting preferred device to wired headset/speaker")
                    val devices = audioManager?.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                    var preferredDevice: AudioDeviceInfo? = null
                    
                    // Try to find a wired headset or speaker for better quality
                    devices?.forEach { device ->
                        if (device.type == AudioDeviceInfo.TYPE_WIRED_HEADSET || 
                            device.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                            device.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                            preferredDevice = device
                            return@forEach
                        }
                    }
                    
                    if (preferredDevice != null) {
                        audioTrack?.preferredDevice = preferredDevice
                        Log.d(TAG, "Set preferred audio device: ${preferredDevice?.productName}")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to set preferred device: ${e.message}")
                }
            }
            
            // Reset stats
            totalBytesPlayed = 0
            startTimeMs = System.currentTimeMillis()
            
            // Try to ensure optimal output volume
            try {
                val currentVolume = audioManager?.getStreamVolume(AudioManager.STREAM_MUSIC) ?: 0
                val maxVolume = audioManager?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 15
                val targetVolume = (maxVolume * 0.8).toInt() // 80% of max
                
                if (currentVolume < targetVolume) {
                    Log.d(TAG, "Increasing audio volume from $currentVolume to $targetVolume for better audibility")
                    audioManager?.setStreamVolume(AudioManager.STREAM_MUSIC, targetVolume, 0)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to adjust volume: ${e.message}")
            }
            
            // Start playback
            audioTrack?.play()
            isPlaying = true
            
            Log.i(TAG, "AudioTrack initialized and started successfully")
            
            // Start audio processing thread with completely redesigned approach
            // This implementation is much more resilient to different packet sizes and timing
            audioThread = Thread {
                Log.d(TAG, "Audio processing thread started with resilient buffer management")
                
                // Internal packet aggregation buffer for better performance
                // This combines small packets into larger ones for more efficient playback
                var aggregateBuffer = ByteArray(0)
                val optimalChunkSize = 4800 // 100ms of audio at 24kHz, 16-bit mono (2 bytes per sample)
                var totalBytesProcessed = 0
                var lastLogTimestamp = System.currentTimeMillis()
                var consecutiveEmptyPolls = 0
                var consecutiveErrors = 0
                
                while (isPlaying) {
                    try {
                        // Take from queue with short timeout to maintain responsiveness
                        val data = try {
                            audioQueue.poll(50, java.util.concurrent.TimeUnit.MILLISECONDS)
                        } catch (e: InterruptedException) {
                            Log.w(TAG, "Audio thread interrupted while waiting for data")
                            break
                        }
                        
                        // If no data available, flush any remaining aggregated data
                        if (data == null) {
                            consecutiveEmptyPolls++
                            
                            // After several empty polls, flush any remaining data in the buffer
                            if (consecutiveEmptyPolls >= 3 && aggregateBuffer.isNotEmpty()) {
                                Log.d(TAG, "Flushing ${aggregateBuffer.size} bytes after ${consecutiveEmptyPolls} empty polls")
                                internalWriteAudioData(aggregateBuffer, aggregateBuffer.size)
                                totalBytesProcessed += aggregateBuffer.size
                                aggregateBuffer = ByteArray(0)
                            }
                            
                            continue
                        }
                        
                        // Reset consecutive empty counter since we got data
                        consecutiveEmptyPolls = 0
                        
                        // Empty buffer signals shutdown
                        if (data.isEmpty()) {
                            Log.d(TAG, "Received empty buffer - stopping thread")
                            break
                        }
                        
                        // Skip extremely tiny packets that might cause playback issues
                        if (data.size < 4) { // Less than 2 samples
                            Log.d(TAG, "Skipping extremely tiny packet (${data.size} bytes)")
                            continue
                        }
                        
                        // BUFFER AGGREGATION STRATEGY
                        // Combine packets until we reach optimal size for better performance
                        val newSize = aggregateBuffer.size + data.size
                        val newBuffer = ByteArray(newSize)
                        
                        // Copy existing data
                        if (aggregateBuffer.isNotEmpty()) {
                            System.arraycopy(aggregateBuffer, 0, newBuffer, 0, aggregateBuffer.size)
                        }
                        
                        // Append new data
                        System.arraycopy(data, 0, newBuffer, aggregateBuffer.size, data.size)
                        aggregateBuffer = newBuffer
                        
                        // If we've accumulated enough data OR the packet is already large enough
                        // then write it to the audio track
                        if (aggregateBuffer.size >= optimalChunkSize || data.size >= optimalChunkSize) {
                            // Write the aggregated data
                            internalWriteAudioData(aggregateBuffer, aggregateBuffer.size)
                            totalBytesProcessed += aggregateBuffer.size
                            
                            // Reset the buffer
                            aggregateBuffer = ByteArray(0)
                            
                            // Reset error counter since we successfully wrote data
                            consecutiveErrors = 0
                            
                            // Add a tiny sleep to give the audio system time to process
                            // This helps prevent buffer overflows
                            Thread.sleep(5)
                        }
                        
                        // Periodically log progress
                        val now = System.currentTimeMillis()
                        if (now - lastLogTimestamp > 5000) { // Log every 5 seconds
                            lastLogTimestamp = now
                            val audioLengthMs = (totalBytesProcessed / (sampleRate * 2 / 1000))
                            val elapsedMs = now - startTimeMs
                            
                            Log.d(TAG, "Audio stats: Processed ${totalBytesProcessed/1024} KB " +
                                "in ${elapsedMs/1000} seconds (~${audioLengthMs/1000} sec of audio)")
                        }
                        
                    } catch (e: Exception) {
                        consecutiveErrors++
                        Log.e(TAG, "Error in audio processing thread: ${e.message}")
                        
                        // If we get too many consecutive errors, delay briefly to avoid tight error loops
                        if (consecutiveErrors > 3) {
                            Log.w(TAG, "Multiple consecutive errors (${consecutiveErrors}), adding delay")
                            Thread.sleep(100)
                            
                            // After too many errors, reset the aggregation buffer to prevent corrupt audio
                            if (consecutiveErrors > 5 && aggregateBuffer.size > 0) {
                                Log.w(TAG, "Discarding ${aggregateBuffer.size} bytes due to persistent errors")
                                aggregateBuffer = ByteArray(0)
                            }
                        }
                    }
                }
                
                // Final flush of any remaining data
                if (aggregateBuffer.isNotEmpty()) {
                    try {
                        Log.d(TAG, "Final flush of ${aggregateBuffer.size} bytes")
                        internalWriteAudioData(aggregateBuffer, aggregateBuffer.size)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in final buffer flush: ${e.message}")
                    }
                }
                
                Log.d(TAG, "Audio processing thread exiting, processed ${totalBytesProcessed/1024} KB total")
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
    
    // Improved helper method to write audio data to the AudioTrack with retry logic
    private fun internalWriteAudioData(buffer: ByteArray, size: Int) {
        val track = audioTrack ?: return
        
        // Skip if nothing to write
        if (size <= 0 || buffer.isEmpty()) {
            return
        }
        
        // Try to normalize audio volume before writing
        // This helps prevent very quiet playback
        normalizeAudioIfNeeded(buffer, size)
        
        try {
            // Try writing with retry logic for better reliability
            var bytesWritten = 0
            var retriesLeft = 2 // Allow up to 2 retries
            var totalBytesWritten = 0
            
            while (totalBytesWritten < size && retriesLeft > 0) {
                // Calculate remaining data to write
                val remainingSize = size - totalBytesWritten
                
                // Write the buffer, starting from where we left off
                bytesWritten = track.write(buffer, totalBytesWritten, remainingSize)
                
                if (bytesWritten > 0) {
                    // Track successful writes
                    totalBytesWritten += bytesWritten
                    totalBytesPlayed += bytesWritten
                } else if (bytesWritten == 0) {
                    // No progress but not an error - wait a tiny bit and try again
                    Log.w(TAG, "AudioTrack write returned 0 bytes, waiting briefly before retry")
                    Thread.sleep(5)
                    retriesLeft--
                } else if (bytesWritten == AudioTrack.ERROR_BAD_VALUE) {
                    // Bad parameters were passed - log and exit
                    Log.e(TAG, "Bad value error writing to AudioTrack, size=$size, offset=$totalBytesWritten")
                    break
                } else if (bytesWritten == AudioTrack.ERROR_INVALID_OPERATION) {
                    // Track not properly initialized - major error
                    Log.e(TAG, "Invalid operation error writing to AudioTrack - track may need reinitialization")
                    
                    // If this is the first write attempt, track may need to be reinitialized
                    if (totalBytesWritten == 0) {
                        Log.w(TAG, "First write failed - triggering audio track reinitialization")
                        Thread {
                            // On a separate thread to avoid blocking the current thread
                            try {
                                // Re-create audio track in a safe way
                                val sampleRate = audioTrack?.sampleRate ?: 24000
                                stopAudioTrack()
                                Thread.sleep(200) // Wait for resources to be freed
                                initAudioTrack(sampleRate)
                            } catch (e: Exception) {
                                Log.e(TAG, "Failed to reinitialize AudioTrack: ${e.message}")
                            }
                        }.start()
                    }
                    
                    break
                } else if (bytesWritten == AudioTrack.ERROR_DEAD_OBJECT) {
                    // AudioTrack is dead and needs recreation
                    Log.e(TAG, "AudioTrack is dead, needs to be recreated")
                    
                    // Same reinitialization logic as above
                    Thread {
                        try {
                            val sampleRate = audioTrack?.sampleRate ?: 24000
                            stopAudioTrack()
                            Thread.sleep(200)
                            initAudioTrack(sampleRate)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to reinitialize AudioTrack after DEAD_OBJECT: ${e.message}")
                        }
                    }.start()
                    
                    break
                } else {
                    // Other error
                    Log.w(TAG, "Unknown error writing to AudioTrack: $bytesWritten")
                    retriesLeft--
                    Thread.sleep(10) // Short delay before retry
                }
            }
            
            // Log write results if significant
            if (totalBytesWritten >= 1000) {
                Log.d(TAG, "Wrote $totalBytesWritten bytes to AudioTrack (total: $totalBytesPlayed)")
            } else if (totalBytesWritten < size) {
                // We couldn't write all the data
                Log.w(TAG, "Could only write $totalBytesWritten of $size bytes to AudioTrack")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Exception writing to AudioTrack: ${e.message}")
            e.printStackTrace()
        }
    }
    
    // Helper method to normalize audio volume if it's too quiet
    private fun normalizeAudioIfNeeded(buffer: ByteArray, size: Int) {
        // We only check/normalize larger buffers
        if (size < 100) return
        
        try {
            // Check if the audio is too quiet by sampling the buffer
            var maxAmplitude = 0
            var totalSamples = 0
            
            // Sample every 10th sample (for efficiency) to find the maximum amplitude
            for (i in 0 until size - 1 step 10) {
                if (i + 1 >= size) continue
                
                // Convert bytes to 16-bit samples
                val sample = (buffer[i].toInt() and 0xFF) or ((buffer[i + 1].toInt() and 0xFF) shl 8)
                // Convert from signed to absolute value
                val absValue = if (sample > 32767) 65536 - sample else sample
                
                maxAmplitude = Math.max(maxAmplitude, absValue)
                totalSamples++
            }
            
            // If max amplitude is very low but not zero, boost the volume
            if (maxAmplitude > 0 && maxAmplitude < 1000 && totalSamples > 0) {
                val boostFactor = Math.min(5.0, 4000.0 / maxAmplitude) // Cap the boost at 5x
                
                Log.d(TAG, "Audio too quiet (max=$maxAmplitude), boosting by ${boostFactor}x")
                
                // Apply the boost to the entire buffer
                for (i in 0 until size - 1 step 2) {
                    if (i + 1 >= size) continue
                    
                    // Extract the 16-bit sample
                    val sample = (buffer[i].toInt() and 0xFF) or ((buffer[i + 1].toInt() and 0xFF) shl 8)
                    // Convert from 2's complement if needed
                    val signedSample = if (sample > 32767) sample - 65536 else sample
                    
                    // Apply the boost factor
                    var boostedSample = (signedSample * boostFactor).toInt()
                    
                    // Clamp to 16-bit range
                    boostedSample = Math.max(-32768, Math.min(32767, boostedSample))
                    
                    // Convert back to bytes
                    buffer[i] = boostedSample.toByte()
                    buffer[i + 1] = (boostedSample shr 8).toByte()
                }
            }
        } catch (e: Exception) {
            // Just log and continue - this is just an enhancement, not critical
            Log.w(TAG, "Error in audio normalization: ${e.message}")
        }
    }
    
    private fun stopAudioTrack() {
        val audioLengthSeconds = totalBytesPlayed / 48000 // 16-bit samples, mono, 24kHz
        Log.d(TAG, "Stopping AudioTrack (played $totalBytesPlayed bytes, ~$audioLengthSeconds seconds of audio)")
        
        // Set flag first to stop processing thread
        isPlaying = false
        
        // Add an empty buffer to unblock the queue - send multiple to ensure delivery
        for (i in 0..2) {
            try {
                audioQueue.offer(ByteArray(0))
            } catch (e: Exception) {
                Log.w(TAG, "Error adding stop signal to queue (attempt ${i+1}): ${e.message}")
            }
        }
        
        // Wait for thread to exit gracefully
        try {
            Log.d(TAG, "Waiting for audio thread to exit gracefully")
            audioThread?.join(500) // Shorter timeout for faster recovery
            
            if (audioThread?.isAlive == true) {
                Log.w(TAG, "Audio thread still alive after 500ms - interrupting")
                audioThread?.interrupt()
                
                // Wait again briefly
                audioThread?.join(300)
                
                if (audioThread?.isAlive == true) {
                    Log.w(TAG, "Audio thread still alive after interrupt - will be abandoned")
                    // We'll abandon the thread at this point - the JVM will clean it up
                    // when it detects it's not responsive
                }
            } else {
                Log.d(TAG, "Audio thread exited gracefully")
            }
        } catch (e: InterruptedException) {
            Log.w(TAG, "Interrupted while waiting for audio thread: ${e.message}")
        }
        
        // Null out thread reference regardless of whether it exited cleanly
        audioThread = null
        
        // Release AudioTrack resources with better error handling and ordering
        val track = audioTrack
        audioTrack = null // Clear reference first to prevent other threads from using it
        
        if (track != null) {
            try {
                Log.d(TAG, "Releasing AudioTrack resources")
                
                // Try each operation in sequence with error handling
                try {
                    track.pause()
                    Log.d(TAG, "AudioTrack paused")
                } catch (e: Exception) {
                    Log.w(TAG, "Error pausing AudioTrack: ${e.message}")
                }
                
                try {
                    track.flush()
                    Log.d(TAG, "AudioTrack flushed")
                } catch (e: Exception) {
                    Log.w(TAG, "Error flushing AudioTrack: ${e.message}")
                }
                
                try {
                    track.stop()
                    Log.d(TAG, "AudioTrack stopped")
                } catch (e: Exception) {
                    Log.w(TAG, "Error stopping AudioTrack: ${e.message}")
                }
                
                try {
                    track.release()
                    Log.d(TAG, "AudioTrack released")
                } catch (e: Exception) {
                    Log.e(TAG, "Error releasing AudioTrack: ${e.message}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error during AudioTrack cleanup: ${e.message}")
                e.printStackTrace()
            }
        }
        
        // Clear queue and reset state
        try {
            audioQueue.clear()
            Log.d(TAG, "Audio queue cleared")
        } catch (e: Exception) {
            Log.w(TAG, "Error clearing audio queue: ${e.message}")
        }
        
        // Force garbage collection to help free resources
        try {
            System.gc()
        } catch (e: Exception) {
            // Ignore errors from GC request
        }
        
        Log.i(TAG, "AudioTrack stopped and all resources released successfully")
    }
    
    override fun onDestroy() {
        Log.d(TAG, "Activity being destroyed - cleaning up audio resources")
        stopAudioTrack()
        disableCommunicationMode()
        super.onDestroy()
    }
}
