// lib/screens/voice_agent_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/deepgram_agent_provider.dart';
import '../services/deepgram_agent_types.dart';
import '../widgets/voice_visualization.dart';
import '../widgets/animated_mic_button.dart';
import '../widgets/cooking_timer_widget.dart';
import '../providers/timer_provider.dart';
import '../services/cooking_session_service.dart';
import '../providers/generated_image_provider.dart';

class VoiceAgentScreen extends ConsumerStatefulWidget {
  const VoiceAgentScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<VoiceAgentScreen> createState() => _VoiceAgentScreenState();
}

class _VoiceAgentScreenState extends ConsumerState<VoiceAgentScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isConversationActive = false;
  bool _stepListenerAttached = false;
  bool _imageGenerationEnabled = false; // Disabled by default

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Set up image generation callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = ref.read(deepgramAgentProvider);
      
      // Set the image generation callback
      provider.setImageGenerationCallback((instruction, recipeContext) {
        if (!_imageGenerationEnabled) {
          debugPrint('🖼️ VOICE AGENT: Image generation is disabled, skipping request');
          return;
        }
        
        debugPrint('🖼️ VOICE AGENT: Received image generation request for: $instruction');
        final actualRecipeContext = ref.read(recipeContextProvider);
        final currentStepImageUrl = ref.read(currentStepImageUrlProvider);
        ref.read(generatedImageProvider.notifier).generateImageForInstruction(
          instruction: instruction,
          recipeContext: actualRecipeContext,
          fallbackImageUrl: currentStepImageUrl,
        );
      });
      
      // Only auto-start if navigated to and not already running
      if (!_isConversationActive && provider.state == DeepgramAgentState.idle) {
        debugPrint(
            'VoiceAgentScreen: Auto-starting conversation with continuous listening enabled');

        // Ensure continuous listening is enabled for the most stable experience
        provider.setContinuousListening(true);

        // Start conversation with a short delay to ensure screen is fully rendered
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted) {
            provider.startConversation();
            setState(() {
              _isConversationActive = true;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Force rebuild on cooking session changes
    ref.watch(cookingSessionProvider);
    // Attach step navigation listener once
    if (!_stepListenerAttached) {
      _stepListenerAttached = true;
      ref.listen<List<DeepgramAgentMessage>>(
        deepgramAgentProvider.select((p) => p.messages),
        (previous, next) {
          if (previous == null || next.length <= previous.length) return;
          final newMsgs = next.sublist(previous.length);
          for (final msg in newMsgs) {
            if (msg.type != DeepgramAgentMessageType.agent) continue;
            final content = msg.content.toLowerCase();
            
            // Jump to a specific step: 'step X'
            // Explicit step number commands
            // Patterns: "step X", "move on to step X", "start with step X" etc.
            // Patterns for explicit step instructions, including "let's move on to step X", "go to step X", etc.
            final stepPatterns = [
              RegExp(
                  r"(?:let'?s\s*)?(?:move on to|start with|begin with|go to)\s*step\s+(\d+)",
                  caseSensitive: false),
              RegExp(r'step\s+(\d+)', caseSensitive: false),
            ];
            bool jumped = false;
            for (final pattern in stepPatterns) {
              final m = pattern.firstMatch(content);
              if (m != null && m.groupCount >= 1) {
                final stepIndex = int.tryParse(m.group(1)!);
                if (stepIndex != null) {
                  debugPrint('AI -> Jumping to step $stepIndex');
                  ref.read(cookingSessionProvider.notifier).goToStep(stepIndex);
                  jumped = true;
                  break;
                }
              }
            }
            if (jumped) continue;
            // Handle 'next step' directive
            if (content.contains('next step')) {
              debugPrint('Detected "next step" command from AI');
              ref.read(cookingSessionProvider.notifier).nextStep();
              continue;
            }
            // Handle 'previous step' directive
            if (content.contains('previous step') ||
                content.contains('last step')) {
              debugPrint('Detected "previous step" command from AI');
              ref.read(cookingSessionProvider.notifier).previousStep();
              continue;
            }
          }
          // Debugging: log that AI navigation parsing completed for msg: ${msg.content}
        },
      );
    }
    final provider = ref.watch(deepgramAgentProvider);

    // Show loading screen if initializing
    if (provider.isInitializing) {
      return _buildLoadingScreen();
    }

    // Show error screen if there was an error
    if (provider.error != null && !provider.isInitialized) {
      return _buildErrorScreen(provider.error!);
    }

    // Main screen
    return _buildMainScreen(provider);
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Voice Conversation'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                  MaterialPageRoute(
                      builder: (context) => const VoiceAgentScreen()),
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
    final isSpeaking = provider.state == DeepgramAgentState.speaking;

    // Set the conversation state
    _isConversationActive = provider.state != DeepgramAgentState.idle;

    // Determine the visualization state
    VisualizationState visualizationState;
    if (isListening) {
      visualizationState = VisualizationState.userSpeaking;
    } else if (isSpeaking) {
      visualizationState = VisualizationState.aiSpeaking;
    } else {
      visualizationState = VisualizationState.idle;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Live'),
            const SizedBox(width: 10),
            _buildStatusIndicator(provider.state),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: 'Open settings menu',
            ),
          ),
        ],
      ),
      endDrawer: _buildSettingsDrawer(provider),
      body: Column(
        children: [
          // Scrollable messages area (shows all conversation history)
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: messages.isNotEmpty
                      ? _buildRecentMessages(messages)
                      : const Center(
                          child: Text('Start speaking to begin a conversation')),
                ),
                // Scroll indicator
                if (messages.length > 2)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${messages.length} messages',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Active Timers display (shows only when timers are active)
          Consumer(
            builder: (context, ref, child) {
              final hasTimers = ref.watch(hasActiveTimersProvider);
              if (!hasTimers) return const SizedBox.shrink();
              return ActiveTimersPanel();
            },
          ),
          // Generated cooking instruction image
          Consumer(
            builder: (context, ref, child) {
              // If image generation is disabled, show nothing
              if (!_imageGenerationEnabled) {
                return const SizedBox.shrink();
              }
              
              final imageState = ref.watch(generatedImageProvider);
              
              if (imageState.isLoading) {
                return Container(
                  height: 200,
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Generating cooking image...'),
                      ],
                    ),
                  ),
                );
              }
              
              if (imageState.imageData != null) {
                return Container(
                  height: 200,
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      imageState.imageData!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              }
              
              if (imageState.error != null) {
                return Container(
                  height: 120,
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to generate image',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // No image to show
              return const SizedBox.shrink();
            },
          ),

          // Voice visualization (main component)
          Expanded(
            child: VoiceVisualization(
              state: visualizationState,
            ),
          ),

          // Control buttons
          Container(
            padding: const EdgeInsets.all(20),
            child: _isConversationActive
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pause button
                      IconButton(
                        icon: const Icon(Icons.pause_circle_outline),
                        onPressed: () {
                          provider.pauseConversation();
                        },
                        tooltip: 'Pause conversation',
                        iconSize: 40,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 20),

                      // Stop button
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined),
                        onPressed: () {
                          provider.stopConversation();
                        },
                        tooltip: 'End conversation',
                        iconSize: 40,
                        color: Colors.redAccent,
                      ),
                    ],
                  )
                : AnimatedMicButton(
                    onPressed: () {
                      debugPrint(
                          'VoiceAgentScreen: User pressed mic button to start conversation');
                      // Always ensure continuous listening is enabled for stable connections
                      provider.setContinuousListening(true);
                      // Start conversation with visual feedback
                      provider.startConversation();
                      // Update local state
                      setState(() {
                        _isConversationActive = true;
                      });
                    },
                    isActive: false,
                    baseColor: Colors.deepPurple,
                  ),
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  // Build a scrollable message list showing all messages
  Widget _buildRecentMessages(List<DeepgramAgentMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      reverse: true, // Start from bottom (most recent)
      itemCount: messages.length,
      itemBuilder: (context, index) {
        // Reverse index to show newest at bottom
        final message = messages[messages.length - 1 - index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar or icon
              CircleAvatar(
                radius: 16,
                backgroundColor: _getMessageColor(message.type),
                child: Icon(
                  _getMessageIcon(message.type),
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              // Message text
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getMessageColor(message.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatMessageTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Format message timestamp
  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  // Get message color based on type
  Color _getMessageColor(DeepgramAgentMessageType type) {
    switch (type) {
      case DeepgramAgentMessageType.user:
        return Colors.blue;
      case DeepgramAgentMessageType.agent:
        return Colors.deepPurple;
      case DeepgramAgentMessageType.system:
        return Colors.grey;
      case DeepgramAgentMessageType.error:
        return Colors.red;
    }
  }

  // Get message icon based on type
  IconData _getMessageIcon(DeepgramAgentMessageType type) {
    switch (type) {
      case DeepgramAgentMessageType.user:
        return Icons.person;
      case DeepgramAgentMessageType.agent:
        return Icons.smart_toy;
      case DeepgramAgentMessageType.system:
        return Icons.info;
      case DeepgramAgentMessageType.error:
        return Icons.error;
    }
  }

  // Build a status indicator that shows the current state
  Widget _buildStatusIndicator(DeepgramAgentState state) {
    IconData icon;
    Color color;

    switch (state) {
      case DeepgramAgentState.idle:
        icon = Icons.circle;
        color = Colors.grey;
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
      default:
        icon = Icons.circle;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 16);
  }

  Widget _buildSettingsDrawer(DeepgramAgentProvider provider) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Voice Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          // Interruptions Toggle
          ListTile(
            leading: Icon(
              provider.disableInterruptionsEnabled ? Icons.volume_up : Icons.mic,
              color: provider.disableInterruptionsEnabled ? Colors.green : Colors.grey,
            ),
            title: Text(provider.disableInterruptionsEnabled 
                ? 'Enable Interruptions' 
                : 'Disable Interruptions'),
            onTap: () {
              provider.setDisableInterruptions(!provider.disableInterruptionsEnabled);
              Navigator.pop(context);
            },
          ),
          const Divider(),
          // Speakerphone Toggle
          ListTile(
            leading: Icon(
              provider.isSpeakerphoneEnabled ? Icons.volume_up : Icons.headset,
              color: provider.isSpeakerphoneEnabled ? Colors.green : Colors.grey,
            ),
            title: Text(provider.isSpeakerphoneEnabled 
                ? 'Use Earphones' 
                : 'Use Loudspeaker'),
            onTap: () {
              provider.toggleSpeakerphone();
              Navigator.pop(context);
            },
          ),
          const Divider(),
          // Image Generation Toggle
          ListTile(
            leading: Icon(
              _imageGenerationEnabled ? Icons.image : Icons.image_not_supported,
              color: _imageGenerationEnabled ? Colors.green : Colors.grey,
            ),
            title: Text(_imageGenerationEnabled 
                ? 'Disable Image Generation' 
                : 'Enable Image Generation'),
            onTap: () {
              setState(() {
                _imageGenerationEnabled = !_imageGenerationEnabled;
              });
              
              // Clear any existing generated image when disabled
              if (!_imageGenerationEnabled) {
                ref.read(generatedImageProvider.notifier).clearImage();
              }
              Navigator.pop(context);
            },
          ),
          const Divider(),
          // Clear Chat History
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Clear Chat History'),
            onTap: () {
              provider.clearHistory();
              Navigator.pop(context);
            },
          ),
          const Divider(),
          // Noise Tolerance Section
          const ListTile(
            title: Text(
              'Noise Tolerance',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // Quiet Environment
          ListTile(
            leading: Icon(
              Icons.volume_down,
              color: provider.noiseTolerance <= 15 ? Colors.green : Colors.grey,
            ),
            title: const Text('Quiet Environment'),
            onTap: () {
              provider.setNoiseTolerance(15.0);
              Navigator.pop(context);
            },
          ),
          // Normal Environment
          ListTile(
            leading: Icon(
              Icons.volume_down,
              color: provider.noiseTolerance > 15 && provider.noiseTolerance <= 25 
                  ? Colors.green : Colors.grey,
            ),
            title: const Text('Normal Environment'),
            onTap: () {
              provider.setNoiseTolerance(25.0);
              Navigator.pop(context);
            },
          ),
          // Noisy Environment
          ListTile(
            leading: Icon(
              Icons.volume_up,
              color: provider.noiseTolerance > 25 && provider.noiseTolerance <= 40 
                  ? Colors.green : Colors.grey,
            ),
            title: const Text('Noisy Environment'),
            onTap: () {
              provider.setNoiseTolerance(40.0);
              Navigator.pop(context);
            },
          ),
          // Very Noisy Environment
          ListTile(
            leading: Icon(
              Icons.volume_up,
              color: provider.noiseTolerance > 40 ? Colors.green : Colors.grey,
            ),
            title: const Text('Very Noisy Environment'),
            onTap: () {
              provider.setNoiseTolerance(55.0);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
