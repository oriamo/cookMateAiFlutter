// lib/providers/message_processor_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/message_processor.dart';
import '../providers/timer_provider.dart';
import '../models/chat_message.dart';

// Message processor provider
final messageProcessorProvider = Provider<MessageProcessor>((ref) {
  final timerService = ref.watch(timerServiceProvider);
  return MessageProcessor(timerService);
});

// Modified ChatNotifier to process messages for timers
class EnhancedChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;
  final StateNotifierProvider<EnhancedChatNotifier, List<ChatMessage>> _originalProvider;
  
  EnhancedChatNotifier(this._ref, this._originalProvider, List<ChatMessage> initialMessages) 
      : super(initialMessages);
  
  // Process an assistant message for timer detection
  Future<void> processAssistantMessage(ChatMessage message) async {
    if (message.role == MessageRole.assistant) {
      final messageProcessor = _ref.read(messageProcessorProvider);
      final timerCreated = await messageProcessor.processAIMessage(message.content);
      
      // You could update the message here if needed to indicate a timer was created
      if (timerCreated) {
        // Optionally modify the message or add a system message
      }
    }
  }
}