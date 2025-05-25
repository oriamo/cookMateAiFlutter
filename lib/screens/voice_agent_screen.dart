// lib/screens/voice_agent_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/deepgram_agent_provider.dart';
import '../services/deepgram_agent_types.dart';
import '../widgets/voice_visualization.dart';
import '../widgets/animated_mic_button.dart';
import '../widgets/message_bubble.dart';
import '../widgets/cooking_timer_widget.dart';
import '../providers/timer_provider.dart';
import '../services/message_processor.dart';
import '../services/cooking_session_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VoiceAgentScreen extends ConsumerStatefulWidget {
  const VoiceAgentScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<VoiceAgentScreen> createState() => _VoiceAgentScreenState();
}

class _VoiceAgentScreenState extends ConsumerState<VoiceAgentScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isConversationActive = false;
  bool _stepListenerAttached = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check if we should auto-start the conversation
    // Use a post-frame callback to ensure this runs after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = ref.read(deepgramAgentProvider);
      // Only auto-start if navigated to and not already running
      if (!_isConversationActive && provider.state == DeepgramAgentState.idle) {
        debugPrint('VoiceAgentScreen: Auto-starting conversation with continuous listening enabled');
        
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
              RegExp(r"(?:let'?s\s*)?(?:move on to|start with|begin with|go to)\s*step\s+(\d+)", caseSensitive: false),
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
            if (content.contains('previous step') || content.contains('last step')) {
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
            const Text('Live Voice Conversation'),
            const SizedBox(width: 10),
            _buildStatusIndicator(provider.state),
          ],
        ),
        actions: [
          // Noise & Interruption settings
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            tooltip: 'Voice settings',
            onSelected: (String value) {
              switch (value) {
                case 'toggleInterruptions':
                  // Toggle interruptions
                  provider.setDisableInterruptions(!provider.disableInterruptionsEnabled);
                  break;
                case 'lowNoise':
                  // Set low noise tolerance for quiet environments
                  provider.setNoiseTolerance(15.0);
                  break;
                case 'mediumNoise':
                  // Set medium noise tolerance
                  provider.setNoiseTolerance(25.0);
                  break;
                case 'highNoise':
                  // Set high noise tolerance for noisy environments
                  provider.setNoiseTolerance(40.0);
                  break;
                case 'veryHighNoise':
                  // Set very high noise tolerance for extremely noisy environments
                  provider.setNoiseTolerance(55.0);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'toggleInterruptions',
                child: Row(
                  children: [
                    Icon(
                      provider.disableInterruptionsEnabled
                          ? Icons.volume_up
                          : Icons.mic,
                      color: provider.disableInterruptionsEnabled
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Text(provider.disableInterruptionsEnabled
                        ? 'Enable Interruptions'
                        : 'Disable Interruptions'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: '',
                enabled: false,
                child: Text('Noise Tolerance:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              PopupMenuItem<String>(
                value: 'lowNoise',
                child: Row(
                  children: [
                    Icon(Icons.volume_down,
                        color: provider.noiseTolerance <= 15 ? Colors.green : Colors.grey),
                    const SizedBox(width: 10),
                    const Text('Quiet Environment'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'mediumNoise',
                child: Row(
                  children: [
                    Icon(Icons.volume_down,
                        color: provider.noiseTolerance > 15 &&
                                provider.noiseTolerance <= 25
                            ? Colors.green
                            : Colors.grey),
                    const SizedBox(width: 10),
                    const Text('Normal Environment'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'highNoise',
                child: Row(
                  children: [
                    Icon(Icons.volume_up,
                        color: provider.noiseTolerance > 25 &&
                                provider.noiseTolerance <= 40
                            ? Colors.green
                            : Colors.grey),
                    const SizedBox(width: 10),
                    const Text('Noisy Environment'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'veryHighNoise',
                child: Row(
                  children: [
                    Icon(Icons.volume_up,
                        color: provider.noiseTolerance > 40
                            ? Colors.green
                            : Colors.grey),
                    const SizedBox(width: 10),
                    const Text('Very Noisy Environment'),
                  ],
                ),
              ),
            ],
          ),
          // Toggle speakerphone/earphone output
          IconButton(
            icon: Icon(
              provider.isSpeakerphoneEnabled
                  ? Icons.volume_up
                  : Icons.headset,
              color: provider.isSpeakerphoneEnabled
                  ? Colors.green
                  : Colors.grey,
            ),
            tooltip: provider.isSpeakerphoneEnabled
                ? 'Use Earphones'
                : 'Use Loudspeaker',
            onPressed: () {
              provider.toggleSpeakerphone();
            },
          ),
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
          // Recent messages (limited to displaying last 2 messages)
          Container(
            height: 120,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: messages.isNotEmpty 
              ? _buildRecentMessages(messages)
              : const Center(child: Text('Start speaking to begin a conversation')),
          ),

          // Active Timers display (shows only when timers are active)
          Consumer(
            builder: (context, ref, child) {
              final hasTimers = ref.watch(hasActiveTimersProvider);
              if (!hasTimers) return const SizedBox.shrink();
              return ActiveTimersPanel();
            },
          ),
          // Current step image (updates on CookingSession changes)
          if (ref.watch(cookingSessionProvider)?.currentStep != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: CachedNetworkImage(
                imageUrl: ref.watch(cookingSessionProvider)!.currentStep!.imageUrl,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 48),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          
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
                    debugPrint('VoiceAgentScreen: User pressed mic button to start conversation');
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
  
  // Build a limited message list showing only the most recent messages
  Widget _buildRecentMessages(List<DeepgramAgentMessage> messages) {
    // Get the most recent messages (up to 2)
    final int startIndex = messages.length > 2 ? messages.length - 2 : 0;
    final recentMessages = messages.sublist(startIndex);
    
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: recentMessages.length,
      itemBuilder: (context, index) {
        final message = recentMessages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
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
                  child: Text(
                    message.content,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
}