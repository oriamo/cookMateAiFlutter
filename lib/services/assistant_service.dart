// lib/services/assistant_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:camera/camera.dart';

import 'vad_service.dart';
import 'stt_service.dart';
import 'llm_service.dart';
import 'tts_service.dart';
import 'video_service.dart';

/// Message types for the assistant
enum MessageType {
  user,
  assistant,
  system,
  error,
}

/// Message model for chat interactions
class AssistantMessage {
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isInterim;
  final Uint8List? image;

  AssistantMessage({
    required this.content,
    required this.type,
    this.isInterim = false,
    this.image,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'AssistantMessage(type: $type, isInterim: $isInterim, content: $content)';
  }
}

/// Assistant state
enum AssistantState {
  idle,
  listening,
  processing,
  speaking,
}

/// Main service that orchestrates all the assistant components
class AssistantService {
  // Component services
  late VadService _vadService;
  late SttService _sttService;
  late LlmService _llmService;
  late TtsService _ttsService;
  late VideoService _videoService;

  // State tracking
  AssistantState _state = AssistantState.idle;
  bool _isInitialized = false;
  bool _isContinuousListening = false;

  // Message history
  final List<AssistantMessage> _messages = [];

  // Current interim message
  AssistantMessage? _currentInterimMessage;

  // Stream controllers
  final _messageController = StreamController<AssistantMessage>.broadcast();
  final _stateController = StreamController<AssistantState>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Expose streams
  Stream<AssistantMessage> get onMessage => _messageController.stream;
  Stream<AssistantState> get onStateChange => _stateController.stream;
  Stream<String> get onError => _errorController.stream;

  // Status getters
  AssistantState get state => _state;
  bool get isInitialized => _isInitialized;
  bool get isContinuousListening => _isContinuousListening;
  List<AssistantMessage> get messages => List.unmodifiable(_messages);

  // Expose services for direct access when needed
  VideoService get videoService => _videoService;

  // Constructor
  AssistantService() {
    _vadService = VadService();
    _sttService = SttService();
    _llmService = LlmService();
    _ttsService = TtsService();
    _videoService = VideoService();
  }

  /// Initialize all services
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize all services
      final vadInitialized = await _vadService.initialize();
      final sttInitialized = await _sttService.initialize();
      final llmInitialized = await _llmService.initialize();
      final ttsInitialized = await _ttsService.initialize();
      final videoInitialized = await _videoService.initialize();

      // Check if all services are initialized
      _isInitialized = vadInitialized && sttInitialized &&
          llmInitialized && ttsInitialized && videoInitialized;

      if (!_isInitialized) {
        _errorController.add('Failed to initialize one or more services');
        return false;
      }

      // Set up event listeners
      _setupEventListeners();

      // Try to set Alloy-like voice
      await _ttsService.useAlloyLikeVoice();

      // Add system message
      _addSystemMessage(
          'Alloy is ready. You can speak or type to interact with me.'
      );

      // Change state to idle
      _updateState(AssistantState.idle);

      return true;
    } catch (e) {
      _errorController.add('Failed to initialize assistant: $e');
      return false;
    }
  }

  /// Set up event listeners for all services
  void _setupEventListeners() {
    // VAD events
    _vadService.onSpeechStart.listen((_) {
      // Speech started, start STT
      _handleSpeechStart();
    });

    _vadService.onSpeechEnd.listen((audio) {
      // Speech ended, stop STT
      _handleSpeechEnd();
    });

    _vadService.onError.listen((error) {
      _errorController.add('VAD error: $error');
    });

    // STT events
    _sttService.onResult.listen((result) {
      // Got STT result
      _handleSttResult(result);
    });

    _sttService.onError.listen((error) {
      _errorController.add('STT error: $error');
    });

    // TTS events
    _ttsService.onStateChange.listen((ttsState) {
      if (ttsState == TtsState.playing) {
        _updateState(AssistantState.speaking);
      } else if (ttsState == TtsState.stopped || ttsState == TtsState.paused) {
        // If we're in continuous listening mode, go back to listening
        if (_isContinuousListening) {
          startListening(continuous: true);
        } else {
          _updateState(AssistantState.idle);
        }
      }
    });

    _ttsService.onError.listen((error) {
      _errorController.add('TTS error: $error');
    });

    // LLM events
    _llmService.onResponse.listen((response) {
      // Got chunk of streaming response
      debugPrint('LLM response chunk: $response');
    });

    // Video events
    _videoService.onError.listen((error) {
      _errorController.add('Video error: $error');
    });
  }

  /// Start listening for voice commands
  Future<bool> startListening({bool continuous = false}) async {
    if (!_isInitialized) {
      _errorController.add('Assistant not initialized');
      return false;
    }

    if (_state == AssistantState.speaking) {
      // Stop speaking first
      await _ttsService.stop();
    }

    _isContinuousListening = continuous;

    // Start VAD
    await _vadService.startListening();

    _updateState(AssistantState.listening);
    return true;
  }

  /// Stop listening for voice commands
  Future<bool> stopListening() async {
    if (_state != AssistantState.listening) return false;

    _isContinuousListening = false;

    // Stop VAD and STT
    await _vadService.stopListening();
    await _sttService.stopListening();

    _updateState(AssistantState.idle);
    return true;
  }

  /// Handle start of speech detected by VAD
  void _handleSpeechStart() async {
    debugPrint('ASSISTANT_DEBUG: Speech start detected by VAD');

    try {
      // Log status before starting
      _sttService.logSpeechStatus();
      
      // Start STT with more specific parameters
      final sttStarted = await _sttService.startListening(
        partialResults: true,
        pauseFor: const Duration(seconds: 1), // Shorter pause to be more responsive
        listenFor: const Duration(seconds: 15), // Reasonable timeout
      );
      
      debugPrint('ASSISTANT_DEBUG: STT start result: $sttStarted');
      
      if (!sttStarted) {
        debugPrint('ASSISTANT_DEBUG: Failed to start STT, will try again');
        // Try once more after a short delay
        await Future.delayed(const Duration(milliseconds: 200));
        await _sttService.startListening(partialResults: true);
      }

      // Create interim message
      _currentInterimMessage = AssistantMessage(
        content: '',
        type: MessageType.user,
        isInterim: true,
      );

      // Add to stream
      _messageController.add(_currentInterimMessage!);
      debugPrint('ASSISTANT_DEBUG: Created empty interim message');

      _updateState(AssistantState.listening);
    } catch (e) {
      debugPrint('ASSISTANT_DEBUG: Error in _handleSpeechStart: $e');
      _errorController.add('Failed to start speech recognition: $e');
    }
  }

  /// Handle end of speech detected by VAD
  void _handleSpeechEnd() async {
    debugPrint('ASSISTANT_DEBUG: Speech end detected by VAD');

    try {
      // Get current status
      _sttService.logSpeechStatus();

      // Stop STT
      await _sttService.stopListening();
      
      debugPrint('ASSISTANT_DEBUG: Current interim message: ${_currentInterimMessage?.content}');

      // Finalize current message if it exists and has content
      if (_currentInterimMessage != null) {
        final content = _currentInterimMessage!.content.trim();
        
        if (content.isNotEmpty) {
          debugPrint('ASSISTANT_DEBUG: Creating final message with content: "$content"');
          
          final finalMessage = AssistantMessage(
            content: content,
            type: MessageType.user,
            isInterim: false,
          );

          _messages.add(finalMessage);
          _messageController.add(finalMessage);

          // Process the message
          _processUserMessage(finalMessage);
        } else {
          debugPrint('ASSISTANT_DEBUG: No content in interim message, not processing');
          _updateState(AssistantState.idle);
        }
      } else {
        debugPrint('ASSISTANT_DEBUG: No interim message exists, nothing to process');
        _updateState(AssistantState.idle);
      }

      _currentInterimMessage = null;
    } catch (e) {
      debugPrint('ASSISTANT_DEBUG: Error in _handleSpeechEnd: $e');
      _errorController.add('Failed to process speech: $e');
      _updateState(AssistantState.idle);
    }
  }

  /// Handle STT result
  void _handleSttResult(SpeechRecognitionResult result) {
    final recognizedWords = result.recognizedWords.trim();
    final confidence = result.confidence;
    
    debugPrint('ASSISTANT_DEBUG: STT result received - words: "${recognizedWords}", final: ${result.finalResult}, confidence: $confidence');

    // Skip empty results or very low confidence results
    if (recognizedWords.isEmpty) {
      debugPrint('ASSISTANT_DEBUG: Empty speech result, ignoring');
      return;
    }
    
    if (confidence < 0.1 && result.finalResult) {
      debugPrint('ASSISTANT_DEBUG: Very low confidence final result, ignoring');
      return;
    }

    try {
      // Update interim message
      if (_currentInterimMessage != null) {
        debugPrint('ASSISTANT_DEBUG: Updating interim message from "${_currentInterimMessage!.content}" to "$recognizedWords"');
        
        final updatedMessage = AssistantMessage(
          content: recognizedWords,
          type: MessageType.user,
          isInterim: !result.finalResult,
        );

        _currentInterimMessage = updatedMessage;
        _messageController.add(updatedMessage);
        
        // Log speech recognition status after updating message
        _sttService.logSpeechStatus();
        
        // If this is the final result, process it immediately
        // This helps in case the VAD speech end event doesn't trigger properly
        if (result.finalResult) {
          debugPrint('ASSISTANT_DEBUG: Processing final speech result directly from STT');
          
          // Use a slight delay to avoid race conditions with other events
          Future.delayed(const Duration(milliseconds: 100), () {
            _handleSpeechEnd();
          });
        }
      } else {
        debugPrint('ASSISTANT_DEBUG: Received STT result but no interim message exists');
      }
    } catch (e) {
      debugPrint('ASSISTANT_DEBUG: Error in _handleSttResult: $e');
    }
  }

  /// Process a user message (text or voice)
  Future<void> _processUserMessage(AssistantMessage message) async {
    if (message.content.isEmpty) return;

    _updateState(AssistantState.processing);

    try {
      // Check if the message contains keywords for image processing
      final needsImage = _checkForImageKeywords(message.content);

      // Generate LLM response
      String response;
      if (needsImage) {
        // Capture a frame if not already provided
        Uint8List? imageData = message.image ?? await _videoService.captureFrame();

        if (imageData == null || imageData.isEmpty) {
          response = "I'd like to see what you're referring to, but I'm having trouble accessing the camera.";
        } else {
          response = await _llmService.generateMultimodalResponse(
            message.content,
            [imageData],
          );
        }
      } else {
        response = await _llmService.generateTextResponse(message.content);
      }

      // Add assistant message
      _addAssistantMessage(response);

      // Speak the response
      await _ttsService.speak(response);
    } catch (e) {
      _errorController.add('Failed to process message: $e');

      // Add error message
      _addAssistantMessage(
          'Sorry, I encountered a problem processing your request. Please try again.'
      );

      _updateState(AssistantState.idle);
    }
  }

  /// Send a text message to the assistant
  Future<void> sendTextMessage(String text) async {
    if (text.isEmpty) return;

    // Create user message
    final message = AssistantMessage(
      content: text,
      type: MessageType.user,
    );

    // Add to history
    _messages.add(message);
    _messageController.add(message);

    // Process the message
    await _processUserMessage(message);
  }

  /// Send a message with an image to the assistant
  Future<void> sendImageMessage(String text, Uint8List image) async {
    if (text.isEmpty) return;

    // Create user message with image
    final message = AssistantMessage(
      content: text,
      type: MessageType.user,
      image: image,
    );

    // Add to history
    _messages.add(message);
    _messageController.add(message);

    // Process the message
    await _processUserMessage(message);
  }

  /// Add a system message
  void _addSystemMessage(String content) {
    final message = AssistantMessage(
      content: content,
      type: MessageType.system,
    );

    _messages.add(message);
    _messageController.add(message);
  }

  /// Add an assistant message
  void _addAssistantMessage(String content) {
    final message = AssistantMessage(
      content: content,
      type: MessageType.assistant,
    );

    _messages.add(message);
    _messageController.add(message);
  }

  /// Check if a message contains keywords related to images
  bool _checkForImageKeywords(String message) {
    final imageKeywords = [
      'see', 'look', 'image', 'picture', 'photo', 'camera',
      'show', 'display', 'view', 'screen', 'what is this',
      'what do you see', 'can you see'
    ];

    final lowerMessage = message.toLowerCase();

    return imageKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  /// Update the assistant state
  void _updateState(AssistantState newState) {
    if (_state == newState) return;

    _state = newState;
    _stateController.add(_state);

    debugPrint('Assistant state changed to: $_state');
  }

  /// Clear the message history
  void clearHistory() {
    _messages.clear();
    _llmService.clearChatHistory();
    _addSystemMessage('Chat history cleared.');
  }

  /// Get the camera controller for UI display
  CameraController? get cameraController => _videoService.cameraController;

  /// Clean up resources
  void dispose() async {
    // Stop any ongoing processes
    await stopListening();
    await _ttsService.stop();

    // Dispose services
    _vadService.dispose();
    _sttService.dispose();
    _llmService.dispose();
    _ttsService.dispose();
    _videoService.dispose();

    // Close controllers
    _messageController.close();
    _stateController.close();
    _errorController.close();
  }
}