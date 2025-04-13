// lib/screens/voice_agent_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../services/deepgram_agent_provider.dart';
import '../services/deepgram_agent_types.dart';

class VoiceAgentScreen extends ConsumerStatefulWidget {
  const VoiceAgentScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<VoiceAgentScreen> createState() => _VoiceAgentScreenState();
}

class _VoiceAgentScreenState extends ConsumerState<VoiceAgentScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isConversationActive = false;

  @override
  void dispose() {
    _textController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(deepgramAgentProvider);
    
    // Show loading screen if initializing
    if (provider.isInitializing) {
      return _buildLoadingScreen();
    }

    // Show error screen if there was an error
    if (provider.error != null && !provider.isInitialized) {
      return _buildErrorScreen(provider.error!);
    }

    // Show the main screen
    return _buildMainScreen(provider);
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Voice Conversation'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Initializing Voice Agent...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Voice Conversation'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'Failed to initialize Voice Agent',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(error),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Reload the screen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const VoiceAgentScreen()),
                );
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainScreen(DeepgramAgentProvider provider) {
    final messages = provider.messages;
    final isListening = provider.state == DeepgramAgentState.listening;
    final isProcessing = provider.state == DeepgramAgentState.processing;
    final isSpeaking = provider.state == DeepgramAgentState.speaking;

    // Set the conversation state
    _isConversationActive = provider.state != DeepgramAgentState.idle;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Live Voice Conversation'),
            const SizedBox(width: 10),
            _buildStatusIndicator(provider.state),
          ],
        ),
        actions: [
          // Clear chat history
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => provider.clearHistory(),
            tooltip: 'Clear chat history',
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview (if available)
          if (provider.deepgramAgentService.cameraController != null)
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CameraPreview(provider.deepgramAgentService.cameraController!),
              ),
            ),

          // Chat messages
          Expanded(
            child: messages.isEmpty
                ? _buildWelcomeScreen()
                : _buildChatList(messages),
          ),

          // Live conversation controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: _isConversationActive
                ? ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('End Live Conversation'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () => provider.stopConversation(),
                  )
                : ElevatedButton.icon(
                    icon: const Icon(Icons.mic),
                    label: const Text('Start Live Conversation'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () => provider.startConversation(),
                  ),
          ),

          // Status indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isListening)
                  const Text('Listening...', style: TextStyle(color: Colors.green)),
                if (isProcessing)
                  const Text('Processing...', style: TextStyle(color: Colors.orange)),
                if (isSpeaking)
                  const Text('Speaking...', style: TextStyle(color: Colors.blue)),
              ],
            ),
          ),

          // Text input area
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Camera button for image analysis
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: isProcessing || isSpeaking
                      ? null
                      : () => _sendImageRequest(provider),
                  tooltip: 'Analyze with camera',
                ),

                // Text input field
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (text) => _sendMessage(provider),
                    enabled: !isProcessing && !isSpeaking,
                  ),
                ),

                // Send button
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: (isProcessing || isSpeaking)
                      ? null
                      : () => _sendMessage(provider),
                  tooltip: 'Send message',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(DeepgramAgentState state) {
    IconData icon;
    Color color;

    switch (state) {
      case DeepgramAgentState.idle:
        icon = Icons.circle_outlined;
        color = Colors.grey;
        break;
      case DeepgramAgentState.connecting:
        icon = Icons.sync;
        color = Colors.blue;
        break;
      case DeepgramAgentState.connected:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case DeepgramAgentState.listening:
        icon = Icons.mic;
        color = Colors.green;
        break;
      case DeepgramAgentState.processing:
        icon = Icons.hourglass_bottom;
        color = Colors.orange;
        break;
      case DeepgramAgentState.speaking:
        icon = Icons.volume_up;
        color = Colors.blue;
        break;
    }

    return Icon(icon, color: color, size: 16);
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.record_voice_over, size: 64, color: Colors.blue),
          const SizedBox(height: 20),
          Text(
            'Live Voice Conversation',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Talk naturally with AI using Deepgram\'s Voice Agent',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            'Features:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          _buildFeatureItem('Natural conversational interactions'),
          _buildFeatureItem('Analyze visual content through the camera'),
          _buildFeatureItem('Powered by Gemini and Deepgram'),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.mic),
            label: const Text('Start Conversation'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: () => ref.read(deepgramAgentProvider).startConversation(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildChatList(List<DeepgramAgentMessage> messages) {
    // Use a Builder for the ListView to get a proper context
    return Builder(
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        
        // Debug print message counts by type
        final userCount = messages.where((m) => m.type == DeepgramAgentMessageType.user).length;
        final agentCount = messages.where((m) => m.type == DeepgramAgentMessageType.agent).length;
        debugPrint('🔍 VOICE SCREEN: Displaying ${messages.length} messages (User: $userCount, Agent: $agentCount)');

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return _buildMessageBubble(message);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(DeepgramAgentMessage message) {
    final isUserMessage = message.type == DeepgramAgentMessageType.user;

    return Align(
      alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: _getBubbleColor(message.type),
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // If there's an image, display it
            if (message.image != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    message.image!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // Message text
            Text(
              message.content,
              style: TextStyle(
                color: _getTextColor(message.type),
                fontSize: 16,
              ),
            ),

            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatTimestamp(message.timestamp),
                style: TextStyle(
                  color: _getTextColor(message.type).withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBubbleColor(DeepgramAgentMessageType type) {
    switch (type) {
      case DeepgramAgentMessageType.user:
        return Theme.of(context).colorScheme.primary;
      case DeepgramAgentMessageType.agent:
        return Colors.grey.shade200;
      case DeepgramAgentMessageType.system:
        return Colors.amber.shade100;
      case DeepgramAgentMessageType.error:
        return Colors.red.shade100;
    }
  }

  Color _getTextColor(DeepgramAgentMessageType type) {
    switch (type) {
      case DeepgramAgentMessageType.user:
        return Colors.white;
      case DeepgramAgentMessageType.agent:
        return Colors.black87;
      case DeepgramAgentMessageType.system:
        return Colors.black87;
      case DeepgramAgentMessageType.error:
        return Colors.red.shade800;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  void _sendMessage(DeepgramAgentProvider provider) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    provider.sendTextMessage(text);
    _textController.clear();
  }

  void _sendImageRequest(DeepgramAgentProvider provider) {
    final prompt = _textController.text.trim().isEmpty
        ? 'What do you see in this image?'
        : _textController.text.trim();

    provider.requestImageAnalysis(prompt);
    _textController.clear();
  }
}