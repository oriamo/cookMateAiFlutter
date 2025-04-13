// lib/services/deepgram_agent_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

import 'llm_service.dart';
import 'deepgram_agent_types.dart';

/// Service that manages the connection to Deepgram's Voice Agent API
class DeepgramAgentService {
  // Deepgram WebSocket connection
  WebSocketChannel? _channel;
  String? _apiKey;
  bool _isConnected = false;
  bool _isInitialized = false;
  bool _isListening = false;
  
  // Connection management
  Timer? _inactivityTimer;
  Timer? _heartbeatTimer;
  Timer? _forcedAudioTimer;
  final int _inactivityTimeoutSeconds = 30;
  final int _heartbeatIntervalSeconds = 2; // Send heartbeat every 2 seconds to prevent timeout
  final int _forcedAudioIntervalMs = 250; // Send audio data every 250ms regardless of state
  bool _continuousListeningEnabled = false;
  
  // Packet tracking for debugging
  int _heartbeatCount = 0;
  int _forcedAudioCount = 0;
  int _lastHeartbeatTimestamp = 0;
  int _lastForcedAudioTimestamp = 0;
  
  // Keep track of the recorder and audio subscription
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _recordingSubscription;
  
  // Stream controllers
  final _messageController = StreamController<String>.broadcast();
  final _stateController = StreamController<DeepgramAgentState>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  
  // Current state
  DeepgramAgentState _state = DeepgramAgentState.idle;
  
  // Debug flags
  bool _verboseLogging = true; // Set to true to see all logs
  
  // LLM service for integration
  final LlmService _llmService;
  
  // Camera controller for vision capabilities
  CameraController? _cameraController;
  
  // Expose streams
  Stream<String> get onMessage => _messageController.stream;
  Stream<DeepgramAgentState> get onStateChange => _stateController.stream;
  Stream<String> get onError => _errorController.stream;
  
  // Status getters
  DeepgramAgentState get state => _state;
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isListening => _isListening;
  CameraController? get cameraController => _cameraController;
  
  // Constructor - reuses the existing LLM service for integration
  DeepgramAgentService(this._llmService);
  
  // Create a TTS engine for fallback audio playback
  final FlutterTts _tts = FlutterTts();
  
  // Native Audio Interface
  static const MethodChannel _audioChannel = MethodChannel('com.oraimo.us.cook_mate_ai/audio_stream');
  bool _isAudioStreamInitialized = false;
  
  /// Initialize the Deepgram Agent service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // Get API key from environment
      _apiKey = dotenv.env['DEEPGRAM_API_KEY'];
      if (_apiKey == null || _apiKey!.isEmpty) {
        _errorController.add('Deepgram API key not found. Please add it to .env file.');
        return false;
      }
      
      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (micStatus != PermissionStatus.granted) {
        _errorController.add('Microphone permission denied');
        return false;
      }
      
      // Initialize the LLM service if not already initialized
      final llmInitialized = await _llmService.initialize();
      if (!llmInitialized) {
        _errorController.add('Failed to initialize LLM service');
        return false;
      }
      
      // Initialize camera if available
      try {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          _cameraController = CameraController(
            cameras.first,
            ResolutionPreset.medium,
            enableAudio: false,
          );
          await _cameraController?.initialize();
        }
      } catch (e) {
        // Camera not critical, so just log the error and continue
        debugPrint('Camera initialization failed: $e');
      }
      
      // Initialize TTS as fallback
      await _initializeTts();
      
      // Initialize native audio streaming
      await _initAudioStream();
      
      _isInitialized = true;
      _updateState(DeepgramAgentState.idle);
      return true;
    } catch (e) {
      _errorController.add('Failed to initialize Deepgram Agent: $e');
      return false;
    }
  }
  
  /// Initialize native audio streaming with robust retry logic
  Future<bool> _initAudioStream() async {
    // If already initialized, return success
    if (_isAudioStreamInitialized) {
      debugPrint('🔊 DEEPGRAM: Audio stream already initialized, skipping initialization');
      return true;
    }
    
    // First try to stop any existing audio stream
    await _stopAudioStream();
    
    // Add longer delay to ensure clean state - this is critical for reliable operation
    await Future.delayed(Duration(milliseconds: 200));
    
    // Maximum number of retry attempts
    const maxRetries = 3;
    int retryCount = 0;
    bool success = false;
    
    while (!success && retryCount < maxRetries) {
      try {
        if (retryCount > 0) {
          debugPrint('🔊 DEEPGRAM: Retry #$retryCount initializing native audio stream');
          // Add increasing delay between retries
          await Future.delayed(Duration(milliseconds: 300 * retryCount));
        } else {
          debugPrint('🔊 DEEPGRAM: Initializing native audio stream with ultra-reliable settings');
        }
        
        // Use configuration that prioritizes maximum reliability
        final result = await _audioChannel.invokeMethod<bool>('initAudioStream', {
          'sampleRate': 24000, // Deepgram's output sample rate
          'enableCommunicationMode': false, // Disable communication mode for maximum compatibility
        });
        
        if (result == true) {
          _isAudioStreamInitialized = true;
          debugPrint('🟢 DEEPGRAM: Native audio stream successfully initialized on attempt ${retryCount + 1}');
          
          // Add delay after successful initialization to let the system stabilize
          await Future.delayed(Duration(milliseconds: 100));
          success = true;
        } else {
          debugPrint('🔴 DEEPGRAM: Native audio stream initialization returned false on attempt ${retryCount + 1}');
          
          // If first attempt fails, try a slightly different approach on subsequent attempts
          if (retryCount == 0) {
            // Force garbage collection to help free resources
            // ignore: empty_catches
            try { 
              debugPrint('🔵 DEEPGRAM: Requesting garbage collection to free resources');
              // On Flutter, this isn't direct but can hint to the system
              // A combination of awaits and delays can help trigger GC
              await Future.delayed(Duration(milliseconds: 50));
              Isolate.current.addOnExitListener(RawReceivePort().sendPort);
              await Future.delayed(Duration(milliseconds: 50));
            } catch (e) {}
          }
        }
      } catch (e) {
        debugPrint('🔴 DEEPGRAM: Error initializing native audio stream on attempt ${retryCount + 1}: $e');
      }
      
      retryCount++;
      
      // If we failed but have more retries, stop any existing stream first
      if (!success && retryCount < maxRetries) {
        debugPrint('🔵 DEEPGRAM: Cleaning up before retry #$retryCount');
        await _stopAudioStream();
        await Future.delayed(Duration(milliseconds: 300));
      }
    }
    
    // Final status report
    if (success) {
      // Try to get audio stats to verify everything is working
      try {
        final stats = await _getAudioStats();
        debugPrint('🟢 DEEPGRAM: Audio initialization complete, stats: $stats');
      } catch (e) {
        debugPrint('🟡 DEEPGRAM: Audio initialized but couldn\'t get stats: $e');
      }
      return true;
    } else {
      debugPrint('🔴 DEEPGRAM: All $maxRetries attempts to initialize audio failed, falling back to TTS');
      // Ensure we're in a clean state
      _isAudioStreamInitialized = false;
      await _stopAudioStream();
      
      // Return false to indicate failure
      return false;
    }
  }
  
  /// Enable or disable communication mode for simultaneous recording and playback
  Future<bool> _setCommunicationMode(bool enabled) async {
    try {
      debugPrint('🔊 DEEPGRAM: ${enabled ? "Enabling" : "Disabling"} communication mode');
      final result = await _audioChannel.invokeMethod<bool>('enableCommunicationMode', {
        'enabled': enabled,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error setting communication mode: $e');
      return false;
    }
  }
  
  /// Stop native audio streaming
  Future<bool> _stopAudioStream() async {
    if (!_isAudioStreamInitialized) return true;
    
    try {
      debugPrint('🔊 DEEPGRAM: Stopping native audio stream');
      final result = await _audioChannel.invokeMethod<bool>('stopAudioStream');
      _isAudioStreamInitialized = false;
      return result ?? true;
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error stopping native audio stream: $e');
      return false;
    }
  }
  
  /// Get native audio stream statistics
  Future<Map<String, dynamic>> _getAudioStats() async {
    if (!_isAudioStreamInitialized) {
      return {
        'isPlaying': false,
        'totalBytesPlayed': 0,
        'latencyMs': 0,
      };
    }
    
    try {
      final result = await _audioChannel.invokeMethod<Map<dynamic, dynamic>>('getAudioStats');
      return result?.cast<String, dynamic>() ?? {
        'isPlaying': false,
        'totalBytesPlayed': 0,
        'latencyMs': 0,
      };
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error getting audio stats: $e');
      return {
        'isPlaying': false,
        'totalBytesPlayed': 0,
        'latencyMs': 0,
      };
    }
  }
  
  /// Initialize Text-to-Speech engine
  Future<void> _initializeTts() async {
    debugPrint('🔵 DEEPGRAM: Initializing TTS engine');
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    _tts.setCompletionHandler(() {
      debugPrint('🔵 DEEPGRAM: TTS playback completed');
      if (_state == DeepgramAgentState.speaking) {
        _updateState(DeepgramAgentState.idle);
      }
    });
    
    debugPrint('🟢 DEEPGRAM: TTS engine initialized');
  }
  
  // Keep track of audio playback metrics
  int _totalAudioPacketsReceived = 0;
  int _totalAudioBytesReceived = 0;
  int _consecutiveAudioFailures = 0;
  int _maxConsecutiveFailures = 3; // After this many failures, we'll reinitialize
  DateTime _lastAudioReinitialization = DateTime.now();
  
  /// Handle audio data from Deepgram with robust error recovery
  /// This implementation includes advanced buffering and failure recovery strategies
  void _handleAudioData(Uint8List audioData) async {
    try {
      // Update state to indicate the agent is speaking
      _updateState(DeepgramAgentState.speaking);
      
      // Make sure the forced audio timer is running to prevent connection timeouts
      if (_forcedAudioTimer == null || !_forcedAudioTimer!.isActive) {
        _startForcedAudioTimer();
      }
      
      // Reset inactivity timer since we're actively receiving data
      _resetInactivityTimer();
      
      // Track metrics for debugging and analytics
      _totalAudioPacketsReceived++;
      _totalAudioBytesReceived += audioData.length;
      
      // Skip very small packets which cause playback issues
      if (audioData.length < 80) {
        debugPrint('🔊 DEEPGRAM: Skipping very small audio packet (${audioData.length} bytes)');
        return;
      }
      
      // Periodic logging of audio stats
      if (_totalAudioPacketsReceived % 10 == 0) {
        debugPrint('🔊 DEEPGRAM: Audio stats: received $_totalAudioPacketsReceived packets, $_totalAudioBytesReceived bytes total');
      }
      
      // INITIALIZATION LOGIC
      // Try to use native audio playback with smart retry logic
      if (!_isAudioStreamInitialized) {
        // Check if we need to throttle reinitialization attempts
        final now = DateTime.now();
        final timeSinceLastInit = now.difference(_lastAudioReinitialization);
        
        if (timeSinceLastInit.inSeconds < 5) {
          // If we've tried to initialize very recently, use TTS as fallback
          debugPrint('🟡 DEEPGRAM: Too many recent audio init attempts (${timeSinceLastInit.inMilliseconds}ms ago), throttling');
          
          // Only speak if we haven't spoken in last 2 seconds (avoid multiple messages)
          final currentTime = DateTime.now().millisecondsSinceEpoch;
          if (currentTime - _lastSpeakTime > 2000) {
            _lastSpeakTime = currentTime;
            await _tts.speak('Processing your request');
          }
          return;
        }
        
        // Attempt to initialize audio
        debugPrint('🔊 DEEPGRAM: Native audio not initialized - initializing now');
        _lastAudioReinitialization = now; // Update timestamp before attempting
        _isAudioStreamInitialized = await _initAudioStream();
        
        if (!_isAudioStreamInitialized) {
          debugPrint('🔴 DEEPGRAM: Native audio initialization failed - will use TTS for speech instead');
          
          // Only speak if we haven't spoken in last 2 seconds
          final currentTime = DateTime.now().millisecondsSinceEpoch;
          if (currentTime - _lastSpeakTime > 2000) {
            _lastSpeakTime = currentTime;
            await _tts.speak('The assistant is responding now');
          }
          return;
        } else {
          // Successfully initialized
          _consecutiveAudioFailures = 0;
          debugPrint('🟢 DEEPGRAM: Native audio successfully initialized, proceeding with playback');
        }
      }
      
      // AUDIO PLAYBACK LOGIC
      // Send audio data to native player with comprehensive error handling
      debugPrint('🔊 DEEPGRAM: Sending ${audioData.length} bytes to native audio player');
      try {
        // Add a small delay for larger packets to help with buffering
        // This is a critical optimization to prevent buffer underruns and overruns
        if (audioData.length > 800) {
          await Future.delayed(Duration(milliseconds: 8)); // Slightly longer delay for larger packets
        } else if (audioData.length > 400) {
          await Future.delayed(Duration(milliseconds: 4)); // Small delay for medium packets
        }
        
        // Send audio data to native layer
        final result = await _audioChannel.invokeMethod<bool>('writeAudioData', {
          'data': audioData,
        });
        
        if (result == true) {
          // Success - reset failure counter
          if (_consecutiveAudioFailures > 0) {
            _consecutiveAudioFailures = 0;
            debugPrint('🟢 DEEPGRAM: Audio playback recovered after previous failures');
          }
        } else {
          // The method returned false - not an exception but still a failure
          _consecutiveAudioFailures++;
          debugPrint('🟡 DEEPGRAM: Native audio write returned false (failure #$_consecutiveAudioFailures)');
          
          // Consider reinitializing after too many failures
          if (_shouldReinitializeAudio()) {
            await _reinitializeAudio();
          }
        }
      } catch (e) {
        // If sending data fails, log error and try to recover
        _consecutiveAudioFailures++;
        debugPrint('🔴 DEEPGRAM: Error sending audio data to native player: $e (failure #$_consecutiveAudioFailures)');
        
        // Check if we should reinitialize or fall back to TTS
        if (_shouldReinitializeAudio()) {
          await _reinitializeAudio();
        } else if (_consecutiveAudioFailures > 1) {
          // For multiple failures that don't trigger reinitialization,
          // still provide audio feedback with TTS
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastSpeakTime > 3000) { // Only every 3 seconds to avoid spam
            _lastSpeakTime = now;
            await _tts.speak('Still processing your request');
          }
        }
      }
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error handling audio data: $e');
      
      // Try to recover gracefully from any unhandled errors
      try {
        await Future.delayed(Duration(milliseconds: 100));
        if (_isAudioStreamInitialized && _consecutiveAudioFailures > _maxConsecutiveFailures) {
          _reinitializeAudio();
        }
      } catch (_) {}
    }
  }
  
  /// Determine if we should reinitialize the audio system
  bool _shouldReinitializeAudio() {
    // Check if we've had too many consecutive failures
    if (_consecutiveAudioFailures >= _maxConsecutiveFailures) {
      // Also check if we haven't reinitialized too recently
      final timeSinceLastInit = DateTime.now().difference(_lastAudioReinitialization);
      if (timeSinceLastInit.inSeconds >= 3) { // Throttle reinits to at most once every 3 seconds
        return true;
      }
    }
    return false;
  }
  
  /// Reinitialize the audio system after failures
  Future<void> _reinitializeAudio() async {
    debugPrint('🔵 DEEPGRAM: Reinitializing audio after $_consecutiveAudioFailures consecutive failures');
    
    // Update reinitialization timestamp
    _lastAudioReinitialization = DateTime.now();
    
    // Stop and reinitialize
    _isAudioStreamInitialized = false;
    await _stopAudioStream();
    
    // Add delay to ensure clean state
    await Future.delayed(Duration(milliseconds: 300));
    
    // Try to reinitialize
    _isAudioStreamInitialized = await _initAudioStream();
    
    // Log result
    if (_isAudioStreamInitialized) {
      debugPrint('🟢 DEEPGRAM: Audio reinitialization successful');
      _consecutiveAudioFailures = 0;
    } else {
      debugPrint('🔴 DEEPGRAM: Audio reinitialization failed, will use TTS');
      // Speak a notification
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastSpeakTime > 2000) {
        _lastSpeakTime = now;
        await _tts.speak('Processing your request');
      }
    }
  }
  
  // Track when we last spoke with TTS to avoid repeated messages
  int _lastSpeakTime = 0;
  
  /// Connect to Deepgram Voice Agent API
  Future<bool> connect() async {
    if (!_isInitialized) {
      _errorController.add('Service not initialized');
      debugPrint('🔴 DEEPGRAM: Service not initialized in connect()');
      return false;
    }
    
    debugPrint('🔵 DEEPGRAM: Attempting to connect. API key exists: ${_apiKey != null && _apiKey!.isNotEmpty}');
    debugPrint('🔵 DEEPGRAM: API key first 4 chars: ${_apiKey != null ? _apiKey!.substring(0, math.min(4, _apiKey!.length)) + "..." : "null"}');
    
    if (_isConnected) {
      // Already connected
      debugPrint('🟢 DEEPGRAM: Already connected, returning early');
      return true;
    }
    
    try {
      _updateState(DeepgramAgentState.connecting);
      debugPrint('🔵 DEEPGRAM: Changed state to connecting');
      
      // Use the correct Deepgram Voice Agent API endpoint as per documentation
      final wsUrl = 'wss://agent.deepgram.com/agent';
      debugPrint('🔵 DEEPGRAM: Attempting to connect to WebSocket: $wsUrl');
      
      // For WebSocket in Flutter, we need to use the dart:io implementation for headers
      debugPrint('🔵 DEEPGRAM: Creating WebSocket with authentication token');
      
      try {
        final socket = await WebSocket.connect(wsUrl, headers: {
          'Authorization': 'Token $_apiKey',
        });
        debugPrint('🟢 DEEPGRAM: WebSocket connected successfully');
        
        // Create channel from socket
        _channel = IOWebSocketChannel(socket);
        debugPrint('🟢 DEEPGRAM: Created IOWebSocketChannel');
        
        // Set up event listeners for the WebSocket connection
        _setupWebSocketListeners();
        debugPrint('🔵 DEEPGRAM: Set up WebSocket listeners');
        
        // Send initial settings configuration
        _sendAgentConfig();
        debugPrint('🔵 DEEPGRAM: Sent agent configuration');
        
        _isConnected = true;
        _updateState(DeepgramAgentState.connected);
        
        // Start inactivity and heartbeat timers
        _startInactivityTimer();
        _startHeartbeatTimer();
        
        // Start the forced audio timer to ensure we never timeout
        if (_continuousListeningEnabled) {
          _startForcedAudioTimer();
        }
        
        debugPrint('🟢 DEEPGRAM: Connection completed successfully, state updated to connected');
        return true;
      } catch (socketError) {
        debugPrint('🔴 DEEPGRAM: WebSocket connection error: $socketError');
        throw socketError;  // Re-throw to be caught by the outer try-catch
      }
    } catch (e) {
      final errorMsg = 'Failed to connect to Deepgram: $e';
      debugPrint('🔴 DEEPGRAM: $errorMsg');
      _errorController.add(errorMsg);
      _updateState(DeepgramAgentState.idle);
      return false;
    }
  }
  
  /// Set up listeners for WebSocket events
  void _setupWebSocketListeners() {
    if (_channel == null) {
      debugPrint('🔴 DEEPGRAM: Cannot set up listeners - channel is null');
      return;
    }
    
    debugPrint('🔵 DEEPGRAM: Setting up WebSocket listeners');
    
    // Listen for messages from Deepgram
    _channel!.stream.listen(
      (dynamic message) {
        try {
          // Reset inactivity timer since we got a message
          _resetInactivityTimer();
          
          // Check if this is a binary message (audio from the server)
          if (message is List<int>) {
            // Handle binary audio response from the agent
            debugPrint('🔵 DEEPGRAM: Received binary audio data: ${message.length} bytes');
            
            // Process audio data with native audio player
            final audioData = Uint8List.fromList(message);
            _handleAudioData(audioData);
            
            return;
          }
          
          debugPrint('🟢 DEEPGRAM: Received message: ${message.toString().substring(0, math.min(100, message.toString().length))}...');
          
          // Parse the message from Deepgram
          final Map<String, dynamic> data = json.decode(message as String);
          
          // Handle different message types from Deepgram's Voice Agent API
          if (data.containsKey('type')) {
            debugPrint('🔵 DEEPGRAM: Message type: ${data['type']}');
            
            switch (data['type']) {
              case 'ConversationText':
                // Transcribed user speech
                debugPrint('🔵 DEEPGRAM: Received conversation text');
                if (data.containsKey('content')) {
                  final transcript = data['content'] as String;
                  if (transcript.isNotEmpty) {
                    debugPrint('🟢 DEEPGRAM: Transcript: $transcript, role: ${data['role'] ?? 'unknown'}');
                    
                    // Handle both user and assistant messages
                    if (data['role'] == 'user') {
                      // User's transcribed speech
                      _handleSpeechRecognition(transcript, true);
                    } else if (data['role'] == 'assistant') {
                      // Assistant's response
                      _messageController.add(transcript);
                    }
                  }
                }
                break;
                
              case 'UserStartedSpeaking':
                // User started speaking
                debugPrint('🔊 DEEPGRAM: User started speaking event');
                _updateState(DeepgramAgentState.listening);
                
                // Reset inactivity timer since user is active
                _resetInactivityTimer();
                
                // In continuous listening mode, allow the user to interrupt the AI
                // but we'll keep audio streaming in both directions
                if (_continuousListeningEnabled) {
                  // Only log that we detected speech but don't stop audio playback
                  // This ensures continuous audio streaming while allowing barge-in
                  debugPrint('🔊 DEEPGRAM: User speaking while AI is talking (barge-in)');
                  
                  // Optional: lower the volume of the playback to make it easier to hear the user
                  // But don't stop it entirely to maintain continuous streaming
                } else {
                  // In regular mode, stop any audio playback if we're not already speaking
                  if (_state != DeepgramAgentState.speaking) {
                    _stopAudioStream();
                  }
                }
                break;
                
              case 'UserStoppedSpeaking':
                // User stopped speaking
                debugPrint('🔵 DEEPGRAM: User stopped speaking event');
                _updateState(DeepgramAgentState.processing);
                break;
                
              case 'AgentStartedSpeaking':
                // Agent started speaking
                debugPrint('🔊 DEEPGRAM: Agent started speaking event');
                _updateState(DeepgramAgentState.speaking);
                break;
                
              case 'AgentStoppedSpeaking':
                // Agent stopped speaking
                debugPrint('🔊 DEEPGRAM: Agent stopped speaking event');
                
                // Let audio finish playing naturally
                debugPrint('🔊 DEEPGRAM: Agent finished speaking, letting audio complete');
                
                // Wait a bit and check audio status
                Future.delayed(Duration(seconds: 1), () async {
                  final stats = await _getAudioStats();
                  debugPrint('🔊 DEEPGRAM: Audio stats: ${stats.toString()}');
                  
                  // Only update state if we're still in speaking mode
                  if (_state == DeepgramAgentState.speaking) {
                    if (_continuousListeningEnabled) {
                      // In continuous mode, transition back to listening
                      debugPrint('🔊 DEEPGRAM: Continuous listening active, returning to listening state');
                      _updateState(DeepgramAgentState.listening);
                      
                      // Make sure we're ready for recording again
                      if (!_isListening) {
                        _isListening = true;
                        // Restart audio streaming
                        _streamAudio();
                      }
                    } else {
                      // In regular mode, transition to connected state
                      _updateState(DeepgramAgentState.connected);
                    }
                    
                    // Reset inactivity timer to start countdown for disconnection
                    _resetInactivityTimer();
                  }
                });
                break;
                
              case 'AgentFinishedThinking':
                // When the agent has processed the user's input
                debugPrint('🔵 DEEPGRAM: Agent finished thinking event');
                if (data.containsKey('text')) {
                  final agentResponse = data['text'] as String;
                  _messageController.add(agentResponse);
                }
                break;
                
              case 'EndOfThought':
                // Mark the transition from processing to speaking
                debugPrint('🔊 DEEPGRAM: Received EndOfThought - AI finished processing');
                // Make sure we're ready for new audio
                _stopAudioStream().then((_) {
                  _initAudioStream();
                });
                break;
                
              case 'AgentAudioDone':
                // All audio has been sent
                debugPrint('🔊 DEEPGRAM: Received AgentAudioDone - Audio streaming complete');
                // Wait for playback to finish naturally
                break;
                
              case 'Error':
                // Error from Deepgram
                if (data.containsKey('description')) {
                  final errorMsg = 'Deepgram error: ${data['description']}';
                  debugPrint('🔴 DEEPGRAM: $errorMsg');
                  _errorController.add(errorMsg);
                }
                break;
                
              default:
                debugPrint('🟡 DEEPGRAM: Unknown message type: ${data['type']}');
                break;
            }
          } else {
            debugPrint('🟡 DEEPGRAM: Message doesn\'t contain type field: $data');
          }
        } catch (e) {
          debugPrint('🔴 DEEPGRAM: Error processing WebSocket message: $e');
        }
      },
      onError: (error) {
        debugPrint('🔴 DEEPGRAM: WebSocket stream error: $error');
        _errorController.add('WebSocket error: $error');
        _disconnect();
      },
      onDone: () {
        debugPrint('🔴 DEEPGRAM: WebSocket connection closed');
        _disconnect();
      },
    );
    
    debugPrint('🟢 DEEPGRAM: WebSocket listeners setup completed');
  }
  
  /// Handle speech recognition results
  void _handleSpeechRecognition(String transcript, bool isFinal) {
    debugPrint('🟢 DEEPGRAM: Handling speech transcript: "$transcript", isFinal: $isFinal');
    
    if (transcript.isEmpty) {
      debugPrint('🟡 DEEPGRAM: Empty transcript received, ignoring');
      return;
    }
    
    if (isFinal) {
      // Final result - add to message stream
      debugPrint('🟢 DEEPGRAM: Adding final transcript to message stream: "$transcript"');
      _messageController.add(transcript);
      _updateState(DeepgramAgentState.processing);
      
      // Make sure we restart listening after processing to maintain the connection
      Future.delayed(Duration(milliseconds: 500), () {
        // Only if we're not already in another state (like speaking)
        if (_state == DeepgramAgentState.processing) {
          debugPrint('🔵 DEEPGRAM: Auto-transitioning back to listening state to maintain connection');
          _updateState(DeepgramAgentState.listening);
        }
      });
    } else {
      // Interim result - just update state
      debugPrint('🔵 DEEPGRAM: Received interim transcript: "$transcript"');
      _updateState(DeepgramAgentState.listening);
    }
  }
  
  /// Send agent configuration to Deepgram
  void _sendAgentConfig() {
    if (_channel == null) {
      debugPrint('🔴 DEEPGRAM: Cannot send agent config - channel is null');
      return;
    }
    
    debugPrint('🔵 DEEPGRAM: Preparing agent configuration');
    
    // Follow the documented format from Deepgram docs
    final config = {
      "type": "SettingsConfiguration",
      "audio": {
        "input": {
          "encoding": "linear16",
          "sample_rate": 16000
        },
        "output": {
          "encoding": "linear16",
          "sample_rate": 24000,
          "container": "none"
        }
      },
      "agent": {
        "listen": {
          "model": "nova-3"
        },
        "think": {
          "provider": {
            "type": "open_ai"
          },
          "model": "gpt-4o-mini",
          "instructions": "You are Chef, a helpful cooking assistant that can provide recipes, cooking tips, answer cooking-related questions, set cooking timers, and assist with shopping lists.\n\n" +
          "TIMER FUNCTIONALITY:\n" +
          "1. When a user asks you to set a timer, respond with EXACTLY this format: 'alright let me set up a timer for X minutes' where X is the number of minutes.\n" +
          "2. For recipe steps: Guide users through steps one at a time. If a step requires waiting, ask if they'd like you to set a timer. If they say yes, respond with the exact timer format.\n" +
          "3. Always keep track of what each timer is for and mention it in your response (e.g., 'alright let me set up a timer for 5 minutes for the pasta').\n" +
          "4. Use only whole numbers of minutes for timers (1-180 minutes).\n\n" +
          "RECIPE INSTRUCTIONS:\n" +
          "- When giving cooking instructions, list them step by step.\n" +
          "- Ask for progress updates on the previous step before moving to the next step.\n" +
          "- For steps requiring waiting, ask if the user wants a timer.\n" +
          "- Be concise but informative in your responses."
        },
        "speak": {
          "model": "aura-zeus-en"
        }
      }
    };
    
    try {
      final configJson = json.encode(config);
      debugPrint('🔵 DEEPGRAM: Sending SettingsConfiguration: ${configJson.substring(0, math.min(100, configJson.length))}...');
      
      // Send the configuration to the currently established connection
      _channel!.sink.add(configJson);
      debugPrint('🟢 DEEPGRAM: SettingsConfiguration sent successfully');
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error sending agent configuration: $e');
    }
  }
  
  /// Start listening for voice input - this is the main entry point for starting conversations
  Future<bool> startListening() async {
    debugPrint('🎤 DEEPGRAM: Starting listening mode. Connected: $_isConnected, Already listening: $_isListening');
    
    // First make sure we're connected - this is critical
    if (!_isConnected) {
      debugPrint('🎤 DEEPGRAM: Not connected, connecting first');
      
      // Clear old timers before connecting
      _stopHeartbeatTimer();
      _stopForcedAudioTimer();
      
      // Try to connect with a timeout
      bool connected = false;
      try {
        connected = await connect().timeout(
          Duration(seconds: 5),
          onTimeout: () {
            debugPrint('🔴 DEEPGRAM: Connection attempt timed out after 5 seconds');
            return false;
          }
        );
      } catch (e) {
        debugPrint('🔴 DEEPGRAM: Error during connection attempt: $e');
        connected = false;
      }
      
      if (!connected) {
        debugPrint('🔴 DEEPGRAM: Connection failed, cannot start listening');
        _errorController.add('Failed to connect to Deepgram voice service. Please check your internet connection and try again.');
        return false;
      }
      
      // Wait a moment to ensure connection is stable before starting audio
      await Future.delayed(Duration(milliseconds: 500));
    }
    
    // Double-check connection status
    if (!_isConnected) {
      debugPrint('🔴 DEEPGRAM: Still not connected after connection attempt');
      return false;
    }
    
    // If already listening, just make sure everything is running properly
    if (_isListening) {
      debugPrint('🎤 DEEPGRAM: Already listening, ensuring timers and audio stream are active');
      
      // Make sure our critical timers are running
      _startHeartbeatTimer();
      _startForcedAudioTimer();
      
      // Reset inactivity timer
      _resetInactivityTimer();
      
      // For continuous listening, make sure we're still streaming audio
      if (_recordingSubscription == null || _recorder == null) {
        debugPrint('🔴 DEEPGRAM: Audio stream not active despite being in listening state - restarting audio');
        await _streamAudio();
      }
      
      return true;
    }
    
    try {
      debugPrint('🎤 DEEPGRAM: Starting new listening session');
      
      // Update state to listening
      _isListening = true;
      _updateState(DeepgramAgentState.listening);
      
      // Reset inactivity timer since we're actively using the connection
      _resetInactivityTimer();
      
      // Always ensure heartbeat and forced audio timers are running
      _startHeartbeatTimer();
      _startForcedAudioTimer();
      
      // Always stop any existing recording first to avoid conflicts
      await _stopRecording();
      
      // Start fresh audio stream - most critical part
      debugPrint('🎤 DEEPGRAM: Starting new audio stream for listening');
      await _streamAudio();
      
      // Very important: Enable continuous listening by default
      // This ensures the connection stays active
      if (!_continuousListeningEnabled) {
        debugPrint('🎤 DEEPGRAM: Enabling continuous listening mode for more stable connections');
        _continuousListeningEnabled = true;
        await _setCommunicationMode(true);
      }
      
      // Send a detailed log message with connection status
      debugPrint('🟢 DEEPGRAM: Listening mode fully started successfully.');
      debugPrint('🟢 DEEPGRAM: Status: Connected: $_isConnected, Listening: $_isListening, Continuous: $_continuousListeningEnabled, State: $_state');
      
      return true;
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Failed to start listening: $e');
      _errorController.add('Failed to start listening: $e');
      
      // Set our state tracking correctly
      _isListening = false;
      
      // Try to recover if possible
      if (_isConnected) {
        debugPrint('🎤 DEEPGRAM: Will retry starting audio stream in 1 second after failure');
        Future.delayed(Duration(seconds: 1), () {
          if (_isConnected) {
            // Make sure heartbeat is still running even if audio failed
            _startHeartbeatTimer();
            _startForcedAudioTimer();
            _streamAudio();
          }
        });
      }
      
      return false;
    }
  }
  
  /// Stop listening for voice input but keep the connection open 
  /// (pauses the conversation)
  Future<bool> stopListening() async {
    if (!_isConnected || !_isListening) return false;
    
    try {
      // Update state
      _isListening = false;
      _updateState(DeepgramAgentState.connected);
      
      // Reset inactivity timer when transitioning to connected state
      _resetInactivityTimer();
      
      // In continuous mode, we keep recording but change state
      // In regular mode, we stop the recording
      if (!_continuousListeningEnabled) {
        debugPrint('🔊 DEEPGRAM: Stopping audio recording (regular mode)');
        await _stopRecording();
      } else {
        debugPrint('🔊 DEEPGRAM: Keeping audio stream active (continuous mode)');
        // Keep streaming, just change the state
      }
      
      return true;
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Failed to stop listening: $e');
      _errorController.add('Failed to stop listening: $e');
      return false;
    }
  }
  
  /// Completely end the conversation and close all connections
  Future<bool> endConversation() async {
    debugPrint('🔵 DEEPGRAM: Ending conversation and closing all connections');
    
    try {
      // Stop recording first to ensure no more audio is sent
      await _stopRecording();
      
      // Stop all timers
      _stopForcedAudioTimer();
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
      _stopHeartbeatTimer();
      
      // Stop audio playback
      await _stopAudioStream();
      
      // Set states before disconnecting
      _isListening = false;
      
      // Close the WebSocket connection
      if (_isConnected) {
        debugPrint('🔵 DEEPGRAM: Closing WebSocket connection');
        try {
          _channel?.sink.close();
        } catch (e) {
          debugPrint('🔴 DEEPGRAM: Error closing WebSocket: $e');
        }
      }
      
      _channel = null;
      _isConnected = false;
      
      // Update state to idle
      _updateState(DeepgramAgentState.idle);
      
      debugPrint('🟢 DEEPGRAM: Conversation ended successfully');
      return true;
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error ending conversation: $e');
      _errorController.add('Error ending conversation: $e');
      
      // Make sure we still set the disconnected state even if there was an error
      _isConnected = false;
      _isListening = false;
      _channel = null;
      _updateState(DeepgramAgentState.idle);
      
      return false;
    }
  }
  
  /// Send a text message to the agent
  Future<void> sendTextMessage(String text) async {
    if (!_isConnected) {
      final connected = await connect();
      if (!connected) return;
    }
    
    try {
      // Process with LLM directly
      _updateState(DeepgramAgentState.processing);
      final response = await _llmService.generateTextResponse(text);
      
      // Add to message stream
      _messageController.add(response);
      
      _updateState(DeepgramAgentState.connected);
    } catch (e) {
      _errorController.add('Failed to send message: $e');
    }
  }
  
  /// Send audio data to Deepgram
  void sendAudioData(Uint8List audioData) {
    if (_channel == null || !_isConnected || !_isListening) return;
    
    try {
      // Send raw audio data to Deepgram
      _channel!.sink.add(audioData);
    } catch (e) {
      debugPrint('Error sending audio data: $e');
    }
  }
  
  /// Stream audio data from microphone to Deepgram
  /// This function ensures we maintain continuous audio streaming to Deepgram
  Future<void> _streamAudio() async {
    if (!_isConnected) {
      debugPrint('🔴 DEEPGRAM: Cannot stream audio - not connected');
      
      // Try to reconnect if not connected
      debugPrint('🔵 DEEPGRAM: Trying to reconnect before streaming audio');
      final connected = await connect();
      if (!connected) {
        debugPrint('🔴 DEEPGRAM: Failed to connect, cannot stream audio');
        return;
      }
    }
    
    // Stop any existing recording first
    await _stopRecording();
    
    try {
      debugPrint('🔵 DEEPGRAM: Initializing audio recorder for continuous streaming');
      
      // Make sure heartbeat and forced audio timers are running before starting recording
      _startHeartbeatTimer();
      _startForcedAudioTimer();
      
      // Create a new recorder
      _recorder = AudioRecorder();
      
      // Check and request permission if needed
      final hasPermission = await _recorder!.hasPermission();
      debugPrint('🔵 DEEPGRAM: Microphone permission status: $hasPermission');
      
      if (!hasPermission) {
        debugPrint('🔴 DEEPGRAM: Microphone permission denied');
        _errorController.add('Microphone permission denied');
        return;
      }
      
      // Always enable continuous listening features
      // This is critical for maintaining uninterrupted audio streaming
      _continuousListeningEnabled = true;
      
      // Configure audio recording for continuous listening
      // These settings are optimized for full-duplex operation (recording while playing)
      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,  // 16-bit PCM for Deepgram
        sampleRate: 16000,                // 16kHz as required by Deepgram
        numChannels: 1,                   // Mono audio
        autoGain: true,                   // Enable auto gain for better speech detection
        echoCancel: true,                 // Enable echo cancellation for full-duplex operation
        noiseSuppress: true,              // Enable noise suppression
      );
      
      debugPrint('🟢 DEEPGRAM: Starting continuous audio stream with PCM 16-bit, 16kHz, mono');
      
      // Start recording to stream with retry in case of failure
      Stream<Uint8List>? stream;
      int retryCount = 0;
      
      while (stream == null && retryCount < 3) {
        try {
          stream = await _recorder!.startStream(config);
        } catch (e) {
          retryCount++;
          debugPrint('🔴 DEEPGRAM: Error starting stream, retry $retryCount: $e');
          await Future.delayed(Duration(milliseconds: 200));
        }
      }
      
      if (stream == null) {
        throw Exception('Failed to start audio stream after $retryCount retries');
      }
      
      debugPrint('🟢 DEEPGRAM: Audio stream started successfully');
      
      // Add tracking variables for detailed logging
      bool hasSentAudioData = false;
      int packetCount = 0;
      int totalBytesSent = 0;
      int microStreamStartTime = DateTime.now().millisecondsSinceEpoch;
      int lastPacketTimestamp = microStreamStartTime;
      int maxGapBetweenPackets = 0;
      
      // Listen to the stream and send audio data to Deepgram
      _recordingSubscription = stream.listen(
        (data) {
          if (_isConnected && data.isNotEmpty) {
            final now = DateTime.now().millisecondsSinceEpoch;
            final timeSinceLastPacket = now - lastPacketTimestamp;
            lastPacketTimestamp = now;
            
            // Update metrics
            packetCount++;
            totalBytesSent += data.length;
            if (timeSinceLastPacket > maxGapBetweenPackets) {
              maxGapBetweenPackets = timeSinceLastPacket;
            }
            
            // Log first packet
            if (!hasSentAudioData) {
              debugPrint('🟢 DEEPGRAM: First audio packet received and sent: ${data.length} bytes');
              hasSentAudioData = true;
            }
            
            // Periodic logging with more detail
            if (packetCount % 20 == 0) {
              final avgPacketSize = totalBytesSent / packetCount;
              final runningTimeMs = now - microStreamStartTime;
              final packetsPerSecond = packetCount / (runningTimeMs / 1000);
              
              debugPrint('🎤 DEEPGRAM: Audio stream stats: $packetCount packets, ${totalBytesSent ~/ 1024} KB total, '
                  '${avgPacketSize.toStringAsFixed(1)} bytes avg, ${packetsPerSecond.toStringAsFixed(1)} pkts/sec, '
                  'max gap: $maxGapBetweenPackets ms');
            }
            
            // CRITICAL SECTION: Send audio data regardless of conversation state
            // This ensures continuous streaming to Deepgram to prevent timeout
            try {
              if (_channel != null) {
                // Add a sequence tag to help identify this is mic data 
                final micPacket = _markAsMicPacket(data, packetCount);
                _channel!.sink.add(micPacket);
                
                // Reset inactivity timer since we're actively sending data
                _resetInactivityTimer();
                
                // In continuous mode, analyze audio for interruptions during speaking
                if (_continuousListeningEnabled && _state == DeepgramAgentState.speaking) {
                  final hasSignificantAudio = _detectSignificantAudio(data);
                  if (hasSignificantAudio) {
                    debugPrint('🔊 DEEPGRAM: Detected user speech during AI response - possible interruption');
                    _stopAudioStream();
                    _updateState(DeepgramAgentState.listening);
                  }
                }
              } else {
                debugPrint('🔴 DEEPGRAM: WebSocket channel is null while trying to send audio packet #$packetCount');
                
                // Try to reconnect immediately if channel is null
                _reconnect();
              }
            } catch (e) {
              debugPrint('🔴 DEEPGRAM: Error sending audio packet #$packetCount: $e');
              
              // Try to reconnect if we can't send data, but limit reconnection frequency
              if (_isConnected && packetCount % 5 == 0) {
                _reconnect();
              }
            }
          } else if (!_isConnected) {
            debugPrint('🔴 DEEPGRAM: Not connected while receiving audio packet #$packetCount');
            // Cancel subscription if we're no longer connected
            _recordingSubscription?.cancel();
            _recordingSubscription = null;
          }
        },
        onError: (e) {
          debugPrint('🔴 DEEPGRAM: Audio recording error: $e');
          _errorController.add('Audio recording error: $e');
          
          // Try to restart on error in continuous mode
          if (_continuousListeningEnabled && _isConnected) {
            debugPrint('🔵 DEEPGRAM: Attempting to restart audio stream after error');
            
            // Small delay before restart
            Future.delayed(Duration(milliseconds: 500), () {
              if (_isConnected && _continuousListeningEnabled) {
                _streamAudio();
              }
            });
          }
        },
        onDone: () {
          debugPrint('🔵 DEEPGRAM: Audio stream done, packets sent: $packetCount, total: ${totalBytesSent ~/ 1024} KB');
          
          // If continuous listening is enabled and we're still connected, 
          // but the stream ended, restart it immediately
          if (_continuousListeningEnabled && _isConnected) {
            debugPrint('🔵 DEEPGRAM: Restarting audio stream for continuous listening - previous stream ended');
            _streamAudio();
          }
        },
      );
      
      // Start amplitude monitoring for voice detection
      _startAmplitudeMonitoring();
      
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Failed to stream audio: $e');
      _errorController.add('Failed to stream audio: $e');
      
      // If we're using continuous listening and there was an error,
      // try to restart the streaming after a short delay
      if (_continuousListeningEnabled && _isConnected) {
        debugPrint('🔵 DEEPGRAM: Will attempt to restart audio stream in 2 seconds after failure');
        Future.delayed(Duration(seconds: 2), () {
          if (_isConnected && _continuousListeningEnabled) {
            _streamAudio();
          }
        });
      }
    }
  }
  
  /// Mark a packet as coming from microphone by inserting a small header
  /// This doesn't modify the audio data itself but helps with debugging
  Uint8List _markAsMicPacket(Uint8List original, int sequenceNumber) {
    // For very small packets, don't modify them
    if (original.length < 16) return original;
    
    // Clone the original data
    final packet = Uint8List.fromList(original);
    
    // First 2 bytes: 'MIC' marker (subtle, non-destructive)
    // We only set a single bit in each byte to minimize audio impact
    packet[0] = (packet[0] & 0xFE) | 0x01; // Set lowest bit
    packet[1] = (packet[1] & 0xFE) | 0x01; // Set lowest bit
    
    // Encode sequence at bytes 2-3 (very subtly)
    // Only modify the lowest bit to avoid affecting audio quality
    packet[2] = (packet[2] & 0xFE) | ((sequenceNumber & 0x01) != 0 ? 1 : 0);
    packet[3] = (packet[3] & 0xFE) | ((sequenceNumber & 0x02) != 0 ? 1 : 0);
    
    return packet;
  }
  
  /// Start monitoring audio amplitude to detect speech and interruptions
  void _startAmplitudeMonitoring() {
    if (_recorder == null) return;
    
    Timer.periodic(const Duration(milliseconds: 300), (timer) async {
      // Stop if not connected or recorder is gone
      if (!_isConnected || _recorder == null) {
        debugPrint('🔵 DEEPGRAM: Amplitude monitoring stopped');
        timer.cancel();
        return;
      }
      
      try {
        final amplitude = await _recorder!.getAmplitude();
        
        // Log less frequently to reduce noise in logs
        if (math.Random().nextInt(5) == 0) { // Log only ~20% of readings
          debugPrint('🔵 DEEPGRAM: Audio amplitude: ${amplitude.current.toStringAsFixed(1)}, state: $_state');
        }
        
        // IMPORTANT: Handle amplitude-based state transitions
        if (_continuousListeningEnabled && amplitude.current > 20) {
          if (_state == DeepgramAgentState.connected || _state == DeepgramAgentState.idle) {
            // Wake from idle/connected state if we detect speech
            debugPrint('🔊 DEEPGRAM: Detected speech in continuous mode (${amplitude.current.toStringAsFixed(1)}), activating listening');
            _updateState(DeepgramAgentState.listening);
            _resetInactivityTimer();
          } else if (_state == DeepgramAgentState.speaking && amplitude.current > 35) {
            // Higher threshold for interrupting during speech to avoid false triggers
            debugPrint('🔊 DEEPGRAM: Detected user interruption during AI speech (${amplitude.current.toStringAsFixed(1)}), stopping playback');
            _stopAudioStream();
            _updateState(DeepgramAgentState.listening);
            _resetInactivityTimer();
          }
        }
      } catch (e) {
        debugPrint('🔴 DEEPGRAM: Error getting amplitude: $e');
        timer.cancel();
      }
    });
  }
  
  /// Simple energy detector for audio packets
  bool _detectSignificantAudio(Uint8List audioData) {
    // This is a very basic detector that looks at the 16-bit PCM values
    // and calculates an average energy level
    if (audioData.length < 32) return false;
    
    int sum = 0;
    int count = 0;
    
    // Process as 16-bit samples
    for (int i = 0; i < audioData.length - 1; i += 2) {
      // Convert two bytes to a 16-bit sample
      int sample = audioData[i] | (audioData[i + 1] << 8);
      // Convert from signed to absolute value
      if (sample > 32767) sample = sample - 65536;
      sample = sample.abs();
      sum += sample;
      count++;
    }
    
    // Calculate average energy level
    double averageEnergy = count > 0 ? sum / count : 0;
    
    // Energy threshold for speech - this needs to be calibrated
    // through testing on actual device
    const double SPEECH_THRESHOLD = 1000.0;
    
    return averageEnergy > SPEECH_THRESHOLD;
  }
  
  /// Process an image with the LLM
  Future<void> processImageWithLlm(String userMessage) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _errorController.add('Camera not available');
      return;
    }
    
    try {
      // Capture image from camera
      final image = await _cameraController!.takePicture();
      final imageData = await image.readAsBytes();
      
      // Process with LLM
      _updateState(DeepgramAgentState.processing);
      final response = await _llmService.generateMultimodalResponse(userMessage, [imageData]);
      
      // Add to message stream
      _messageController.add(response);
      
      _updateState(DeepgramAgentState.connected);
    } catch (e) {
      _errorController.add('Failed to process image: $e');
    }
  }
  
  /// Start the inactivity timer that will close connection after timeout
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(seconds: _inactivityTimeoutSeconds), () {
      debugPrint('🔵 DEEPGRAM: Inactivity timeout reached, closing connection to save costs');
      
      // If we're still connected but idle, disconnect to save costs
      if (_isConnected && (_state == DeepgramAgentState.connected || _state == DeepgramAgentState.idle)) {
        debugPrint('🔵 DEEPGRAM: Closing inactive connection');
        _disconnect();
        
        // Notify user that connection was closed due to inactivity
        _messageController.add("Voice connection closed due to inactivity. Tap the mic to start a new conversation.");
      }
    });
  }
  
  /// Start sending periodic heartbeats to keep the connection alive
  void _startHeartbeatTimer() {
    _stopHeartbeatTimer(); // Cancel any existing timer
    
    _heartbeatTimer = Timer.periodic(Duration(seconds: _heartbeatIntervalSeconds), (timer) {
      if (!_isConnected) {
        _stopHeartbeatTimer();
        return;
      }
      
      // Send heartbeats regardless of state to ensure connection stays alive
      debugPrint('🔵 DEEPGRAM: Sending heartbeat to keep connection alive');
      _sendHeartbeat();
    });
    
    debugPrint('🔵 DEEPGRAM: Heartbeat timer started (interval: $_heartbeatIntervalSeconds seconds)');
  }
  
  /// Stop the heartbeat timer
  void _stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  
  /// Send a heartbeat message to keep the connection alive
  void _sendHeartbeat() {
    if (!_isConnected || _channel == null) return;
    
    try {
      // Create a heartbeat packet with a unique pattern to be easily identifiable in logs
      final now = DateTime.now();
      _heartbeatCount++;
      final timeSinceLastHeartbeat = _lastHeartbeatTimestamp > 0 
          ? now.millisecondsSinceEpoch - _lastHeartbeatTimestamp 
          : 0;
      
      // Create a heartbeat packet with more data (640 bytes) to ensure it's received
      final heartbeatData = _createHeartbeatPacket(_heartbeatCount);
      
      // Send the heartbeat packet
      _channel!.sink.add(heartbeatData);
      
      // Update timestamp
      _lastHeartbeatTimestamp = now.millisecondsSinceEpoch;
      
      // Log with sequence number for tracking
      debugPrint('❤️ DEEPGRAM: Heartbeat #$_heartbeatCount sent successfully (${heartbeatData.length} bytes, ${timeSinceLastHeartbeat}ms since last)');
      
      // Reset inactivity timer since we just sent data
      _resetInactivityTimer();
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error sending heartbeat #$_heartbeatCount: $e');
      
      // Try to reconnect if there's an error
      if (_isConnected) {
        _reconnect();
      }
    }
  }
  
  /// Create a heartbeat packet that's distinct from regular audio
  Uint8List _createHeartbeatPacket(int sequenceNumber) {
    // Create a larger packet (640 bytes) for heartbeats
    final packet = Uint8List(640);
    
    // Add a recognizable pattern for heartbeats
    // This helps identify them in logs and for debugging
    // First 4 bytes: 'HEAT' marker
    packet[0] = 72; // 'H'
    packet[1] = 69; // 'E'
    packet[2] = 65; // 'A'
    packet[3] = 84; // 'T'
    
    // Next 4 bytes: sequence number 
    packet[4] = (sequenceNumber >> 24) & 0xFF;
    packet[5] = (sequenceNumber >> 16) & 0xFF;
    packet[6] = (sequenceNumber >> 8) & 0xFF;
    packet[7] = sequenceNumber & 0xFF;
    
    // Add some low-level non-zero random noise in the remaining bytes
    final random = math.Random();
    for (int i = 8; i < packet.length; i += 2) {
      // Low amplitude sine wave pattern (values between -10 and 10)
      final noise = (math.sin(i * 0.1) * 10).toInt();
      packet[i] = noise & 0xFF;
      packet[i + 1] = 0; // Higher byte is zero for very low values
    }
    
    return packet;
  }
  
  /// Start a forced audio timer that sends audio data periodically regardless of state
  void _startForcedAudioTimer() {
    _stopForcedAudioTimer();
    
    // Log that we are starting the timer
    debugPrint('🔵 DEEPGRAM: Starting forced audio timer (${_forcedAudioIntervalMs}ms intervals)');
    
    _forcedAudioTimer = Timer.periodic(Duration(milliseconds: _forcedAudioIntervalMs), (_) {
      if (!_isConnected || _channel == null) {
        debugPrint('🔴 DEEPGRAM: Not connected in forced audio timer - stopping timer');
        _stopForcedAudioTimer();
        return;
      }
      
      final now = DateTime.now();
      _forcedAudioCount++;
      final timeSinceLastAudio = _lastForcedAudioTimestamp > 0 
          ? now.millisecondsSinceEpoch - _lastForcedAudioTimestamp 
          : 0;
      
      // Create a varied forced audio packet with a distinctive pattern
      final forcedAudioData = _createForcedAudioPacket(_forcedAudioCount);
      try {
        _channel!.sink.add(forcedAudioData);
        
        // Update timestamp
        _lastForcedAudioTimestamp = now.millisecondsSinceEpoch;
        
        // Log every 10th packet to reduce spam but maintain visibility
        if (_forcedAudioCount % 10 == 0) {
          debugPrint('🔉 DEEPGRAM: Forced audio packet #$_forcedAudioCount sent (${forcedAudioData.length} bytes, ${timeSinceLastAudio}ms since last)');
        }
        
        // Reset inactivity timer with each packet
        _resetInactivityTimer();
      } catch (e) {
        debugPrint('🔴 DEEPGRAM: Error sending forced audio packet #$_forcedAudioCount: $e');
        
        // Try to reconnect if we can't send data, but only every 5th failure to avoid too many reconnect attempts
        if (_isConnected && (_forcedAudioCount % 5 == 0)) {
          debugPrint('🔴 DEEPGRAM: Multiple forced audio packet failures - attempting reconnection');
          _reconnect();
        }
      }
    });
    
    debugPrint('🟢 DEEPGRAM: Forced audio timer started with ${_forcedAudioIntervalMs}ms intervals');
  }
  
  /// Stop the forced audio timer
  void _stopForcedAudioTimer() {
    if (_forcedAudioTimer != null) {
      debugPrint('🔵 DEEPGRAM: Stopping forced audio timer (sent $_forcedAudioCount packets)');
      _forcedAudioTimer?.cancel();
      _forcedAudioTimer = null;
    }
  }
  
  /// Create a forced audio packet with distinctive pattern and sequence number
  Uint8List _createForcedAudioPacket(int sequenceNumber) {
    // Create a packet with 480 bytes (15ms of 16kHz audio at 16-bit mono)
    // Using a larger packet for more stability
    final packet = Uint8List(480);
    
    // Add a recognizable pattern for forced audio packets
    // First 4 bytes: 'FORC' marker
    packet[0] = 70; // 'F'
    packet[1] = 79; // 'O'
    packet[2] = 82; // 'R'
    packet[3] = 67; // 'C'
    
    // Next 4 bytes: sequence number
    packet[4] = (sequenceNumber >> 24) & 0xFF;
    packet[5] = (sequenceNumber >> 16) & 0xFF;
    packet[6] = (sequenceNumber >> 8) & 0xFF;
    packet[7] = sequenceNumber & 0xFF;
    
    // Add structured noise that simulates low-level speech energy
    // This is more effective at keeping connections alive than pure random noise
    for (int i = 8; i < packet.length; i += 2) {
      double sample;
      
      // Create a multi-tone signal with decreasing amplitude
      if (i < 100) {
        // Start with higher amplitude
        sample = math.sin(i * 0.1) * 15 + math.sin(i * 0.05) * 5;
      } else if (i < 300) {
        // Middle section
        sample = math.sin(i * 0.2) * 10 + math.sin(i * 0.07) * 3;
      } else {
        // End with lower amplitude
        sample = math.sin(i * 0.3) * 5 + math.sin(i * 0.09) * 2;
      }
      
      // Convert to 16-bit sample (LSB, MSB)
      final intSample = sample.toInt();
      packet[i] = intSample & 0xFF;
      packet[i + 1] = (intSample >> 8) & 0xFF;
    }
    
    return packet;
  }
  
  /// Resets the inactivity timer - call this on user activity
  void _resetInactivityTimer() {
    if (_isConnected) {
      debugPrint('🔵 DEEPGRAM: Resetting inactivity timer due to user activity');
      _startInactivityTimer();
    }
  }
  
  /// Enables or disables continuous listening mode
  void setContinuousListening(bool enabled) {
    _continuousListeningEnabled = enabled;
    debugPrint('🔵 DEEPGRAM: Continuous listening ${enabled ? 'enabled' : 'disabled'}');
    
    // Enable or disable communication mode based on continuous listening setting
    _setCommunicationMode(enabled);
    
    // If audio stream is already initialized, reinitialize with new settings
    if (_isAudioStreamInitialized) {
      _stopAudioStream().then((_) {
        _initAudioStream();
      });
    }
    
    // Start or stop the forced audio timer
    if (enabled && _isConnected) {
      debugPrint('🔵 DEEPGRAM: Starting forced audio for continuous mode');
      _startForcedAudioTimer();
    } else {
      debugPrint('🔵 DEEPGRAM: Stopping forced audio for regular mode');
      _stopForcedAudioTimer();
    }
    
    // If enabling continuous listening, make sure we're connected and listening
    if (enabled) {
      // Make sure we're sending frequent heartbeats in continuous mode
      if (_isConnected) {
        // Restart heartbeat with more frequent intervals for continuous mode
        _heartbeatIntervalSeconds < 3 ? _startHeartbeatTimer() : null;
      }
      
      // Connect if not already connected
      if (_isInitialized && !_isConnected) {
        connect().then((success) {
          if (success) {
            startListening();
          }
        });
      } else if (_isConnected && !_isListening) {
        // If connected but not listening, start listening
        startListening();
      }
    } else {
      // If disabling continuous mode and we're not actively listening,
      // we can use the standard heartbeat interval
      if (_isConnected && _state != DeepgramAgentState.listening) {
        _startHeartbeatTimer();
      }
    }
  }
  
  // Flag to prevent multiple simultaneous reconnections
  bool _isReconnecting = false;
  
  /// Attempts to reconnect if the connection was dropped
  Future<void> _reconnect() async {
    // Don't attempt multiple reconnects at the same time
    if (_isReconnecting) {
      debugPrint('🔵 DEEPGRAM: Reconnection already in progress, skipping duplicate request');
      return;
    }
    
    try {
      _isReconnecting = true;
      
      // Keep track of the state we had before reconnecting
      final previousState = _state;
      final wasListening = _isListening;
      
      debugPrint('🔵 DEEPGRAM: Attempting to reconnect... (previous state: $previousState, was listening: $wasListening)');
      
      // Clean up old connection but preserve state
      await _disconnect(keepState: true);
      
      // Wait a moment before reconnecting to avoid rapid reconnect loops
      await Future.delayed(Duration(milliseconds: 500));
      
      // Try to reconnect with a timeout
      bool connected = false;
      try {
        connected = await connect().timeout(
          Duration(seconds: 5),
          onTimeout: () {
            debugPrint('🔴 DEEPGRAM: Reconnection attempt timed out after 5 seconds');
            return false;
          }
        );
      } catch (e) {
        debugPrint('🔴 DEEPGRAM: Error during reconnection attempt: $e');
        connected = false;
      }
      
      if (connected) {
        debugPrint('🟢 DEEPGRAM: Successfully reconnected to Deepgram');
        
        // Always start heartbeat and forced audio timers after reconnection
        _startHeartbeatTimer();
        _startForcedAudioTimer();
        
        // Wait a moment to ensure WebSocket stabilizes
        await Future.delayed(Duration(milliseconds: 300));
        
        // If we were listening before, restart listening
        if (wasListening) {
          debugPrint('🟢 DEEPGRAM: Restarting listening after successful reconnection');
          await startListening();
        } else {
          debugPrint('🟢 DEEPGRAM: Connection restored but not resuming listening (wasn\'t active before)');
        }
      } else {
        debugPrint('🔴 DEEPGRAM: Failed to reconnect to Deepgram');
        
        // If this was a critical failure during active conversation, notify the user
        if (wasListening) {
          _errorController.add('Lost connection to voice service. Please try again.');
          _updateState(DeepgramAgentState.idle);
        }
        
        // Try one more time after a delay if we were in an active conversation
        if (wasListening && previousState != DeepgramAgentState.idle) {
          debugPrint('🔵 DEEPGRAM: Will attempt one more reconnection in 3 seconds');
          Future.delayed(Duration(seconds: 3), () {
            _reconnect();
          });
        }
      }
    } finally {
      _isReconnecting = false;
    }
  }
  
  /// Disconnect from Deepgram
  Future<void> _disconnect({bool keepState = false}) async {
    _isConnected = false;
    _isListening = false;
    
    // Cancel all timers
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _stopHeartbeatTimer();
    _stopForcedAudioTimer();
    
    // Stop recording if active
    await _stopRecording();
    
    try {
      _channel?.sink.close();
    } catch (e) {
      debugPrint('Error closing WebSocket: $e');
    }
    
    _channel = null;
    
    if (!keepState) {
      _updateState(DeepgramAgentState.idle);
    }
  }
  
  /// Stop the current recording stream
  Future<void> _stopRecording() async {
    try {
      // Cancel any existing subscriptions
      await _recordingSubscription?.cancel();
      _recordingSubscription = null;
      
      // Stop recording
      if (_recorder != null) {
        await _recorder!.stop();
        _recorder = null;
        debugPrint('🔵 DEEPGRAM: Recording stopped');
      }
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error stopping recording: $e');
    }
  }
  
  /// Disconnect and clean up resources
  Future<void> dispose() async {
    await _disconnect();
    
    // Stop native audio stream
    await _stopAudioStream();
    
    // Dispose of camera controller
    await _cameraController?.dispose();
    
    // Close stream controllers
    _messageController.close();
    _stateController.close();
    _errorController.close();
  }
  
  /// Update the service state
  void _updateState(DeepgramAgentState newState) {
    if (_state == newState) return;
    
    _state = newState;
    _stateController.add(_state);
    
    debugPrint('Deepgram Agent state changed to: $_state');
  }
}

/// States for the Deepgram Agent
enum DeepgramAgentState {
  idle,
  connecting,
  connected,
  listening,
  processing,
  speaking,
}