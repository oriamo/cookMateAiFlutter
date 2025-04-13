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
  
  // Keep alive mechanism
  Timer? _keepAliveTimer;
  final int _keepAliveIntervalSeconds = 30;
  
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
  
  /// Initialize native audio streaming
  Future<bool> _initAudioStream() async {
    try {
      debugPrint('🔊 DEEPGRAM: Initializing native audio stream');
      final result = await _audioChannel.invokeMethod<bool>('initAudioStream', {
        'sampleRate': 24000, // Deepgram's sample rate
      });
      
      _isAudioStreamInitialized = result ?? false;
      debugPrint('🔊 DEEPGRAM: Native audio stream initialized: $_isAudioStreamInitialized');
      return _isAudioStreamInitialized;
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error initializing native audio stream: $e');
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
  
  /// Handle audio data from Deepgram with native streaming
  void _handleAudioData(Uint8List audioData) async {
    try {
      // Update state to indicate the agent is speaking
      _updateState(DeepgramAgentState.speaking);
      
      // Send data to native audio player
      if (_isAudioStreamInitialized) {
        debugPrint('🔊 DEEPGRAM: Sending ${audioData.length} bytes to native audio player');
        try {
          await _audioChannel.invokeMethod<bool>('writeAudioData', {
            'data': audioData,
          });
        } catch (e) {
          debugPrint('🔴 DEEPGRAM: Error sending audio data to native player: $e');
          
          // If native playback fails, initialize it again
          if (!await _initAudioStream()) {
            // If re-init fails, fall back to TTS
            debugPrint('🔴 DEEPGRAM: Failed to reinitialize native audio - falling back to TTS');
            await _tts.speak('Audio playback failed. Falling back to text-to-speech.');
          }
        }
      } else {
        // If native audio isn't available, try to initialize it
        debugPrint('🔊 DEEPGRAM: Native audio not initialized - attempting to initialize');
        if (await _initAudioStream()) {
          // Try again with the same data
          _handleAudioData(audioData);
        } else {
          // Fall back to TTS
          debugPrint('🔴 DEEPGRAM: Native audio initialization failed - falling back to TTS');
          await _tts.speak('Audio playback not available. Using text-to-speech instead.');
        }
      }
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error handling audio data: $e');
    }
  }
  
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
        
        // Start keep-alive timer
        _resetKeepAliveTimer();
        
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
          // Reset auto-reconnect timer since we got a message
          _resetKeepAliveTimer();
          
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
                
                // Cancel any ongoing audio playback
                _stopAudioStream();
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
                    _updateState(DeepgramAgentState.connected); // Change to connected instead of idle to keep the connection active
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
          "instructions": "You are Alloy, a helpful cooking assistant that can provide recipes, cooking tips, and answer cooking-related questions. Be concise but informative."
        },
        "speak": {
          "model": "aura-asteria-en"
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
  
  /// Start listening for voice input
  Future<bool> startListening() async {
    if (!_isConnected) {
      final connected = await connect();
      if (!connected) return false;
    }
    
    if (_isListening) return true; // Already listening
    
    try {
      // Update state to listening
      _isListening = true;
      _updateState(DeepgramAgentState.listening);
      
      // Reset keep-alive timer since we're actively using the connection
      _resetKeepAliveTimer();
      
      // Start streaming audio
      await _streamAudio();
      
      return true;
    } catch (e) {
      _errorController.add('Failed to start listening: $e');
      return false;
    }
  }
  
  /// Stop listening for voice input
  Future<bool> stopListening() async {
    if (!_isConnected || !_isListening) return false;
    
    try {
      // Update state
      _isListening = false;
      _updateState(DeepgramAgentState.connected);
      
      // Reset keep-alive timer when transitioning to connected state
      _resetKeepAliveTimer();
      
      // Send a small ping to ensure the connection is still active
      _sendPing();
      
      return true;
    } catch (e) {
      _errorController.add('Failed to stop listening: $e');
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
  Future<void> _streamAudio() async {
    if (!_isConnected || !_isListening) {
      debugPrint('🔴 DEEPGRAM: Cannot stream audio - not connected or not listening');
      return;
    }
    
    try {
      debugPrint('🔵 DEEPGRAM: Initializing audio recorder for streaming');
      // Set up an audio recorder to capture microphone input
      final recorder = AudioRecorder();
      
      // Check and request permission if needed
      final hasPermission = await recorder.hasPermission();
      debugPrint('🔵 DEEPGRAM: Microphone permission status: $hasPermission');
      
      if (hasPermission) {
        // Create subscriptions to be used later
        StreamSubscription<Uint8List>? audioSubscription;
        StreamSubscription<DeepgramAgentState>? stateSubscription;
        
        debugPrint('🔵 DEEPGRAM: Starting audio stream with PCM 16-bit, 16kHz, mono');
        // Start recording to stream
        final stream = await recorder.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ));
        
        debugPrint('🟢 DEEPGRAM: Audio stream started successfully');
        
        // Add a flag to track if we've sent any audio data
        bool hasSentAudioData = false;
        int packetCount = 0;
        int totalBytesSent = 0;
        
        // Listen to the stream and send audio data to Deepgram
        audioSubscription = stream.listen(
          (data) {
            if (_isListening && _isConnected) {
              if (data.isNotEmpty) {
                packetCount++;
                totalBytesSent += data.length;
                
                if (!hasSentAudioData) {
                  debugPrint('🟢 DEEPGRAM: First audio packet received and sent: ${data.length} bytes');
                  hasSentAudioData = true;
                }
                
                if (packetCount % 10 == 0) {
                  debugPrint('🔵 DEEPGRAM: Sent $packetCount audio packets, total: ${totalBytesSent} bytes');
                }
                
                // Send audio data to Deepgram
                sendAudioData(data);
              } else {
                debugPrint('🟡 DEEPGRAM: Received empty audio data packet');
              }
            } else {
              debugPrint('🟡 DEEPGRAM: Not sending audio packet - isListening: $_isListening, isConnected: $_isConnected');
            }
          },
          onError: (e) {
            debugPrint('🔴 DEEPGRAM: Audio recording error: $e');
            _errorController.add('Audio recording error: $e');
          },
          onDone: () {
            debugPrint('🔵 DEEPGRAM: Audio stream done, packets sent: $packetCount');
          },
        );
        
        // Create a subscription to listen for when recording should stop
        stateSubscription = _stateController.stream.listen((state) {
          if (state != DeepgramAgentState.listening) {
            debugPrint('🔵 DEEPGRAM: State changed to $state, stopping audio recording');
            audioSubscription?.cancel();
            stateSubscription?.cancel();
            recorder.stop();
          }
        });
        
        // Debug info for audio amplitude
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
          if (!_isListening) {
            debugPrint('🔵 DEEPGRAM: Audio amplitude monitoring stopped');
            timer.cancel();
            return;
          }
          
          final amplitude = await recorder.getAmplitude();
          debugPrint('🔵 DEEPGRAM: Audio amplitude: ${amplitude.current}, isListening: $_isListening');
        });
      } else {
        debugPrint('🔴 DEEPGRAM: Microphone permission denied');
        _errorController.add('Microphone permission denied');
      }
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Failed to stream audio: $e');
      _errorController.add('Failed to stream audio: $e');
    }
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
  
  /// Resets the keep-alive timer
  void _resetKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer(Duration(seconds: _keepAliveIntervalSeconds), () {
      debugPrint('🔵 DEEPGRAM: Keep-alive timer triggered, reconnecting...');
      
      // Only try to reconnect if we're currently connected
      if (_isConnected) {
        // Send a ping or reconnect
        _sendPing();
      }
    });
  }
  
  /// Sends a ping to keep the connection alive
  void _sendPing() {
    if (_channel == null || !_isConnected) {
      debugPrint('🔴 DEEPGRAM: Cannot send ping - not connected');
      return;
    }
    
    try {
      debugPrint('🔵 DEEPGRAM: Sending ping to keep connection alive');
      // Deepgram doesn't have a formal ping, so we'll send an empty audio chunk
      // This should keep the connection alive without causing any problems
      final emptyAudio = Uint8List(2); // Minimal valid PCM data (silence)
      _channel!.sink.add(emptyAudio);
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error sending ping: $e');
      // Try to reconnect if ping fails
      _reconnect();
    }
  }
  
  /// Attempts to reconnect if the connection was dropped
  Future<void> _reconnect() async {
    debugPrint('🔵 DEEPGRAM: Attempting to reconnect...');
    
    // Clean up old connection
    await _disconnect(keepState: true);
    
    // Try to reconnect
    final connected = await connect();
    
    if (connected) {
      debugPrint('🟢 DEEPGRAM: Successfully reconnected');
      // If we were listening before, start listening again
      if (_state == DeepgramAgentState.listening) {
        await startListening();
      }
    } else {
      debugPrint('🔴 DEEPGRAM: Failed to reconnect');
    }
  }
  
  /// Disconnect from Deepgram
  Future<void> _disconnect({bool keepState = false}) async {
    _isConnected = false;
    _isListening = false;
    
    // Cancel keep-alive timer
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    
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