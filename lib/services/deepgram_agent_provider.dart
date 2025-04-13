// lib/services/deepgram_agent_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';

import 'deepgram_agent_service.dart';
import 'llm_service.dart';

/// Message model for Deepgram Agent chat interactions
class DeepgramAgentMessage {
  final String content;
  final DeepgramAgentMessageType type;
  final DateTime timestamp;
  final Uint8List? image;

  DeepgramAgentMessage({
    required this.content,
    required this.type,
    this.image,
  }) : timestamp = DateTime.now();
}

/// Message types for the Deepgram Agent
enum DeepgramAgentMessageType {
  user,
  agent,
  system,
  error,
}

/// Provider for the Deepgram Agent
final deepgramAgentProvider = ChangeNotifierProvider<DeepgramAgentProvider>((ref) {
  // Get the LLM service for Gemini integration
  final llmService = LlmService();
  return DeepgramAgentProvider(llmService);
});

/// ChangeNotifier that wraps the Deepgram Agent service
class DeepgramAgentProvider extends ChangeNotifier {
  // Services
  late final DeepgramAgentService _deepgramAgentService;
  
  // State
  bool _isInitializing = false;
  bool _isInitialized = false;
  String? _error;
  
  // Messages
  final List<DeepgramAgentMessage> _messages = [];
  
  // Constructor
  DeepgramAgentProvider(LlmService llmService) {
    _deepgramAgentService = DeepgramAgentService(llmService);
    _initialize();
  }
  
  // State
  bool _continuousListeningEnabled = false;
  
  // Getters
  bool get isInitializing => _isInitializing;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  List<DeepgramAgentMessage> get messages => List.unmodifiable(_messages);
  DeepgramAgentState get state => _deepgramAgentService.state;
  DeepgramAgentService get deepgramAgentService => _deepgramAgentService;
  bool get continuousListeningEnabled => _continuousListeningEnabled;
  
  // Initialize the Deepgram Agent service
  Future<void> _initialize() async {
    if (_isInitialized || _isInitializing) return;
    
    _isInitializing = true;
    _error = null;
    notifyListeners();
    
    try {
      final isInitialized = await _deepgramAgentService.initialize();
      
      if (isInitialized) {
        _isInitialized = true;
        
        // Set up listeners
        _setupListeners();
        
        // Add welcome message
        _addSystemMessage('Welcome to live voice conversation mode powered by Deepgram. You can speak or type to interact with the AI.');
      } else {
        _error = 'Failed to initialize Deepgram Agent';
      }
    } catch (e) {
      _error = 'Error initializing Deepgram Agent: $e';
      debugPrint(_error);
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }
  
  // Set up listeners for the Deepgram Agent service
  void _setupListeners() {
    // Message listener
    _deepgramAgentService.onMessage.listen((message) {
      debugPrint('🟢 DEEPGRAM PROVIDER: Received message: $message');
      
      // Don't add empty messages
      if (message.trim().isEmpty) {
        debugPrint('🟡 DEEPGRAM PROVIDER: Ignoring empty message');
        return;
      }
      
      // Special handling for specific message patterns to explicitly identify user/AI messages
      if (message.contains("Hey there") || 
          message.contains("my name is") || 
          message.contains("I'm not sure if you can hear") ||
          message.startsWith("Can you") ||
          message.startsWith("How do I") ||
          message.startsWith("What is")) {
        // These are clearly user messages
        debugPrint('🟢 DEEPGRAM PROVIDER: Adding explicit user message: $message');
        _addUserMessage(message);
        return;
      }
      
      if (message.contains("I can definitely assist") || 
          message.startsWith("I can ") || 
          message.startsWith("I'm Alloy") || 
          message.startsWith("What cooking") || 
          message.contains("assist you") ||
          message.startsWith("How can I help")) {
        // These are clearly agent messages
        debugPrint('🟢 DEEPGRAM PROVIDER: Adding explicit agent response: $message');
        _addAgentMessage(message);
        return;
      }
      
      // For messages received while listening, they are most likely user transcriptions
      if (_deepgramAgentService.state == DeepgramAgentState.listening) {
        debugPrint('🟢 DEEPGRAM PROVIDER: Adding user transcription from listening state: $message');
        _addUserMessage(message);
        return;
      }
      
      // For messages received while the agent is speaking, they're from the agent
      if (_deepgramAgentService.state == DeepgramAgentState.speaking) {
        debugPrint('🟢 DEEPGRAM PROVIDER: Adding agent message from speaking state: $message');
        _addAgentMessage(message);
        return;
      }
      
      // If the last message was from the user, this is probably the agent's response
      if (_messages.isNotEmpty && _messages.last.type == DeepgramAgentMessageType.user) {
        debugPrint('🟢 DEEPGRAM PROVIDER: Adding agent response based on last message: $message');
        _addAgentMessage(message);
        return;
      } 
      
      // If we're not sure, default to agent message for safety
      debugPrint('🟡 DEEPGRAM PROVIDER: Adding message with unknown role: $message');
      _addAgentMessage(message);
    });
    
    // Error listener
    _deepgramAgentService.onError.listen((error) {
      debugPrint('🔴 DEEPGRAM PROVIDER: Error: $error');
      _addErrorMessage(error);
    });
    
    // State listener
    _deepgramAgentService.onStateChange.listen((newState) {
      debugPrint('🔵 DEEPGRAM PROVIDER: State changed to: $newState');
      // Just notify listeners when state changes
      notifyListeners();
    });
  }
  
  // Start a live voice conversation
  Future<void> startConversation() async {
    if (!_isInitialized) {
      await _initialize();
    }
    
    try {
      await _deepgramAgentService.connect();
      await _deepgramAgentService.startListening();
    } catch (e) {
      _addErrorMessage('Failed to start conversation: $e');
    }
    
    notifyListeners();
  }
  
  // Pause the live voice conversation (keeps connection open)
  Future<void> pauseConversation() async {
    if (!_isInitialized) return;
    
    try {
      await _deepgramAgentService.stopListening();
      _addSystemMessage('Conversation paused. Tap the mic to continue.');
    } catch (e) {
      _addErrorMessage('Failed to pause conversation: $e');
    }
    
    notifyListeners();
  }
  
  // Completely end the live voice conversation (closes connection)
  Future<void> stopConversation() async {
    if (!_isInitialized) return;
    
    try {
      final success = await _deepgramAgentService.endConversation();
      if (success) {
        _addSystemMessage('Voice conversation ended.');
      }
    } catch (e) {
      _addErrorMessage('Failed to end conversation: $e');
    }
    
    notifyListeners();
  }
  
  // Send a text message
  Future<void> sendTextMessage(String text) async {
    if (text.isEmpty) return;
    
    // Add user message
    _addUserMessage(text);
    
    // Send to Deepgram
    await _deepgramAgentService.sendTextMessage(text);
    
    notifyListeners();
  }
  
  // Request an image analysis
  Future<void> requestImageAnalysis(String text) async {
    // Add user message
    _addUserMessage(text);
    
    // Capture and process image
    await _deepgramAgentService.processImageWithLlm(text);
    
    notifyListeners();
  }
  
  // Add a user message
  void _addUserMessage(String content) {
    final message = DeepgramAgentMessage(
      content: content,
      type: DeepgramAgentMessageType.user,
    );
    
    _messages.add(message);
    notifyListeners();
  }
  
  // Add an agent message
  void _addAgentMessage(String content) {
    final message = DeepgramAgentMessage(
      content: content,
      type: DeepgramAgentMessageType.agent,
    );
    
    _messages.add(message);
    notifyListeners();
  }
  
  // Add a system message
  void _addSystemMessage(String content) {
    final message = DeepgramAgentMessage(
      content: content,
      type: DeepgramAgentMessageType.system,
    );
    
    _messages.add(message);
    notifyListeners();
  }
  
  // Add an error message
  void _addErrorMessage(String content) {
    final message = DeepgramAgentMessage(
      content: content,
      type: DeepgramAgentMessageType.error,
    );
    
    _messages.add(message);
    notifyListeners();
  }
  
  // Toggle continuous listening mode
  void setContinuousListening(bool enabled) {
    _continuousListeningEnabled = enabled;
    _deepgramAgentService.setContinuousListening(enabled);
    
    if (enabled) {
      _addSystemMessage('Continuous listening mode enabled. The AI will listen for new queries after responding.');
    } else {
      _addSystemMessage('Continuous listening mode disabled. Tap the mic to start each new query.');
    }
    
    notifyListeners();
  }
  
  // Clear chat history
  void clearHistory() {
    _messages.clear();
    _addSystemMessage('Chat history cleared.');
    notifyListeners();
  }
  
  @override
  void dispose() {
    _deepgramAgentService.dispose();
    super.dispose();
  }
}