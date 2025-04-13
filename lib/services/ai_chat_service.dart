import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:convert';
import '../models/chat_message.dart';

enum AIServiceError {
  network,
  authentication,
  rateLimited,
  serverError,
  modelUnavailable,
  contentFiltered,
  unknown
}

class AIChatService {
  final genai.GenerativeModel _model;
  late genai.ChatSession _chat;
  final int _maxRetries = 2;
  
  AIChatService()
      : _model = genai.GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
          safetySettings: [
            genai.SafetySetting(genai.HarmCategory.dangerousContent, genai.HarmBlockThreshold.medium),
            genai.SafetySetting(genai.HarmCategory.harassment, genai.HarmBlockThreshold.medium),
            genai.SafetySetting(genai.HarmCategory.hateSpeech, genai.HarmBlockThreshold.medium),
            genai.SafetySetting(genai.HarmCategory.sexuallyExplicit, genai.HarmBlockThreshold.medium),
          ],
        ) {
    _initChat();
  }

  void _initChat() {
    _chat = _model.startChat(
      history: [
        genai.Content('user', [
          genai.TextPart('You are CookMate AI, a helpful cooking assistant. Your goal is to provide cooking advice, recipe suggestions, and food-related tips. Please provide concise, practical responses focused on cooking, food preparation, and recipe guidance. Always consider dietary restrictions when they are mentioned. If you don\'t know the answer to a cooking question, say so honestly rather than making up information.')
        ]),
        genai.Content('model', [
          genai.TextPart('Hello! I\'m CookMate AI, your personal cooking assistant. I\'m here to help with recipe ideas, cooking techniques, ingredient substitutions, and any other food-related questions you might have. Feel free to ask about specific cuisines, dietary preferences, or quick meal ideas. How can I assist with your cooking today?')
        ]),
      ],
    );
  }

  AIServiceError _parseError(Exception e) {
    final errorMessage = e.toString().toLowerCase();
    
    if (errorMessage.contains('network') || 
        errorMessage.contains('socket') || 
        errorMessage.contains('connect')) {
      return AIServiceError.network;
    } else if (errorMessage.contains('authentication') || 
              errorMessage.contains('api key') ||
              errorMessage.contains('unauthorized')) {
      return AIServiceError.authentication;
    } else if (errorMessage.contains('rate limit') || 
              errorMessage.contains('quota') ||
              errorMessage.contains('too many requests')) {
      return AIServiceError.rateLimited;
    } else if (errorMessage.contains('5') && 
              errorMessage.contains('error')) {
      return AIServiceError.serverError;
    } else if (errorMessage.contains('model') && 
              errorMessage.contains('unavailable')) {
      return AIServiceError.modelUnavailable;
    } else if (errorMessage.contains('safety') || 
              errorMessage.contains('content') ||
              errorMessage.contains('filtered')) {
      return AIServiceError.contentFiltered;
    }
    
    return AIServiceError.unknown;
  }

  String _getErrorMessage(AIServiceError error) {
    switch (error) {
      case AIServiceError.network:
        return 'Network connection issue. Please check your internet connection and try again.';
      case AIServiceError.authentication:
        return 'Authentication error. Please contact support.';
      case AIServiceError.rateLimited:
        return 'You\'ve reached the limit of requests. Please try again later.';
      case AIServiceError.serverError:
        return 'Server error. Please try again later.';
      case AIServiceError.modelUnavailable:
        return 'The AI service is temporarily unavailable. Please try again later.';
      case AIServiceError.contentFiltered:
        return 'I cannot respond to this type of content. Please ask about cooking-related topics.';
      case AIServiceError.unknown:
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<String> sendMessage(String message, {int retryCount = 0}) async {
    try {
      final response = await _chat.sendMessage(
        genai.Content('user', [genai.TextPart(message)]),
      );

      final responseText = response.text;
      return responseText ?? 'Sorry, I couldn\'t generate a response.';
    } catch (e) {
      // Retry logic for network and server errors
      if (retryCount < _maxRetries) {
        final error = e is Exception ? _parseError(e) : AIServiceError.unknown;
        
        if (error == AIServiceError.network || 
            error == AIServiceError.serverError) {
          // Wait for a bit before retrying (exponential backoff)
          await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
          return sendMessage(message, retryCount: retryCount + 1);
        }
      }
      
      // If retries exhausted or other error type
      final error = e is Exception ? _parseError(e) : AIServiceError.unknown;
      return _getErrorMessage(error);
    }
  }
  
  void resetChat() {
    _initChat();
  }
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final AIChatService _aiService;
  final Uuid _uuid = const Uuid();
  static const String _storageKey = 'cook_mate_chat_history';
  
  ChatNotifier(this._aiService) : super([
    ChatMessage(
      id: 'welcome-message',
      content: 'Hello! I\'m CookMate AI, your personal cooking assistant. How can I help you with your cooking today?',
      role: MessageRole.assistant,
    ),
  ]) {
    // Load chat history from storage when initialized
    _loadChatHistory();
  }
  
  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_storageKey);
      
      if (historyJson != null && historyJson.isNotEmpty) {
        final List<dynamic> historyData = jsonDecode(historyJson);
        final List<ChatMessage> loadedMessages = historyData
            .map((messageData) => ChatMessage.fromJson(messageData))
            .toList();
        
        if (loadedMessages.isNotEmpty) {
          state = loadedMessages;
        }
      }
    } catch (e) {
      // If there's an error loading history, keep using the default state
      print('Error loading chat history: $e');
    }
  }
  
  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyData = state.map((message) => message.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(historyData));
    } catch (e) {
      print('Error saving chat history: $e');
    }
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    
    // Add user message
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      content: content,
      role: MessageRole.user,
    );
    state = [...state, userMessage];
    await _saveChatHistory();
    
    // Show loading message
    final loadingMessageId = _uuid.v4();
    state = [...state, ChatMessage(
      id: loadingMessageId,
      content: '...',
      role: MessageRole.assistant,
    )];
    
    // Get AI response
    final response = await _aiService.sendMessage(content);
    
    // Check if response is an error message
    final isError = response.startsWith('Sorry,') || 
                   response.contains('error') ||
                   response.contains('unavailable') ||
                   response.contains('try again');
    
    // Replace loading message with actual response
    state = state.where((message) => message.id != loadingMessageId).toList();
    state = [...state, ChatMessage(
      id: _uuid.v4(),
      content: response,
      role: MessageRole.assistant,
      isError: isError,
    )];
    
    // Save chat history
    await _saveChatHistory();
  }
  
  void clearChat() {
    _aiService.resetChat();
    state = [
      ChatMessage(
        id: 'welcome-message',
        content: 'Hello! I\'m CookMate AI, your personal cooking assistant. How can I help you with your cooking today?',
        role: MessageRole.assistant,
      ),
    ];
    _saveChatHistory();
  }
}

// AI Service provider
final aiServiceProvider = Provider<AIChatService>((ref) {
  return AIChatService();
});

// Chat messages provider
final chatMessagesProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  return ChatNotifier(aiService);
});