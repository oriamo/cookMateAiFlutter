import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import '../models/chat_message.dart';
import '../services/ai_chat_service.dart';

class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key});

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  
  final List<String> _suggestionChips = [
    "What can I cook with chicken and pasta?",
    "How do I make pizza dough from scratch?",
    "Suggest a quick vegetarian dinner",
    "How do I know when fish is cooked properly?",
    "What's a good substitute for eggs in baking?",
    "How do I fix an oversalted soup?",
    "Give me a recipe for chocolate chip cookies",
    "What pairs well with salmon?"
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    
    // Show typing indicator
    setState(() {
      _isTyping = true;
    });
    
    // Send message using Riverpod
    await ref.read(chatMessagesProvider.notifier).sendMessage(text);
    
    // Hide typing indicator
    setState(() {
      _isTyping = false;
    });
    
    _scrollToBottom();
  }
  
  void _useSuggestion(String suggestion) {
    _messageController.text = suggestion;
    _sendMessage();
  }
  
  void _clearChat() {
    ref.read(chatMessagesProvider.notifier).clearChat();
  }

  @override
  Widget build(BuildContext context) {
    // Watch chat messages
    final messages = ref.watch(chatMessagesProvider);
    
    // Scroll to bottom when messages change
    if (messages.isNotEmpty) {
      _scrollToBottom();
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 16,
              child: Icon(
                Icons.restaurant,
                size: 18,
                color: Colors.deepPurple,
              ),
            ),
            SizedBox(width: 8),
            Text('Chef AI'),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearChat,
            tooltip: 'New Conversation',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return FadeInUp(
                        duration: const Duration(milliseconds: 300),
                        from: 20,
                        child: _buildMessageBubble(message),
                      );
                    },
                  ),
          ),
          
          if (_isTyping)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Chef AI is typing...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          
          // Suggestion chips
          if (messages.length <= 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestionChips.map((suggestion) {
                  return ActionChip(
                    label: Text(
                      suggestion,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                    backgroundColor: Colors.deepPurple.shade50,
                    onPressed: () => _useSuggestion(suggestion),
                  );
                }).toList(),
              ),
            ),
          
          // Divider
          Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
          
          // Message input
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.mic),
                  onPressed: () {},
                  color: Colors.grey.shade600,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask something about cooking...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    minLines: 1,
                    maxLines: 5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Colors.deepPurple,
                ),
              ],
            ),
          ),
          
          // Bottom safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation with Chef AI',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask for recipes, cooking tips, or meal ideas',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) _buildAvatar(),
          const SizedBox(width: 8),
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Colors.deepPurple.shade100
                    : message.isError
                        ? Colors.red.shade50
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: message.isError
                          ? Colors.red.shade700
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          if (message.isUser) _buildUserAvatar(),
        ],
      ),
    );
  }
  
  Widget _buildAvatar() {
    return const CircleAvatar(
      radius: 16,
      backgroundColor: Colors.deepPurple,
      child: Icon(
        Icons.restaurant,
        size: 16,
        color: Colors.white,
      ),
    );
  }
  
  Widget _buildUserAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.blue.shade500,
      child: const Icon(
        Icons.person,
        size: 16,
        color: Colors.white,
      ),
    );
  }
  
  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}