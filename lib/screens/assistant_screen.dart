// lib/screens/assistant_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../services/assistant_service.dart';
import '../services/deepgram_agent_provider.dart';
import '../services/deepgram_agent_types.dart';
import '../widgets/message_bubble.dart';
import '../widgets/glowing_live_button.dart';

// Provider for the assistant service
final assistantServiceProvider = Provider<AssistantService>((ref) {
  // Create and return a new instance of AssistantService
  final service = AssistantService();
  
  // Initialize the service
  service.initialize();
  
  // Dispose of the service when the provider is disposed
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Flag to track if camera is showing
  bool _showCamera = true;
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  // Send a text message
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    // Get the assistant service
    final assistantService = ref.read(assistantServiceProvider);
    
    // Send the message
    assistantService.sendTextMessage(text);
    
    // Clear the input field
    _messageController.clear();
    
    // Scroll to bottom after a short delay to ensure the new message is rendered
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }
  
  // Toggle camera visibility
  void _toggleCamera() {
    setState(() {
      _showCamera = !_showCamera;
    });
  }
  
  // Capture image and send with message
  void _captureAndSendImage() async {
    final assistantService = ref.read(assistantServiceProvider);
    final text = _messageController.text.trim();
    final promptText = text.isNotEmpty ? text : "What can you tell me about this?";
    
    // Try to capture a frame
    final frame = await assistantService.videoService.captureFrame();
    
    if (frame != null) {
      // Send the image with the message
      assistantService.sendImageMessage(promptText, frame);
      
      // Clear the input field
      _messageController.clear();
      
      // Scroll to bottom after a short delay
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } else {
      // Show an error if the frame couldn't be captured
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not capture image from camera')),
      );
    }
  }
  
  // Navigate to voice agent screen and start conversation automatically
  void _navigateToVoiceAgentAndStart() {
    context.push('/voice-agent').then((_) {
      // Start conversation automatically when routed to voice agent
      final deepgramProvider = ref.read(deepgramAgentProvider);
      if (deepgramProvider.state == DeepgramAgentState.idle) {
        deepgramProvider.startConversation();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Access the assistant service
    final assistantService = ref.watch(assistantServiceProvider);
    
    // Listen for new messages and scroll to bottom
    ref.listen<List<AssistantMessage>>(
      Provider((ref) => assistantService.messages), 
      (previous, next) {
        if (previous == null || previous.length != next.length) {
          Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        }
      }
    );
    
    // Get the current state of the assistant
    final isListening = assistantService.state == AssistantState.listening;
    final isProcessing = assistantService.state == AssistantState.processing;
    final isSpeaking = assistantService.state == AssistantState.speaking;
    
    // Get the camera controller for the camera preview
    final cameraController = assistantService.cameraController;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.assistant,
                size: 20,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Alloy Assistant'),
            const SizedBox(width: 10),
            _buildStatusIndicator(assistantService.state),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // Camera toggle button
          IconButton(
            icon: Icon(_showCamera ? Icons.videocam_off : Icons.videocam),
            onPressed: _toggleCamera,
            tooltip: _showCamera ? 'Hide Camera' : 'Show Camera',
          ),
          
          // Clear history button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: assistantService.clearHistory,
            tooltip: 'Clear Chat History',
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview (if enabled and available)
          if (_showCamera && cameraController != null)
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CameraPreview(cameraController),
              ),
            ),
          
          
          // Chat messages
          Expanded(
            child: _buildMessageList(assistantService.messages),
          ),
          
          // Input area
          _buildInputArea(
            isListening: isListening,
            isProcessing: isProcessing,
            isSpeaking: isSpeaking,
            assistantService: assistantService,
          ),
          
          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
  
  // Build the status indicator based on the assistant state
  Widget _buildStatusIndicator(AssistantState state) {
    IconData icon;
    Color color;
    
    switch (state) {
      case AssistantState.idle:
        icon = Icons.circle_outlined;
        color = Colors.white70;
        break;
      case AssistantState.listening:
        icon = Icons.mic;
        color = Colors.green;
        break;
      case AssistantState.processing:
        icon = Icons.hourglass_empty;
        color = Colors.amber;
        break;
      case AssistantState.speaking:
        icon = Icons.volume_up;
        color = Colors.lightBlue;
        break;
    }
    
    return Icon(icon, color: color, size: 16);
  }
  
  // Build the message list
  Widget _buildMessageList(List<AssistantMessage> messages) {
    if (messages.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return FadeInUp(
          duration: const Duration(milliseconds: 300),
          from: 20,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MessageBubble(message: message),
          ),
        );
      },
    );
  }
  
  // Build empty state when there are no messages
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 24),
          Text(
            'Hello, I\'m Alloy',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ask me anything about cooking or recipes',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSuggestionChip('What can I cook with chicken and pasta?'),
                _buildSuggestionChip('Give me a recipe for chocolate chip cookies'),
                _buildSuggestionChip('How do I know when fish is cooked properly?'),
                _buildSuggestionChip('What\'s a good substitute for eggs in baking?'),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Build suggestion chips for the empty state
  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.chat, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build input area with text field and buttons
  Widget _buildInputArea({
    required bool isListening,
    required bool isProcessing,
    required bool isSpeaking,
    required AssistantService assistantService,
  }) {
    final isInputDisabled = isProcessing || isSpeaking;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Glowing LIVE button (replaces mic and camera buttons)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GlowingLiveButton(
              onPressed: _navigateToVoiceAgentAndStart,
              baseColor: Colors.deepPurple,
              glowColor: Colors.purple.withOpacity(0.6),
            ),
          ),
          
          // Text input field
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                enabled: !isInputDisabled,
              ),
              textInputAction: TextInputAction.send,
              keyboardType: TextInputType.text,
              onSubmitted: (_) => _sendMessage(),
              maxLines: null,
            ),
          ),
          
          // Send button
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: isInputDisabled ? null : _sendMessage,
            color: Colors.deepPurple,
            tooltip: 'Send message',
          ),
        ],
      ),
    );
  }
}