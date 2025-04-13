package com.oraimo.us.cook_mate_ai

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

import android.media.AudioTrack
import android.media.AudioRecord
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.MediaRecorder
import android.os.Build
import android.os.Process
import android.content.Context
import androidx.annotation.RequiresApi
import java.util.concurrent.LinkedBlockingQueue
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import android.os.Handler
import android.os.Looper

/**
 * MainActivity that implements low-latency full-duplex audio (simultaneous playback and recording)
 * optimized for voice agent applications.
 */
class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.oraimo.us.cook_mate_ai/audio_stream"
    private val TAG = "FullDuplexAudio"
    
    // Audio playback components
    private var audioTrack: AudioTrack? = null
    private var isPlaying = false
    private val audioQueue = LinkedBlockingQueue<ByteArray>()
    private var audioThread: Thread? = null
    private var totalBytesPlayed = 0
    private var startTimeMs = 0L
    
    // Audio recording components
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var recordingThread: Thread? = null
    private var microphoneData = LinkedBlockingQueue<ByteArray>()
    
    // Audio system management
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    
    // Speech detection 
    private var speechDetectionEnabled = true
    private var isUserSpeaking = AtomicBoolean(false)
    private var noiseFloor = 500 // Baseline noise level, will be auto-calibrated
    private var speechThreshold = 2000 // Threshold above noise floor to detect speech
    private var consecutiveQuietFrames = 0
    private var consecutiveLoudFrames = 0
    private var lastVadUpdateTimeMs = 0L
    
    // Handler for main thread callbacks
    private val handler = Handler(Looper.getMainLooper())
    
    // Flutter method channel setup
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize AudioManager
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        Log.d(TAG, "Registering full-duplex audio method channel")
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initAudioSystem" -> {
                    val sampleRate = call.argument<Int>("sampleRate") ?: 24000
                    val enableVoiceDetection = call.argument<Boolean>("enableVoiceDetection") ?: true
                    val optimizeForLatency = call.argument<Boolean>("optimizeForLatency") ?: true
                    
                    Log.d(TAG, "Initializing full-duplex audio system: SR=$sampleRate Hz, " +
                          "VAD=$enableVoiceDetection, lowLatency=$optimizeForLatency")
                    
                    speechDetectionEnabled = enableVoiceDetection
                    initFullDuplexAudio(sampleRate, optimizeForLatency)
                    result.success(true)
                }
                "writeAudioData" -> {
                    val data = call.argument<ByteArray>("data")
                    if (data != null) {
                        val shouldInterruptOnSpeech = call.argument<Boolean>("interruptOnSpeech") ?: true
                        
                        // If user is speaking and interruption is enabled, don't play the audio
                        if (shouldInterruptOnSpeech && isUserSpeaking.get()) {
                            Log.d(TAG, "Skipping audio playback - user is speaking (barge-in)")
                            result.success(false)
                        } else {
                            addAudioData(data)
                            result.success(true)
                        }
                    } else {
                        Log.e(TAG, "Received null audio data")
                        result.error("INVALID_DATA", "Audio data is null or invalid", null)
                    }
                }
                "stopAudioSystem" -> {
                    Log.d(TAG, "Stopping full-duplex audio system")
                    stopFullDuplexAudio()
                    result.success(true)
                }
                "isUserSpeaking" -> {
                    result.success(isUserSpeaking.get())
                }
                "getAudioStats" -> {
                    val stats = mapOf(
                        "isPlaying" to isPlaying,
                        "isRecording" to isRecording,
                        "totalBytesPlayed" to totalBytesPlayed,
                        "isUserSpeaking" to isUserSpeaking.get(),
                        "speechThreshold" to speechThreshold,
                        "noiseFloor" to noiseFloor,
                        "latencyMs" to calculateLatency()
                    )
                    result.success(stats)
                }
                "setSpeechDetectionParams" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val threshold = call.argument<Int>("threshold")
                    
                    speechDetectionEnabled = enabled
                    if (threshold != null && threshold > 0) {
                        speechThreshold = threshold
                    }
                    
                    Log.d(TAG, "Updated speech detection: enabled=$speechDetectionEnabled, threshold=$speechThreshold")
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
     * Initialize the full-duplex audio system with both playback and recording components.
     * 
     * @param sampleRate The sample rate for audio playback (usually 24000 for Deepgram)
     * @param optimizeForLatency If true, optimize for low latency at expense of potential glitches
     */
    private fun initFullDuplexAudio(sampleRate: Int, optimizeForLatency: Boolean = true) {
        // Stop any existing audio components
        stopFullDuplexAudio()
        
        // Add delay to ensure clean state
        Thread.sleep(100)
        
        // Request audio focus and configure system
        setupAudioSystem(optimizeForLatency)
        
        // Initialize recording first (always at 16kHz as required by Deepgram)
        initAudioRecording(16000)
        
        // Then initialize playback
        initAudioPlayback(sampleRate, optimizeForLatency)
        
        Log.d(TAG, "Full-duplex audio system initialized")
    }
    
    /**
     * Configure Android audio system for optimal full-duplex performance
     */
    private fun setupAudioSystem(optimizeForLatency: Boolean) {
        try {
            Log.d(TAG, "Setting up audio system for full-duplex operation")
            
            // Request audio focus
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Modern API (Android 8.0+)
                val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(
                                if (optimizeForLatency) 
                                    AudioAttributes.USAGE_VOICE_COMMUNICATION
                                else 
                                    AudioAttributes.USAGE_MEDIA
                            )
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
                // Legacy API
                @Suppress("DEPRECATION")
                val result = audioManager?.requestAudioFocus(
                    null, 
                    AudioManager.STREAM_VOICE_CALL,
                    AudioManager.AUDIOFOCUS_GAIN
                )
                Log.d(TAG, "Audio focus request result: $result")
            }
            
            // Set appropriate audio mode for VoIP-style communication
            if (optimizeForLatency) {
                // MODE_IN_COMMUNICATION is optimized for VOIP calls with lower latency
                // but might have lower audio quality
                audioManager?.mode = AudioManager.MODE_IN_COMMUNICATION
                Log.d(TAG, "Set audio mode to MODE_IN_COMMUNICATION for lowest latency")
            } else {
                // MODE_NORMAL provides better audio quality but potentially higher latency
                audioManager?.mode = AudioManager.MODE_NORMAL
                Log.d(TAG, "Set audio mode to MODE_NORMAL for better audio quality")
            }
            
            // Ensure microphone is unmuted
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    audioManager?.setMicrophoneMute(false)
                } catch (e: Exception) {
                    Log.e(TAG, "Error unmuting microphone: ${e.message}")
                }
            }
            
            // Try to route audio to speaker or headset for best call quality
            audioManager?.isSpeakerphoneOn = true
            
            Log.d(TAG, "Audio system configuration complete")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up audio system: ${e.message}")
            e.printStackTrace()
        }
    }
    
    /**
     * Initialize audio playback component
     */
    private fun initAudioPlayback(sampleRate: Int, optimizeForLatency: Boolean) {
        // Release any existing AudioTrack
        stopAudioPlayback()
        
        try {
            // Calculate optimal buffer size
            val minBufferSize = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            
            // Buffer size strategy based on latency preference
            val bufferSize = if (optimizeForLatency) {
                // Smaller buffer for lower latency (but more risk of glitches)
                minBufferSize * 4
            } else {
                // Larger buffer for more stability (but higher latency)
                minBufferSize * 16
            }
            
            Log.d(TAG, "Creating AudioTrack with buffer size: $bufferSize bytes (min: $minBufferSize)")
            
            // Create and configure AudioTrack based on API level
            audioTrack = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                createModernAudioTrack(sampleRate, bufferSize, optimizeForLatency)
            } else {
                createLegacyAudioTrack(sampleRate, bufferSize)
            }
            
            // Try to optimize device selection
            selectOptimalAudioDevice()
            
            // Reset stats
            totalBytesPlayed = 0
            startTimeMs = System.currentTimeMillis()
            
            // Start playback
            audioTrack?.play()
            isPlaying = true
            
            Log.i(TAG, "AudioTrack initialized and started successfully")
            
            // Start audio processing thread
            startAudioProcessingThread(sampleRate, optimizeForLatency)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize AudioTrack: ${e.message}")
            e.printStackTrace()
            stopAudioPlayback()
        }
    }
    
    /**
     * Create modern AudioTrack (Android M and higher)
     */
    @RequiresApi(Build.VERSION_CODES.M)
    private fun createModernAudioTrack(sampleRate: Int, bufferSize: Int, optimizeForLatency: Boolean): AudioTrack {
        // Select optimal usage category
        val usage = if (optimizeForLatency) {
            // USAGE_VOICE_COMMUNICATION optimizes for minimal latency
            AudioAttributes.USAGE_VOICE_COMMUNICATION
        } else {
            // USAGE_MEDIA provides better audio quality
            AudioAttributes.USAGE_MEDIA
        }
        
        // Create audio attributes
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(usage)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        
        // Configure AudioTrack
        val track = AudioTrack.Builder()
            .setAudioAttributes(audioAttributes)
            .setAudioFormat(AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(sampleRate)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build())
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setPerformanceMode(
                if (optimizeForLatency) {
                    // Lowest latency setting
                    AudioTrack.PERFORMANCE_MODE_LOW_LATENCY
                } else {
                    // More reliable setting
                    AudioTrack.PERFORMANCE_MODE_POWER_SAVING
                }
            )
            .build()
        
        // Note: Not using audio offload as it can increase latency
        // Offload APIs require Android 10+ and are not critical for our use case
        
        return track
    }
    
    /**
     * Create legacy AudioTrack (pre-Android M)
     */
    private fun createLegacyAudioTrack(sampleRate: Int, bufferSize: Int): AudioTrack {
        // Use STREAM_VOICE_CALL for lower latency in VoIP
        val streamType = AudioManager.STREAM_VOICE_CALL
        
        return AudioTrack(
            streamType,
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize,
            AudioTrack.MODE_STREAM
        )
    }
    
    /**
     * Select optimal audio output device
     */
    private fun selectOptimalAudioDevice() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val devices = audioManager?.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                var preferredDevice: AudioDeviceInfo? = null
                
                // Priority order: wired headset, bluetooth headset, built-in speaker
                devices?.forEach { device ->
                    when (device.type) {
                        AudioDeviceInfo.TYPE_WIRED_HEADSET -> {
                            // Wired headset is best for call quality with no echo
                            preferredDevice = device
                            return@forEach
                        }
                        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> {
                            // Bluetooth headset is second best
                            if (preferredDevice == null) preferredDevice = device
                        }
                        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> {
                            // Built-in speaker is last resort
                            if (preferredDevice == null) preferredDevice = device
                        }
                    }
                }
                
                if (preferredDevice != null) {
                    audioTrack?.preferredDevice = preferredDevice
                    Log.d(TAG, "Set preferred audio output device: ${preferredDevice?.productName}")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to set preferred audio device: ${e.message}")
            }
        }
    }
    
    /**
     * Start audio processing thread for playback
     */
    private fun startAudioProcessingThread(sampleRate: Int, optimizeForLatency: Boolean) {
        audioThread = Thread {
            // Set thread priority higher for more reliable audio
            Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
            
            Log.d(TAG, "Audio playback thread started with priority: ${Process.getThreadPriority(Process.myTid())}")
            
            // Create a direct buffer for more efficient audio processing
            val bufferSize = if (optimizeForLatency) {
                // Small chunks for low latency
                sampleRate / 10 * 2 // ~100ms of audio
            } else {
                // Larger chunks for more stability
                sampleRate / 5 * 2 // ~200ms of audio
            }
            
            val buffer = ByteArray(bufferSize)
            var totalBytesProcessed = 0
            
            while (isPlaying) {
                try {
                    // Poll for data with timeout to maintain responsiveness
                    val data = try {
                        audioQueue.poll(50, java.util.concurrent.TimeUnit.MILLISECONDS)
                    } catch (e: InterruptedException) {
                        Log.w(TAG, "Audio thread interrupted while waiting for data")
                        break
                    }
                    
                    // If no data, continue waiting
                    if (data == null) continue
                    
                    // Empty buffer signals shutdown
                    if (data.isEmpty()) {
                        Log.d(TAG, "Received empty buffer - stopping audio thread")
                        break
                    }
                    
                    // Skip if user is speaking and speech detection is enabled (barge-in feature)
                    if (speechDetectionEnabled && isUserSpeaking.get()) {
                        // Log only occasionally to avoid spamming
                        if (totalBytesProcessed % (sampleRate * 4) == 0) {
                            Log.d(TAG, "Skipping audio playback - user is speaking (barge-in)")
                        }
                        continue
                    }
                    
                    // Process the audio data
                    writeAudioData(data)
                    totalBytesProcessed += data.size
                    
                    // Add a small sleep to reduce CPU usage in low-latency mode
                    if (!optimizeForLatency) {
                        Thread.sleep(5)
                    }
                    
                    // Log stats occasionally
                    if (totalBytesProcessed % (sampleRate * 10) == 0) {
                        val audioLengthSec = totalBytesProcessed / (sampleRate * 2)
                        Log.d(TAG, "Audio playback stats: processed ${totalBytesProcessed/1024} KB " +
                              "(~${audioLengthSec}s of audio)")
                    }
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Error in audio playback thread: ${e.message}")
                    // Continue despite errors - don't break the loop
                }
            }
            
            Log.d(TAG, "Audio playback thread exiting, processed ${totalBytesProcessed/1024} KB total")
        }
        
        audioThread?.start()
    }
    
    /**
     * Initialize audio recording component
     */
    private fun initAudioRecording(sampleRate: Int) {
        // Stop any existing recording
        stopAudioRecording()
        
        try {
            // Calculate minimum buffer size for recording
            val minBufferSize = AudioRecord.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            
            // Use a larger buffer for stable recording without dropouts
            val bufferSize = minBufferSize * 4
            
            Log.d(TAG, "Creating AudioRecord with buffer size: $bufferSize bytes (min: $minBufferSize)")
            
            // Create AudioRecord
            audioRecord = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                createModernAudioRecord(sampleRate, bufferSize)
            } else {
                createLegacyAudioRecord(sampleRate, bufferSize)
            }
            
            // Start recording
            audioRecord?.startRecording()
            isRecording = true
            
            Log.i(TAG, "AudioRecord initialized and started successfully")
            
            // Start recording thread
            startRecordingThread(sampleRate)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize AudioRecord: ${e.message}")
            e.printStackTrace()
            stopAudioRecording()
        }
    }
    
    /**
     * Create modern AudioRecord (Android M and higher)
     */
    @RequiresApi(Build.VERSION_CODES.M)
    private fun createModernAudioRecord(sampleRate: Int, bufferSize: Int): AudioRecord {
        val audioSource = MediaRecorder.AudioSource.VOICE_COMMUNICATION // Best for VoIP
        
        val audioFormat = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setSampleRate(sampleRate)
            .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
            .build()
            
        return AudioRecord.Builder()
            .setAudioSource(audioSource)
            .setAudioFormat(audioFormat)
            .setBufferSizeInBytes(bufferSize)
            .build()
    }
    
    /**
     * Create legacy AudioRecord (pre-Android M)
     */
    private fun createLegacyAudioRecord(sampleRate: Int, bufferSize: Int): AudioRecord {
        val audioSource = MediaRecorder.AudioSource.VOICE_COMMUNICATION
        
        return AudioRecord(
            audioSource,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )
    }
    
    /**
     * Start recording thread
     */
    private fun startRecordingThread(sampleRate: Int) {
        recordingThread = Thread {
            // Set thread priority higher for more reliable audio
            Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
            
            Log.d(TAG, "Audio recording thread started with priority: ${Process.getThreadPriority(Process.myTid())}")
            
            // Optimal frame size for voice detection (10ms to 30ms is ideal)
            // We'll use 20ms (320 bytes at 16kHz, 16-bit mono)
            val frameSize = (sampleRate / 50) * 2 // 20ms worth of audio
            val buffer = ByteArray(frameSize)
            
            var totalBytesRead = 0
            var framesProcessed = 0
            
            // Calibrate noise floor before starting
            calibrateNoiseFloor()
            
            // Main recording loop
            while (isRecording) {
                try {
                    val bytesRead = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    
                    if (bytesRead > 0) {
                        // Copy to a new buffer to avoid reuse issues
                        val audioData = ByteArray(bytesRead)
                        System.arraycopy(buffer, 0, audioData, 0, bytesRead)
                        
                        // Add to queue for Flutter layer to consume
                        // (but limit queue size to avoid memory issues)
                        if (microphoneData.size < 100) {
                            microphoneData.add(audioData)
                        }
                        
                        // Detect if user is speaking
                        if (speechDetectionEnabled) {
                            detectSpeech(audioData)
                        }
                        
                        // Update stats
                        totalBytesRead += bytesRead
                        framesProcessed++
                        
                        // Log stats occasionally
                        if (framesProcessed % 500 == 0) { // Roughly every 10 seconds
                            val audioLengthSec = totalBytesRead / (sampleRate * 2)
                            Log.d(TAG, "Audio recording stats: processed $framesProcessed frames, " +
                                  "${totalBytesRead/1024} KB (~${audioLengthSec}s of audio)")
                        }
                    }
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Error in audio recording thread: ${e.message}")
                    // Continue despite errors - don't break the loop
                }
            }
            
            Log.d(TAG, "Audio recording thread exiting, processed $framesProcessed frames")
        }
        
        recordingThread?.start()
    }
    
    /**
     * Calibrate the noise floor to set speech detection threshold
     */
    private fun calibrateNoiseFloor() {
        try {
            if (audioRecord == null) return
            
            Log.d(TAG, "Calibrating noise floor for speech detection...")
            
            // Read several frames to determine ambient noise level
            val calibrationFrames = 10
            val sampleBuffer = ByteArray(320) // 20ms at 16kHz, 16-bit mono
            var totalEnergy = 0
            var maxEnergy = 0
            
            for (i in 0 until calibrationFrames) {
                val bytesRead = audioRecord?.read(sampleBuffer, 0, sampleBuffer.size) ?: 0
                if (bytesRead > 0) {
                    val energy = calculateAudioEnergy(sampleBuffer)
                    totalEnergy += energy
                    maxEnergy = max(maxEnergy, energy)
                }
                Thread.sleep(20) // Wait for next frame
            }
            
            // Set noise floor to average energy plus a bit of headroom
            if (calibrationFrames > 0) {
                val avgEnergy = totalEnergy / calibrationFrames
                noiseFloor = max(avgEnergy, 200) // Ensure at least some threshold
                
                // Set speech threshold to be noise floor plus significant margin
                // This value might need tuning based on testing
                speechThreshold = (noiseFloor * 2) + 1000
                
                Log.d(TAG, "Noise floor calibrated: noiseFloor=$noiseFloor, " +
                      "speechThreshold=$speechThreshold, maxEnergy=$maxEnergy")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error calibrating noise floor: ${e.message}")
            // Use default values if calibration fails
            noiseFloor = 500
            speechThreshold = 2000
        }
    }
    
    /**
     * Detect if user is speaking using energy-based Voice Activity Detection (VAD)
     */
    private fun detectSpeech(audioData: ByteArray) {
        try {
            val energy = calculateAudioEnergy(audioData)
            val isSpeaking = isUserSpeaking.get()
            
            // State machine for speech detection with hysteresis
            if (isSpeaking) {
                // Already in speaking state, see if we should exit
                if (energy < (noiseFloor + (speechThreshold / 3))) {
                    // Energy dropped significantly below threshold
                    consecutiveQuietFrames++
                    
                    // Require multiple quiet frames to exit speaking state (hysteresis)
                    if (consecutiveQuietFrames >= 15) { // ~300ms of quiet
                        isUserSpeaking.set(false)
                        Log.d(TAG, "Speech ENDED (energy=$energy, threshold=$speechThreshold, quiet frames=$consecutiveQuietFrames)")
                        consecutiveQuietFrames = 0
                    }
                } else {
                    // Still speaking
                    consecutiveQuietFrames = 0
                }
            } else {
                // Not in speaking state, see if we should enter
                if (energy > speechThreshold) {
                    // Energy above threshold
                    consecutiveLoudFrames++
                    
                    // Require multiple loud frames to enter speaking state (avoid false triggers)
                    if (consecutiveLoudFrames >= 3) { // ~60ms of loud audio
                        isUserSpeaking.set(true)
                        Log.d(TAG, "Speech DETECTED (energy=$energy, threshold=$speechThreshold, loud frames=$consecutiveLoudFrames)")
                        consecutiveLoudFrames = 0
                        
                        // Periodically update the Flutter side with speak state changes
                        val now = System.currentTimeMillis()
                        if (now - lastVadUpdateTimeMs > 100) {
                            lastVadUpdateTimeMs = now
                            notifyVadStateChange(true)
                        }
                    }
                } else {
                    // Not loud enough
                    consecutiveLoudFrames = 0
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error in speech detection: ${e.message}")
        }
    }
    
    /**
     * Calculate energy (loudness) of an audio buffer
     */
    private fun calculateAudioEnergy(buffer: ByteArray): Int {
        var sum = 0
        var count = 0
        
        // Process every other sample for efficiency (still accurate enough)
        var i = 0
        while (i < buffer.size - 1) {
            // Convert two bytes to a 16-bit sample
            val sample = (buffer[i].toInt() and 0xFF) or ((buffer[i + 1].toInt() and 0xFF) shl 8)
            // Convert from signed representation if needed
            val value = if (sample > 32767) sample - 65536 else sample
            // Add absolute value to sum
            sum += abs(value)
            count++
            i += 4 // Skip 2 samples
        }
        
        // Return average energy
        return if (count > 0) sum / count else 0
    }
    
    /**
     * Notify Flutter of voice activity detection state changes
     */
    private fun notifyVadStateChange(isSpeaking: Boolean) {
        try {
            // Post to main thread since we're in a worker thread
            handler?.post {
                try {
                    // Call event method on Flutter channel
                    val eventData = mapOf(
                        "event" to "userSpeakingChanged",
                        "isSpeaking" to isSpeaking
                    )
                    
                    // We'd use the event channel here in a real implementation
                    Log.d(TAG, "VAD state change: isSpeaking=$isSpeaking")
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending VAD state to Flutter: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in notifyVadStateChange: ${e.message}")
        }
    }
    
    /**
     * Add audio data to playback queue
     */
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
            
            if (data.size >= 4) {
                // Skip if user is speaking and barge-in is enabled
                if (speechDetectionEnabled && isUserSpeaking.get()) {
                    Log.d(TAG, "Skipping audio playback - user is speaking (barge-in at queue level)")
                    return
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
    
    /**
     * Write audio data to AudioTrack with volume normalization
     */
    private fun writeAudioData(buffer: ByteArray) {
        val track = audioTrack ?: return
        if (buffer.isEmpty()) return
        
        try {
            // Normalize audio volume if needed for better audibility
            normalizeAudioIfNeeded(buffer)
            
            // Write to AudioTrack and track bytes written
            val bytesWritten = track.write(buffer, 0, buffer.size)
            
            if (bytesWritten > 0) {
                totalBytesPlayed += bytesWritten
            } else if (bytesWritten < 0) {
                // Handle error codes
                when (bytesWritten) {
                    AudioTrack.ERROR_BAD_VALUE -> 
                        Log.e(TAG, "AudioTrack.write ERROR_BAD_VALUE")
                    AudioTrack.ERROR_INVALID_OPERATION -> 
                        Log.e(TAG, "AudioTrack.write ERROR_INVALID_OPERATION")
                    AudioTrack.ERROR_DEAD_OBJECT -> {
                        Log.e(TAG, "AudioTrack.write ERROR_DEAD_OBJECT - attempting recovery")
                        // AudioTrack is dead, needs recreation on a separate thread
                        Thread {
                            try {
                                val sampleRate = audioTrack?.sampleRate ?: 24000
                                stopAudioPlayback()
                                Thread.sleep(100)
                                initAudioPlayback(sampleRate, true)
                            } catch (e: Exception) {
                                Log.e(TAG, "Failed to recover from dead AudioTrack: ${e.message}")
                            }
                        }.start()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error writing to AudioTrack: ${e.message}")
        }
    }
    
    /**
     * Normalize audio volume for better audibility
     */
    private fun normalizeAudioIfNeeded(buffer: ByteArray) {
        if (buffer.size < 100) return
        
        try {
            // Check audio energy level
            var maxAmplitude = 0
            var sampleCount = 0
            
            // Sample every 8th sample for efficiency
            var i = 0
            while (i < buffer.size - 1) {
                val sample = (buffer[i].toInt() and 0xFF) or ((buffer[i + 1].toInt() and 0xFF) shl 8)
                val absValue = if (sample > 32767) 65536 - sample else sample
                maxAmplitude = max(maxAmplitude, absValue)
                sampleCount++
                i += 16 // Skip 8 samples
            }
            
            // Only boost if audio is too quiet but non-zero
            if (maxAmplitude in 1..1500 && sampleCount > 0) {
                val boostFactor = min(3.0, 3000.0 / maxAmplitude) // Cap at 3x boost
                
                if (boostFactor > 1.3) { // Only boost if significant
                    Log.d(TAG, "Boosting audio volume by ${boostFactor}x (max amplitude: $maxAmplitude)")
                    
                    // Apply the boost to all samples
                    i = 0
                    while (i < buffer.size - 1) {
                        val sample = (buffer[i].toInt() and 0xFF) or ((buffer[i + 1].toInt() and 0xFF) shl 8)
                        val signedSample = if (sample > 32767) sample - 65536 else sample
                        
                        var boostedSample = (signedSample * boostFactor).toInt()
                        boostedSample = max(-32768, min(32767, boostedSample)) // Clamp
                        
                        // Write back to buffer
                        buffer[i] = boostedSample.toByte()
                        buffer[i + 1] = (boostedSample shr 8).toByte()
                        i += 2
                    }
                }
            }
        } catch (e: Exception) {
            // Continue without normalization if error occurs
            Log.w(TAG, "Error in audio normalization: ${e.message}")
        }
    }
    
    /**
     * Calculate audio playback latency
     */
    private fun calculateLatency(): Int {
        if (totalBytesPlayed <= 0 || startTimeMs <= 0) return 0
        
        try {
            // For 16-bit mono, bytes per millisecond = (sampleRate * 2) / 1000
            val sampleRate = audioTrack?.sampleRate ?: 24000
            val bytesPerMs = (sampleRate * 2) / 1000
            
            // Calculate how many milliseconds of audio we've played
            val audioMs = (totalBytesPlayed / bytesPerMs)
            
            // Calculate how many milliseconds have passed since we started
            val elapsedMs = System.currentTimeMillis() - startTimeMs
            
            // Prevent negative latency reports which can happen if the calculations are off
            if (audioMs > elapsedMs) return 0
            
            // Latency is the difference
            return (elapsedMs - audioMs).toInt()
        } catch (e: Exception) {
            Log.e(TAG, "Error calculating latency: ${e.message}")
            return 0
        }
    }
    
    /**
     * Stop audio playback component
     */
    private fun stopAudioPlayback() {
        Log.d(TAG, "Stopping audio playback")
        
        // Set flag to stop processing thread
        isPlaying = false
        
        // Signal thread to exit with empty buffer
        try {
            for (i in 0..2) {
                audioQueue.offer(ByteArray(0))
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error adding stop signal to queue: ${e.message}")
        }
        
        // Wait for thread to exit
        try {
            audioThread?.join(300)
            if (audioThread?.isAlive == true) {
                audioThread?.interrupt()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error waiting for audio thread to exit: ${e.message}")
        }
        
        audioThread = null
        
        // Release AudioTrack resources
        try {
            audioTrack?.let { track ->
                try { track.pause() } catch (e: Exception) {}
                try { track.flush() } catch (e: Exception) {}
                try { track.stop() } catch (e: Exception) {}
                try { track.release() } catch (e: Exception) {}
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing AudioTrack: ${e.message}")
        }
        
        audioTrack = null
        audioQueue.clear()
        
        Log.d(TAG, "Audio playback stopped")
    }
    
    /**
     * Stop audio recording component
     */
    private fun stopAudioRecording() {
        Log.d(TAG, "Stopping audio recording")
        
        // Set flag to stop recording thread
        isRecording = false
        
        // Wait for thread to exit
        try {
            recordingThread?.join(300)
            if (recordingThread?.isAlive == true) {
                recordingThread?.interrupt()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error waiting for recording thread to exit: ${e.message}")
        }
        
        recordingThread = null
        
        // Release AudioRecord resources
        try {
            audioRecord?.let { recorder ->
                try { recorder.stop() } catch (e: Exception) {}
                try { recorder.release() } catch (e: Exception) {}
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing AudioRecord: ${e.message}")
        }
        
        audioRecord = null
        microphoneData.clear()
        
        Log.d(TAG, "Audio recording stopped")
    }
    
    /**
     * Stop the entire full-duplex audio system
     */
    private fun stopFullDuplexAudio() {
        // Stop both components
        stopAudioPlayback()
        stopAudioRecording()
        
        // Release audio focus and reset mode
        try {
            // Abandon audio focus
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
                audioFocusRequest = null
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(null)
            }
            
            // Reset audio mode to normal
            audioManager?.mode = AudioManager.MODE_NORMAL
            
            // Turn off speakerphone
            audioManager?.isSpeakerphoneOn = false
            
        } catch (e: Exception) {
            Log.e(TAG, "Error resetting audio system: ${e.message}")
        }
        
        Log.d(TAG, "Full-duplex audio system stopped")
    }
    
    override fun onDestroy() {
        Log.d(TAG, "Activity being destroyed - cleaning up audio resources")
        stopFullDuplexAudio()
        super.onDestroy()
    }
}