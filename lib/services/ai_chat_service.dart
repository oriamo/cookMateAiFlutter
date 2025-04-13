import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

// Mock responses for demo mode
final List<String> mockResponses = [
  "I'd recommend using chicken thighs instead of breast for your curry. They have more flavor and stay juicy even when overcooked a bit.",
  
  "For a quick weeknight dinner, try this 15-minute pasta: Boil spaghetti, then toss with olive oil, garlic, red pepper flakes, and parmesan. Add some spinach at the end to wilt it. Simple but delicious!",
  
  "The best way to store fresh herbs is to trim the stems, place them in a glass with water (like flowers), cover loosely with a plastic bag, and refrigerate. Change the water every couple of days, and they'll last much longer!",
  
  "Yes, you can substitute yogurt for sour cream in most recipes. Greek yogurt works best because of its thicker consistency. Use equal amounts, but expect a slightly tangier flavor.",
  
  "For crispier roasted vegetables, make sure to: 1) Pat them dry before seasoning, 2) Use enough oil to coat but not drench, 3) Don't overcrowd the pan, 4) Roast at a high temperature (425-450°F), and 5) Flip halfway through cooking.",
  
  "To fix an over-salted soup, try adding a peeled, raw potato chunk and simmer for 15 minutes. The potato will absorb some of the salt. You can also add more unsalted broth or a splash of cream to dilute it.",
  
  "For a moist chocolate cake, add a cup of hot coffee to the batter (it enhances the chocolate flavor without adding coffee taste) and use oil instead of butter. Also, don't overbake - when a toothpick comes out with a few moist crumbs, it's done.",
];

class AIChatService {
  final _random = DateTime.now().millisecondsSinceEpoch; // For deterministic responses
  int _responseIndex = 0;
  
  AIChatService();

  // In demo mode, we'll return predefined responses
  Future<String> sendMessage(String message, {int retryCount = 0}) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Provide a response based on a cycle of our mock responses
    _responseIndex = (_responseIndex + 1) % mockResponses.length;
    return mockResponses[_responseIndex];
  }
  
  void resetChat() {
    // Reset response index
    _responseIndex = 0;
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
    
    // Replace loading message with actual response
    state = state.where((message) => message.id != loadingMessageId).toList();
    state = [...state, ChatMessage(
      id: _uuid.v4(),
      content: response,
      role: MessageRole.assistant,
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