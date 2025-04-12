
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;

/// Service that handles interactions with the Gemini AI model
class LlmService {
  // Gemini instance
  late Gemini _gemini;
  late genai.GenerativeModel _generativeModel;

  // Chat history for contextual conversations
  final List<Map<String, String>> _chatHistory = [];

  // System prompt that defines the assistant's behavior
  final String _systemPrompt = '''
You are Alloy, a helpful, witty, and concise AI assistant. 
Your responses should be informative but brief.
You have both voice and vision capabilities, allowing you to see images and respond to voice commands.
''';

  // Controllers for streams
  final _responseController = StreamController<String>.broadcast();

  // Expose streams
  Stream<String> get onResponse => _responseController.stream;

  // Configuration
  final bool _enableStreaming;

  /// Constructor with optional streaming capability
  LlmService({bool enableStreaming = true}) : _enableStreaming = enableStreaming;

  /// Initialize the LLM service with API key
  Future<bool> initialize() async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('Missing Gemini API key. Please add it to .env file');
        return false;
      }

      // Initialize Gemini
      _gemini = Gemini.instance;
      _gemini.init(apiKey: apiKey);

      // Initialize GenerativeModel for more advanced features
      _generativeModel = genai.GenerativeModel(
        model: 'gemini-pro',
        apiKey: apiKey,
      );

      // Add system prompt to chat history
      _chatHistory.add({
        'role': 'system',
        'content': _systemPrompt
      });

      return true;
    } catch (e) {
      debugPrint('Failed to initialize Gemini: $e');
      return false;
    }
  }

  /// Generate a response to a text prompt
  Future<String> generateTextResponse(String prompt) async {
    try {
      // Add user prompt to chat history
      _addUserMessage(prompt);

      if (_enableStreaming) {
        return await _streamTextResponse();
      } else {
        return await _generateSingleTextResponse(prompt);
      }
    } catch (e) {
      final errorMessage = 'Error generating response: $e';
      debugPrint(errorMessage);
      return errorMessage;
    }
  }

  /// Generate a response using both text and image
  Future<String> generateMultimodalResponse(String prompt, List<Uint8List> images) async {
    try {
      // Add user prompt to chat history
      _addUserMessage(prompt);

      final response = await _gemini.textAndImage(
        text: prompt,
        images: images,
      );

      final responseText = response?.content?.parts?.last.text ?? 'No response';

      // Add assistant response to chat history
      _addAssistantMessage(responseText);

      return responseText;
    } catch (e) {
      final errorMessage = 'Error generating multimodal response: $e';
      debugPrint(errorMessage);
      return errorMessage;
    }
  }

  /// Generate a streaming response (internal method)
  Future<String> _streamTextResponse() async {
    final completer = Completer<String>();
    final buffer = StringBuffer();

    try {
      // Convert chat history to Gemini chat format
      final chat = _createChatHistory();

      // Create chat session
      final chatSession = _generativeModel.startChat(history: chat);

      // Stream response
      final response = await chatSession.sendMessageStream(
        genai.Content.text(_chatHistory.last['content'] ?? ''),
      );

      // Process streaming response
      response.listen(
            (chunk) {
          final text = chunk.text ?? '';
          buffer.write(text);
          _responseController.add(text);
        },
        onDone: () {
          final fullResponse = buffer.toString();
          // Add assistant response to chat history
          _addAssistantMessage(fullResponse);
          completer.complete(fullResponse);
        },
        onError: (e) {
          completer.completeError('Error in streaming response: $e');
        },
      );

      return await completer.future;
    } catch (e) {
      final errorMessage = 'Error in streaming response: $e';
      debugPrint(errorMessage);
      return errorMessage;
    }
  }

  /// Generate a single (non-streaming) text response
  Future<String> _generateSingleTextResponse(String prompt) async {
    try {
      final response = await _gemini.prompt(
        parts: [Part.text(prompt)],
      );

      final responseText = response?.output ?? 'No response';

      // Add assistant response to chat history
      _addAssistantMessage(responseText);

      // Notify listeners
      _responseController.add(responseText);

      return responseText;
    } catch (e) {
      final errorMessage = 'Error generating response: $e';
      debugPrint(errorMessage);
      return errorMessage;
    }
  }

  /// Convert internal chat history to Gemini format
  List<genai.Content> _createChatHistory() {
    final chatHistory = <genai.Content>[];

    for (final message in _chatHistory) {
      final role = message['role'];
      final content = message['content'] ?? '';

      if (role == 'user') {
        chatHistory.add(genai.Content.user(content));
      } else if (role == 'assistant') {
        chatHistory.add(genai.Content.model(content));
      }
      // System messages are handled differently in Gemini
    }

    return chatHistory;
  }

  /// Add a user message to chat history
  void _addUserMessage(String message) {
    _chatHistory.add({
      'role': 'user',
      'content': message,
    });
  }

  /// Add an assistant message to chat history
  void _addAssistantMessage(String message) {
    _chatHistory.add({
      'role': 'assistant',
      'content': message,
    });
  }

  /// Clear chat history except for the system prompt
  void clearChatHistory() {
    final systemPrompt = _chatHistory.firstWhere(
          (message) => message['role'] == 'system',
      orElse: () => {'role': 'system', 'content': _systemPrompt},
    );

    _chatHistory.clear();
    _chatHistory.add(systemPrompt);
  }

  /// Get the current chat history
  List<Map<String, String>> getChatHistory() {
    return List.from(_chatHistory);
  }

  /// Clean up resources
  void dispose() {
    _responseController.close();
  }
}