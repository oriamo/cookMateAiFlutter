// lib/ui/screens/assistant_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../../services/assistant_service.dart';
import '../widgets/message_bubble.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({Key? key}) : super(key: key);

  @override
  _AssistantScreenState createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isContinuousListening = false;

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
    return Consumer<AssistantProvider>(
      builder: (context, provider, child) {
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
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Initializing Alloy...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'Failed to initialize Alloy',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(error),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Reload the app
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AssistantScreen()),
                );
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainScreen(AssistantProvider provider) {
    final messages = provider.messages;
    final isListening = provider.state == AssistantState.listening;
    final isProcessing = provider.state == AssistantState.processing;
    final isSpeaking = provider.state == AssistantState.speaking;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Flutter Alloy'),
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
          // Settings
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Show settings dialog
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview (if camera is available)
          if (provider.assistantService.cameraController != null)
            Container(
              height: 200,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CameraPreview(provider.assistantService.cameraController!),
              ),
              padding: const EdgeInsets.all(16),
            ),

          // Chat messages
          Expanded(
            child: messages.isEmpty
                ? _buildWelcomeScreen()
                : _buildChatList(messages),
          ),

          // Continuous listening toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Continuous listening',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Switch(
                      value: _isContinuousListening,
                      onChanged: (value) {
                        setState(() {
                          _isContinuousListening = value;
                        });
                        if (value) {
                          provider.startListening(continuous: true);
                        } else {
                          provider.stopListening();
                        }
                      },
                    ),
                  ],
                ),
                if (isListening)
                  const Text('Listening...', style: TextStyle(color: Colors.green)),
                if (isProcessing)
                  const Text('Processing...', style: TextStyle(color: Colors.orange)),
                if (isSpeaking)
                  const Text('Speaking...', style: TextStyle(color: Colors.blue)),
              ],
            ),
          ),

          // Input area
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Voice input button
                IconButton(
                  icon: Icon(
                    isListening ? Icons.mic : Icons.mic_none,
                    color: isListening ? Colors.red : null,
                  ),
                  onPressed: () {
                    if (isListening) {
                      provider.stopListening();
                    } else {
                      provider.startListening();
                    }
                  },
                  tooltip: isListening ? 'Stop listening' : 'Start listening',
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

  Widget _buildStatusIndicator(AssistantState state) {
    IconData icon;
    Color color;

    switch (state) {
      case AssistantState.idle:
        icon = Icons.circle_outlined;
        color = Colors.grey;
        break;
      case AssistantState.listening:
        icon = Icons.mic;
        color = Colors.green;
        break;
      case AssistantState.processing:
        icon = Icons.hourglass_bottom;
        color = Colors.orange;
        break;
      case AssistantState.speaking:
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
          const Icon(Icons.assistant, size: 64, color: Colors.deepPurple),
          const SizedBox(height: 20),
          Text(
            'Welcome to Flutter Alloy',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Your voice and vision AI assistant',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Text(
            'Try asking:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          _buildSuggestionChip('What can you do?'),
          _buildSuggestionChip('Tell me a joke'),
          _buildSuggestionChip('What do you see in the camera?'),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ActionChip(
        label: Text(text),
        onPressed: () {
          _textController.text = text;
          _sendMessage(Provider.of<AssistantProvider>(context, listen: false));
        },
      ),
    );
  }

  Widget _buildChatList(List<AssistantMessage> messages) {
    // Use a Builder for the ListView to get a proper context
    return Builder(
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return MessageBubble(message: message);
          },
        );
      },
    );
  }

  void _sendMessage(AssistantProvider provider) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    provider.sendTextMessage(text);
    _textController.clear();
  }
}