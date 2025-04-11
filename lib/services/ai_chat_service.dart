import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod_annotation/hooks_riverpod_annotation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';

// This should be stored securely in a .env file or as a server-side secret
// Consider replacing this with a proper secret management solution
const String _geminiApiKey = 'AIzaSyCUWRB78A2bhi5Git8W243DyU3ANL_s1kU';

class AIChatService {
  final GenerativeModel _model;
  late ChatSession _chat;
  
  AIChatService()
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: _geminiApiKey,
          safetySettings: [
            SafetySetting(
              harmCategory: HarmCategory.dangerousContent,
              threshold: HarmBlockThreshold.mediumAndAbove,
            ),
            SafetySetting(
              harmCategory: HarmCategory.harassment,
              threshold: HarmBlockThreshold.mediumAndAbove,
            ),
            SafetySetting(
              harmCategory: HarmCategory.hateSpeech,
              threshold: HarmBlockThreshold.mediumAndAbove,
            ),
            SafetySetting(
              harmCategory: HarmCategory.sexuallyExplicit,
              threshold: HarmBlockThreshold.mediumAndAbove,
            ),
          ],
        ) {
    _initChat();
  }

  void _initChat() {
    _chat = _model.startChat(
      history: [
        Content(
          role: 'user',
          parts: [
            TextPart(
              'You are CookMate AI, a helpful cooking assistant. Your goal is to provide cooking advice, recipe suggestions, and food-related tips. Please provide concise, practical responses focused on cooking, food preparation, and recipe guidance. Always consider dietary restrictions when they are mentioned. If you don\'t know the answer to a cooking question, say so honestly rather than making up information.'
            ),
          ],
        ),
        Content(
          role: 'model',
          parts: [
            TextPart(
              'Hello! I\'m CookMate AI, your personal cooking assistant. I\'m here to help with recipe ideas, cooking techniques, ingredient substitutions, and any other food-related questions you might have. Feel free to ask about specific cuisines, dietary preferences, or quick meal ideas. How can I assist with your cooking today?'
            ),
          ],
        ),
      ],
    );
  }

  Future<String> sendMessage(String message) async {
    try {
      final response = await _chat.sendMessage(
        Content(
          role: 'user',
          parts: [TextPart(message)],
        ),
      );

      final responseText = response.text;
      return responseText ?? 'Sorry, I couldn\'t generate a response.';
    } catch (e) {
      return 'Sorry, there was an error processing your request: ${e.toString()}';
    }
  }
  
  void resetChat() {
    _initChat();
  }
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final AIChatService _aiService;
  final Uuid _uuid = const Uuid();
  
  ChatNotifier(this._aiService) : super([
    ChatMessage(
      id: 'welcome-message',
      content: 'Hello! I\'m CookMate AI, your personal cooking assistant. How can I help you with your cooking today?',
      role: MessageRole.assistant,
    ),
  ]);

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    
    // Add user message
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      content: content,
      role: MessageRole.user,
    );
    state = [...state, userMessage];
    
    // Show loading message
    final loadingMessageId = _uuid.v4();
    state = [...state, ChatMessage(
      id: loadingMessageId,
      content: '...',
      role: MessageRole.assistant,
    )];
    
    // Get AI response
    final response = await _aiService.sendMessage(content);
    
    // Replace loading message with actual response
    state = state.where((message) => message.id != loadingMessageId).toList();
    state = [...state, ChatMessage(
      id: _uuid.v4(),
      content: response,
      role: MessageRole.assistant,
    )];
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