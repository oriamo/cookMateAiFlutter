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
  final List<ChatMessage> _messages = [];
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
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _addWelcomeMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          text: "Hello! I'm your AI Chef assistant. How can I help you in the kitchen today?",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
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
    
    // Add user message
    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isTyping = true;
    });
    
    _scrollToBottom();
    
    try {
      // Call AI service
      final response = await AIChatService().generateResponse(text);
      
      // Add AI response
      setState(() {
        _messages.add(
          ChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isTyping = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      // Handle error
      setState(() {
        _messages.add(
          ChatMessage(
            text: "Sorry, I couldn't process your request. Please try again later.",
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
        _isTyping = false;
      });
      
      _scrollToBottom();
    }
  }
  
  void _useSuggestion(String suggestion) {
    _messageController.text = suggestion;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: () {
              setState(() {
                _messages.clear();
                _addWelcomeMessage();
              });
            },
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
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
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
          if (_messages.length <= 2)
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
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(),
          const SizedBox(width: 8),
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
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
                    message.text,
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
          if (isUser) _buildUserAvatar(),
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