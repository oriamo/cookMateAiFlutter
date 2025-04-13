package com.oraimo.us.cook_mate_ai

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

import android.media.AudioTrack
import android.media.AudioFormat
import android.media.AudioManager
import android.os.Build
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d(TAG, "Registering audio streaming method channel")
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initAudioStream" -> {
                    val sampleRate = call.argument<Int>("sampleRate") ?: 24000
                    Log.d(TAG, "Initializing audio stream with sample rate: $sampleRate Hz")
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
                else -> {
                    Log.w(TAG, "Method not implemented: ${call.method}")
                    result.notImplemented()
                }
            }
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
                AudioTrack.Builder()
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
                AudioTrack(
                    AudioManager.STREAM_MUSIC,
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
        super.onDestroy()
    }
}
