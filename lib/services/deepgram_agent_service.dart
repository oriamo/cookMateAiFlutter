// lib/services/deepgram_agent_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'llm_service.dart';
import 'deepgram_agent_types.dart';

/// Service that manages the connection to Deepgram's Voice Agent API with optimized
/// full-duplex audio for low-latency voice interactions with barge-in capability.
class DeepgramAgentService {
  // Deepgram WebSocket connection
  WebSocketChannel? _channel;
  String? _apiKey;
  bool _isConnected = false;
  bool _isInitialized = false;
  
  // Connection management
  Timer? _inactivityTimer;
  Timer? _heartbeatTimer;
  final int _inactivityTimeoutSeconds = 60; // Longer timeout for better user experience
  final int _heartbeatIntervalSeconds = 3; 
  
  // Packet tracking for debugging
  int _heartbeatCount = 0;
  int _lastHeartbeatTimestamp = 0;
  
  // Stream controllers
  final _messageController = StreamController<String>.broadcast();
  final _stateController = StreamController<DeepgramAgentState>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  
  // Current state
  DeepgramAgentState _state = DeepgramAgentState.idle;
  
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
  CameraController? get cameraController => _cameraController;
  
  // Create a TTS engine for fallback audio playback
  final FlutterTts _tts = FlutterTts();
  
  // Native Audio Interface using full-duplex audio system
  static const MethodChannel _audioChannel = MethodChannel('com.oraimo.us.cook_mate_ai/audio_stream');
  bool _isAudioSystemInitialized = false;
  
  // Microphone data management
  final int _micSampleRate = 16000; // 16kHz as required by Deepgram
  bool _isMicActive = false;
  Timer? _micProcessingTimer;
  
  // Barge-in (interruption) configuration
  bool _bargeInEnabled = true;
  bool _isUserSpeaking = false;
  
  // Constructor - reuses the existing LLM service for integration
  DeepgramAgentService(this._llmService);
  
  /// Initialize the Deepgram Agent service with full-duplex audio
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
      
      // Initialize native full-duplex audio system
      await _initAudioSystem();
      
      // Set event handler for user speaking state changes
      _setupEventChannel();
      
      _isInitialized = true;
      _updateState(DeepgramAgentState.idle);
      return true;
    } catch (e) {
      _errorController.add('Failed to initialize Deepgram Agent: $e');
      return false;
    }
  }
  
  /// Set up event channel for native platform events (e.g., user speaking detection)
  void _setupEventChannel() {
    // Listen for user speaking notifications from native layer
    _audioChannel.setMethodCallHandler((call) async {
      if (call.method == 'onUserSpeakingChanged') {
        final isSpeaking = call.arguments['isSpeaking'] as bool;
        _handleUserSpeakingChange(isSpeaking);
        return true;
      }
      return null;
    });
  }
  
  /// Handle user speaking state changes (for barge-in functionality)
  void _handleUserSpeakingChange(bool isSpeaking) {
    _isUserSpeaking = isSpeaking;
    
    // Log user speaking state changes
    debugPrint('🎤 DEEPGRAM: User speaking state changed: $_isUserSpeaking');
    
    if (isSpeaking && _bargeInEnabled && _state == DeepgramAgentState.speaking) {
      // User is speaking while AI is speaking - implement barge-in
      debugPrint('🎤 DEEPGRAM: User interrupted AI speech (barge-in)');
      _updateState(DeepgramAgentState.listening);
    }
  }
  
  /// Initialize native full-duplex audio system
  Future<bool> _initAudioSystem() async {
    if (_isAudioSystemInitialized) {
      debugPrint('🔊 DEEPGRAM: Audio system already initialized');
      return true;
    }
    
    try {
      debugPrint('🔊 DEEPGRAM: Initializing full-duplex audio system');
      
      // Initialize the audio system with optimal configuration for voice agent
      final result = await _audioChannel.invokeMethod<bool>('initAudioSystem', {
        'sampleRate': 24000, // Deepgram's output sample rate
        'enableVoiceDetection': true, // Enable barge-in detection
        'optimizeForLatency': true, // Prioritize low latency for voice applications
      });
      
      if (result != true) {
        debugPrint('🔴 DEEPGRAM: Audio system initialization returned false');
        return false;
      }
      
      _isAudioSystemInitialized = true;
      debugPrint('🟢 DEEPGRAM: Full-duplex audio system successfully initialized');
      
      // Start processing microphone data from native layer
      _startMicrophoneProcessing();
      
      return true;
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error initializing audio system: $e');
      return false;
    }
  }
  
  /// Configure voice detection sensitivity
  Future<bool> _configureVoiceDetection({required bool enabled, int? threshold}) async {
    try {
      final result = await _audioChannel.invokeMethod<bool>('setSpeechDetectionParams', {
        'enabled': enabled,
        'threshold': threshold,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error configuring voice detection: $e');
      return false;
    }
  }
  
  /// Enable or disable barge-in functionality
  void setBargeInEnabled(bool enabled) {
    _bargeInEnabled = enabled;
    debugPrint('🔊 DEEPGRAM: Barge-in ${enabled ? 'enabled' : 'disabled'}');
  }
  
  /// Get audio system statistics
  Future<Map<String, dynamic>> _getAudioStats() async {
    try {
      final result = await _audioChannel.invokeMethod<Map<dynamic, dynamic>>('getAudioStats');
      return result?.cast<String, dynamic>() ?? {
        'isPlaying': false,
        'isRecording': false,
        'totalBytesPlayed': 0,
        'isUserSpeaking': false,
        'latencyMs': 0,
      };
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error getting audio stats: $e');
      return {
        'isPlaying': false,
        'isRecording': false,
        'totalBytesPlayed': 0,
        'isUserSpeaking': false,
        'latencyMs': 0,
      };
    }
  }
  
  /// Start processing microphone data
  void _startMicrophoneProcessing() {
    // Cancel any existing timer
    _micProcessingTimer?.cancel();
    
    // No need for manual microphone management anymore - just enable the state
    _isMicActive = true;
    
    // Log that microphone is active
    debugPrint('🎤 DEEPGRAM: Microphone processing active (handled by native layer)');
  }
  
  /// Stop processing microphone data
  void _stopMicrophoneProcessing() {
    _micProcessingTimer?.cancel();
    _isMicActive = false;
    debugPrint('🎤 DEEPGRAM: Microphone processing stopped');
  }
  
  /// Initialize Text-to-Speech engine for fallback
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
  
  /// Handle audio data from Deepgram for playback
  /// Uses the full-duplex native audio system with barge-in detection
  void _handleAudioData(Uint8List audioData) async {
    try {
      // Update state to indicate the agent is speaking
      _updateState(DeepgramAgentState.speaking);
      
      // Reset inactivity timer since we're actively receiving data
      _resetInactivityTimer();
      
      // Skip very small packets which cause playback issues
      if (audioData.length < 80) {
        debugPrint('🔊 DEEPGRAM: Skipping very small audio packet (${audioData.length} bytes)');
        return;
      }
      
      // Make sure audio system is initialized
      if (!_isAudioSystemInitialized) {
        debugPrint('🔊 DEEPGRAM: Audio system not initialized - initializing now');
        _isAudioSystemInitialized = await _initAudioSystem();
        
        if (!_isAudioSystemInitialized) {
          debugPrint('🔴 DEEPGRAM: Audio system initialization failed - using TTS fallback');
          await _tts.speak('The assistant is responding now');
          return;
        }
      }
      
      // Send audio data to native player with barge-in support
      try {
        // Send the audio data to the native audio system
        // The native layer will handle barge-in detection and interrupt playback if needed
        final result = await _audioChannel.invokeMethod<bool>('writeAudioData', {
          'data': audioData,
          'interruptOnSpeech': _bargeInEnabled, // Enable interruption if user speaks
        });
        
        if (result == false) {
          // Audio was skipped due to user speaking (barge-in)
          debugPrint('🔊 DEEPGRAM: Audio playback interrupted - user is speaking');
          
          // If we were speaking, transition to listening state
          if (_state == DeepgramAgentState.speaking) {
            _updateState(DeepgramAgentState.listening);
          }
        }
      } catch (e) {
        // If sending data fails, log error and try to fall back to TTS
        debugPrint('🔴 DEEPGRAM: Error sending audio data to native player: $e');
        
        // Try to reinitialize audio system
        _isAudioSystemInitialized = false;
        await _initAudioSystem();
        
        // Fall back to TTS if needed (only speak occasionally to avoid spam)
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastSpeakTime > 3000) {
          _lastSpeakTime = now;
          await _tts.speak('The assistant is responding');
        }
      }
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error handling audio data: $e');
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
      
      // Make sure audio system is initialized
      if (!_isAudioSystemInitialized) {
        debugPrint('🔊 DEEPGRAM: Audio system not initialized - initializing now');
        _isAudioSystemInitialized = await _initAudioSystem();
        
        if (!_isAudioSystemInitialized) {
          debugPrint('🔴 DEEPGRAM: Audio system initialization failed');
          return false;
        }
      }
      
      // Connect to Deepgram API
      final wsUrl = 'wss://agent.deepgram.com/agent';
      debugPrint('🔵 DEEPGRAM: Connecting to WebSocket: $wsUrl');
      
      try {
        final socket = await WebSocket.connect(wsUrl, headers: {
          'Authorization': 'Token $_apiKey',
        });
        debugPrint('🟢 DEEPGRAM: WebSocket connected successfully');
        
        // Create channel from socket
        _channel = WebSocketChannel(socket);
        
        // Set up WebSocket listeners
        _setupWebSocketListeners();
        
        // Send initial configuration
        _sendAgentConfig();
        
        _isConnected = true;
        _updateState(DeepgramAgentState.connected);
        
        // Start inactivity and heartbeat timers
        _startInactivityTimer();
        _startHeartbeatTimer();
        
        debugPrint('🟢 DEEPGRAM: Connection completed successfully');
        return true;
      } catch (socketError) {
        debugPrint('🔴 DEEPGRAM: WebSocket connection error: $socketError');
        throw socketError;
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
            // Process binary audio data for playback
            final audioData = Uint8List.fromList(message);
            _handleAudioData(audioData);
            return;
          }
          
          // Handle JSON messages
          debugPrint('🟢 DEEPGRAM: Received message: ${message.toString().substring(0, math.min(100, message.toString().length))}...');
          
          // Parse the message
          final Map<String, dynamic> data = json.decode(message as String);
          
          // Handle different message types
          if (data.containsKey('type')) {
            debugPrint('🔵 DEEPGRAM: Message type: ${data['type']}');
            
            switch (data['type']) {
              case 'ConversationText':
                // Transcribed user speech or AI response text
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
                debugPrint('🎤 DEEPGRAM: User started speaking event from Deepgram');
                _updateState(DeepgramAgentState.listening);
                _resetInactivityTimer();
                break;
                
              case 'UserStoppedSpeaking':
                // User stopped speaking
                debugPrint('🎤 DEEPGRAM: User stopped speaking event from Deepgram');
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
                
                // Wait a bit for audio to finish and check state
                Future.delayed(Duration(seconds: 1), () async {
                  final stats = await _getAudioStats();
                  debugPrint('🔊 DEEPGRAM: Audio stats after stop speaking: ${stats.toString()}');
                  
                  // Update state if still in speaking mode
                  if (_state == DeepgramAgentState.speaking) {
                    // Transition to listening for continuous interaction
                    _updateState(DeepgramAgentState.listening);
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
                break;
                
              case 'AgentAudioDone':
                // All audio has been sent
                debugPrint('🔊 DEEPGRAM: Received AgentAudioDone - Audio streaming complete');
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
      
      // Send the configuration
      _channel!.sink.add(configJson);
      debugPrint('🟢 DEEPGRAM: SettingsConfiguration sent successfully');
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error sending agent configuration: $e');
    }
  }
  
  /// Start listening for voice input
  Future<bool> startListening() async {
    debugPrint('🎤 DEEPGRAM: Starting listening mode. Connected: $_isConnected');
    
    // Make sure we're connected
    if (!_isConnected) {
      debugPrint('🎤 DEEPGRAM: Not connected, connecting first');
      
      // Clear old timers
      _stopHeartbeatTimer();
      
      // Try to connect with timeout
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
      
      // Wait a moment to ensure connection is stable
      await Future.delayed(Duration(milliseconds: 500));
    }
    
    // Make sure audio system is initialized
    if (!_isAudioSystemInitialized) {
      debugPrint('🎤 DEEPGRAM: Audio system not initialized, initializing now');
      _isAudioSystemInitialized = await _initAudioSystem();
      
      if (!_isAudioSystemInitialized) {
        debugPrint('🔴 DEEPGRAM: Audio system initialization failed');
        _errorController.add('Failed to initialize audio system. Please try again.');
        return false;
      }
    }
    
    try {
      debugPrint('🎤 DEEPGRAM: Starting new listening session');
      
      // Update state to listening
      _updateState(DeepgramAgentState.listening);
      
      // Reset inactivity timer
      _resetInactivityTimer();
      
      // Start heartbeat timer
      _startHeartbeatTimer();
      
      debugPrint('🟢 DEEPGRAM: Listening mode started successfully');
      return true;
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Failed to start listening: $e');
      _errorController.add('Failed to start listening: $e');
      return false;
    }
  }
  
  /// Stop listening for voice input but keep the connection open
  Future<bool> stopListening() async {
    if (!_isConnected) return false;
    
    try {
      // Update state
      _updateState(DeepgramAgentState.connected);
      
      // Reset inactivity timer
      _resetInactivityTimer();
      
      return true;
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Failed to stop listening: $e');
      _errorController.add('Failed to stop listening: $e');
      return false;
    }
  }
  
  /// End conversation and close connections
  Future<bool> endConversation() async {
    debugPrint('🔵 DEEPGRAM: Ending conversation and closing connections');
    
    try {
      // Stop the audio system first
      if (_isAudioSystemInitialized) {
        try {
          await _audioChannel.invokeMethod<bool>('stopAudioSystem');
          _isAudioSystemInitialized = false;
        } catch (e) {
          debugPrint('🔴 DEEPGRAM: Error stopping audio system: $e');
        }
      }
      
      // Stop timers
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
      _stopHeartbeatTimer();
      
      // Close WebSocket connection
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
      
      // Make sure we still set the disconnected state
      _isConnected = false;
      _channel = null;
      _updateState(DeepgramAgentState.idle);
      
      return false;
    }
  }
  
  /// Send a text message to the agent (for text-based interaction)
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
  
  /// Process an image with the LLM (for vision capabilities)
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
  
  /// Start the inactivity timer
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(seconds: _inactivityTimeoutSeconds), () {
      debugPrint('🔵 DEEPGRAM: Inactivity timeout reached, closing connection');
      
      // If we're still connected but idle, disconnect to save costs
      if (_isConnected && (_state == DeepgramAgentState.connected || _state == DeepgramAgentState.idle)) {
        debugPrint('🔵 DEEPGRAM: Closing inactive connection');
        _disconnect();
        
        // Notify user that connection was closed due to inactivity
        _messageController.add("Voice connection closed due to inactivity. Tap the mic to start a new conversation.");
      }
    });
  }
  
  /// Reset the inactivity timer
  void _resetInactivityTimer() {
    if (_isConnected) {
      _startInactivityTimer();
    }
  }
  
  /// Start sending heartbeats to keep the connection alive
  void _startHeartbeatTimer() {
    _stopHeartbeatTimer();
    
    _heartbeatTimer = Timer.periodic(Duration(seconds: _heartbeatIntervalSeconds), (timer) {
      if (!_isConnected) {
        _stopHeartbeatTimer();
        return;
      }
      
      debugPrint('🔵 DEEPGRAM: Sending heartbeat to keep connection alive');
      _sendHeartbeat();
    });
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
      // Create unique heartbeat pattern
      final now = DateTime.now();
      _heartbeatCount++;
      final timeSinceLastHeartbeat = _lastHeartbeatTimestamp > 0 
          ? now.millisecondsSinceEpoch - _lastHeartbeatTimestamp 
          : 0;
      
      // Send a minimal heartbeat message to prevent timeouts
      final heartbeatMessage = {
        "type": "KeepAlive",
        "sequence": _heartbeatCount
      };
      
      _channel!.sink.add(json.encode(heartbeatMessage));
      
      // Update timestamp
      _lastHeartbeatTimestamp = now.millisecondsSinceEpoch;
      
      // Log with sequence number
      debugPrint('❤️ DEEPGRAM: Heartbeat #$_heartbeatCount sent (${timeSinceLastHeartbeat}ms since last)');
      
      // Reset inactivity timer
      _resetInactivityTimer();
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error sending heartbeat #$_heartbeatCount: $e');
      
      // Try to reconnect if there's an error
      if (_isConnected) {
        _reconnect();
      }
    }
  }
  
  // Flag to prevent multiple simultaneous reconnections
  bool _isReconnecting = false;
  
  /// Attempts to reconnect if the connection was dropped
  Future<void> _reconnect() async {
    if (_isReconnecting) {
      debugPrint('🔵 DEEPGRAM: Reconnection already in progress, skipping duplicate request');
      return;
    }
    
    try {
      _isReconnecting = true;
      
      // Keep track of the state we had before reconnecting
      final previousState = _state;
      
      debugPrint('🔵 DEEPGRAM: Attempting to reconnect... (previous state: $previousState)');
      
      // Clean up old connection but preserve state
      await _disconnect(keepState: true);
      
      // Wait before reconnecting to avoid rapid reconnect loops
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
        
        // Start heartbeat timer
        _startHeartbeatTimer();
        
        // Wait a moment to ensure WebSocket stabilizes
        await Future.delayed(Duration(milliseconds: 300));
        
        // If we were listening before, restart listening
        if (previousState == DeepgramAgentState.listening || 
            previousState == DeepgramAgentState.speaking) {
          debugPrint('🟢 DEEPGRAM: Restarting listening after successful reconnection');
          await startListening();
        }
      } else {
        debugPrint('🔴 DEEPGRAM: Failed to reconnect to Deepgram');
        
        // If this was a critical failure during active conversation, notify the user
        if (previousState == DeepgramAgentState.listening || 
            previousState == DeepgramAgentState.speaking) {
          _errorController.add('Lost connection to voice service. Please try again.');
          _updateState(DeepgramAgentState.idle);
        }
      }
    } finally {
      _isReconnecting = false;
    }
  }
  
  /// Disconnect from Deepgram
  Future<void> _disconnect({bool keepState = false}) async {
    _isConnected = false;
    
    // Cancel all timers
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _stopHeartbeatTimer();
    
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
  
  /// Cleanup and dispose resources
  Future<void> dispose() async {
    await endConversation();
    
    // Stop and cleanup audio system
    if (_isAudioSystemInitialized) {
      try {
        await _audioChannel.invokeMethod<bool>('stopAudioSystem');
      } catch (e) {
        debugPrint('Error stopping audio system: $e');
      }
    }
    
    // Dispose of camera controller
    await _cameraController?.dispose();
    
    // Close stream controllers
    _messageController.close();
    _stateController.close();
    _errorController.close();
    
    debugPrint('🟢 DEEPGRAM: Resources disposed successfully');
  }
  
  /// Update the service state
  void _updateState(DeepgramAgentState newState) {
    if (_state == newState) return;
    
    _state = newState;
    _stateController.add(_state);
    
    debugPrint('Deepgram Agent state changed to: $_state');
  }
}