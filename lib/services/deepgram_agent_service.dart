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

import 'llm_service.dart';

/// Service that manages the connection to Deepgram's Voice Agent API
class DeepgramAgentService {
  // Deepgram WebSocket connection
  WebSocketChannel? _channel;
  String? _apiKey;
  bool _isConnected = false;
  bool _isInitialized = false;
  bool _isListening = false;
  
  // Stream controllers
  final _messageController = StreamController<String>.broadcast();
  final _stateController = StreamController<DeepgramAgentState>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  
  // Current state
  DeepgramAgentState _state = DeepgramAgentState.idle;
  
  // LLM service for Gemini integration
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
  
  // Constructor - reuses the existing LLM service for Gemini integration
  DeepgramAgentService(this._llmService);
  
  // Create a TTS engine for audio playback
  final FlutterTts _tts = FlutterTts();
  
  // Phone call style continuous audio streaming
  bool _isPlayingAudio = false;
  AudioPlayer? _currentPlayer;
  final List<Uint8List> _audioBuffer = [];
  bool _isStreamingMode = true;     // Enable phone-call style streaming
  
  // For real-time audio handling
  File? _currentAudioFile;
  IOSink? _audioFileSink;
  int _totalBytesWritten = 0;
  
  // Message tracking for context
  final List<Map<String, dynamic>> _messages = [];
  
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
      
      // Configure audio settings for streaming mode
      if (_isStreamingMode) {
        debugPrint('🎧 DEEPGRAM: Initializing in phone-call style streaming mode');
      }
      
      _isInitialized = true;
      _updateState(DeepgramAgentState.idle);
      return true;
    } catch (e) {
      _errorController.add('Failed to initialize Deepgram Agent: $e');
      return false;
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
    
    // Initialize TTS settings
    _initializeTts();
    
    // Listen for messages from Deepgram
    _channel!.stream.listen(
      (dynamic message) {
        try {
          // Check if this is a binary message (audio from the server)
          if (message is List<int>) {
            // Handle binary audio response from the agent
            debugPrint('🔵 DEEPGRAM: Received binary audio data: ${message.length} bytes');
            
            // Store audio data for playback
            final audioData = Uint8List.fromList(message);
            _handleAudioData(audioData);
            
            // Update state to indicate the agent is speaking
            _updateState(DeepgramAgentState.speaking);
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
                debugPrint('🔵 DEEPGRAM: User started speaking event');
                _updateState(DeepgramAgentState.listening);
                
                // In streaming mode, close the current audio stream
                if (_isStreamingMode && _isPlayingAudio) {
                  debugPrint('🎧 DEEPGRAM: Stopping audio stream because user started speaking');
                  _cancelAudioPlayback();
                }
                break;
                
              case 'UserStoppedSpeaking':
                // User stopped speaking
                debugPrint('🔵 DEEPGRAM: User stopped speaking event');
                _updateState(DeepgramAgentState.processing);
                break;
                
              case 'AgentStartedSpeaking':
                // Agent started speaking
                debugPrint('🔵 DEEPGRAM: Agent started speaking event');
                _updateState(DeepgramAgentState.speaking);
                break;
                
              case 'AgentStoppedSpeaking':
                // Agent stopped speaking
                debugPrint('🔵 DEEPGRAM: Agent stopped speaking event');
                
                // Finalize the audio stream
                if (_isStreamingMode && _isPlayingAudio) {
                  // Let the audio finish playing naturally
                  // We'll let the player finish rather than abruptly stopping
                  debugPrint('🎧 DEEPGRAM: Agent finished speaking, letting audio complete');
                }
                
                _updateState(DeepgramAgentState.idle);
                break;
                
              case 'AgentFinishedThinking':
                // When the agent has processed the user's input
                debugPrint('🔵 DEEPGRAM: Agent finished thinking event');
                if (data.containsKey('text')) {
                  final agentResponse = data['text'] as String;
                  _messageController.add(agentResponse);
                }
                break;
                
              case 'Error':
                // Error from Deepgram
                if (data.containsKey('description')) {
                  final errorMsg = 'Deepgram error: ${data['description']}';
                  debugPrint('🔴 DEEPGRAM: $errorMsg');
                  _errorController.add(errorMsg);
                }
                break;
                
              case 'EndOfThought':
                // Mark the transition from processing to speaking
                debugPrint('🔵 DEEPGRAM: Received EndOfThought - AI finished processing');
                // Prepare for new audio stream
                if (_isStreamingMode) {
                  // Close existing stream to prepare for a new one
                  _closeStreamingAudio();
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
  
  /// Handle LLM requests from Deepgram
  Future<void> _handleLlmRequest(String userMessage) async {
    try {
      // Process with LLM (Gemini)
      final response = await _llmService.generateTextResponse(userMessage);
      
      // Send response back to Deepgram
      _sendLlmResponse(response);
      
      // Add to message stream
      _messageController.add(response);
    } catch (e) {
      _errorController.add('Error processing LLM request: $e');
    }
  }
  
  /// Send LLM response back to Deepgram
  void _sendLlmResponse(String response) {
    if (_channel == null || !_isConnected) return;
    
    final message = {
      'type': 'LLMResponse',
      'response': response,
    };
    
    _channel!.sink.add(json.encode(message));
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
  
  /// Disconnect from Deepgram
  Future<void> _disconnect() async {
    _isConnected = false;
    _isListening = false;
    
    try {
      _channel?.sink.close();
    } catch (e) {
      debugPrint('Error closing WebSocket: $e');
    }
    
    _channel = null;
    _updateState(DeepgramAgentState.idle);
  }
  
  /// Disconnect and clean up resources
  Future<void> dispose() async {
    await _disconnect();
    
    // Clean up audio resources
    _cancelAudioPlayback();
    
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
  
  /// Initialize streaming audio system
  Future<void> _initializeStreamingAudio() async {
    try {
      // Clean up any existing audio resources
      await _closeStreamingAudio();
      
      // Create a new temp file for streaming
      final tempDir = await getTemporaryDirectory();
      _currentAudioFile = File('${tempDir.path}/deepgram_stream_${DateTime.now().millisecondsSinceEpoch}.wav');
      debugPrint('🎧 DEEPGRAM: Created streaming audio file: ${_currentAudioFile!.path}');
      
      // Open a sink to write to the file
      _audioFileSink = _currentAudioFile!.openWrite();
      
      // Write WAV header with placeholder size (we'll update it later)
      // Using a large placeholder size for the stream
      final placeholderHeader = _createWavHeader(100000000, 1, 24000, 16);
      await _audioFileSink!.add(placeholderHeader);
      _totalBytesWritten = placeholderHeader.length;
      
      // Create and prepare player for streaming
      _currentPlayer = AudioPlayer();
      await _currentPlayer!.setVolume(1.0);
      
      // Load the file for playback as soon as it starts filling
      await _currentPlayer!.setFilePath(_currentAudioFile!.path);
      debugPrint('🎧 DEEPGRAM: Audio player initialized for streaming');
      
      // Start playback - this will play as the file grows
      await _currentPlayer!.play();
      _isPlayingAudio = true;
      
      debugPrint('🎧 DEEPGRAM: Started streaming audio playback');
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error initializing streaming audio: $e');
    }
  }
  
  /// Close streaming audio resources
  Future<void> _closeStreamingAudio() async {
    try {
      // Close file sink
      if (_audioFileSink != null) {
        await _audioFileSink!.flush();
        await _audioFileSink!.close();
        _audioFileSink = null;
      }
      
      // Clean up player
      if (_currentPlayer != null) {
        await _currentPlayer!.stop();
        await _currentPlayer!.dispose();
        _currentPlayer = null;
      }
      
      // Delete temp file
      if (_currentAudioFile != null && await _currentAudioFile!.exists()) {
        await _currentAudioFile!.delete();
        _currentAudioFile = null;
      }
      
      _isPlayingAudio = false;
      _totalBytesWritten = 0;
      debugPrint('🎧 DEEPGRAM: Closed streaming audio resources');
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error closing streaming audio: $e');
    }
  }
  
  /// Handle audio data from Deepgram - phone call style streaming
  void _handleAudioData(Uint8List audioData) {
    try {
      // Update state to indicate the agent is speaking
      _updateState(DeepgramAgentState.speaking);
      
      // Initialize streaming if needed
      if (!_isPlayingAudio) {
        _initializeStreamingAudio();
      }
      
      // Write audio chunk to the streaming file
      if (_audioFileSink != null) {
        _audioFileSink!.add(audioData);
        _totalBytesWritten += audioData.length;
        debugPrint('🎧 DEEPGRAM: Added ${audioData.length} bytes to audio stream (total: $_totalBytesWritten)');
      }
    } catch (e) {
      debugPrint('🔴 DEEPGRAM: Error handling audio data: $e');
    }
  }
  
  /// Cancel any ongoing audio playback
  Future<void> _cancelAudioPlayback() async {
    // In streaming mode, we need to close the whole streaming setup
    if (_isStreamingMode) {
      await _closeStreamingAudio();
      return;
    }
    
    // Legacy cancellation for non-streaming mode
    if (_currentPlayer != null) {
      try {
        await _currentPlayer!.stop();
        await _currentPlayer!.dispose();
        debugPrint('🔵 DEEPGRAM: Successfully cancelled audio playback');
      } catch (e) {
        debugPrint('🔴 DEEPGRAM: Error cancelling audio playback: $e');
      } finally {
        _currentPlayer = null;
        _isPlayingAudio = false;
      }
    }
  }
  
  // These streaming methods are no longer used
  // We've simplified to use direct playback
  
  // This placeholder method is no longer used
  
  /// Create a WAV header for the audio data
  Uint8List _createWavHeader(int dataLength, int numChannels, int sampleRate, int bitsPerSample) {
    final byteRate = (sampleRate * numChannels * bitsPerSample) ~/ 8;
    final blockAlign = (numChannels * bitsPerSample) ~/ 8;
    
    final buffer = ByteData(44);
    
    // RIFF chunk descriptor
    buffer.setUint8(0, 'R'.codeUnitAt(0));
    buffer.setUint8(1, 'I'.codeUnitAt(0));
    buffer.setUint8(2, 'F'.codeUnitAt(0));
    buffer.setUint8(3, 'F'.codeUnitAt(0));
    buffer.setUint32(4, 36 + dataLength, Endian.little);
    buffer.setUint8(8, 'W'.codeUnitAt(0));
    buffer.setUint8(9, 'A'.codeUnitAt(0));
    buffer.setUint8(10, 'V'.codeUnitAt(0));
    buffer.setUint8(11, 'E'.codeUnitAt(0));
    
    // 'fmt ' sub-chunk
    buffer.setUint8(12, 'f'.codeUnitAt(0));
    buffer.setUint8(13, 'm'.codeUnitAt(0));
    buffer.setUint8(14, 't'.codeUnitAt(0));
    buffer.setUint8(15, ' '.codeUnitAt(0));
    buffer.setUint32(16, 16, Endian.little); // fmt chunk size
    buffer.setUint16(20, 1, Endian.little); // PCM format
    buffer.setUint16(22, numChannels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);
    
    // 'data' sub-chunk
    buffer.setUint8(36, 'd'.codeUnitAt(0));
    buffer.setUint8(37, 'a'.codeUnitAt(0));
    buffer.setUint8(38, 't'.codeUnitAt(0));
    buffer.setUint8(39, 'a'.codeUnitAt(0));
    buffer.setUint32(40, dataLength, Endian.little);
    
    return buffer.buffer.asUint8List();
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