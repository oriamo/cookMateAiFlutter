// lib/screens/voice_agent_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/deepgram_agent_provider.dart';
import '../services/deepgram_agent_types.dart';
import '../widgets/waveform_visualization.dart';
import '../widgets/cooking_timer_widget.dart';
import '../providers/timer_provider.dart';
import '../providers/generated_image_provider.dart';

class VoiceAgentScreen extends ConsumerStatefulWidget {
  const VoiceAgentScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<VoiceAgentScreen> createState() => _VoiceAgentScreenState();
}

class _VoiceAgentScreenState extends ConsumerState<VoiceAgentScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isConversationActive = false;
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
        provider.startConversation();
      }
    });
  }

  WaveformState _mapToWaveformState(DeepgramAgentState state) {
    switch (state) {
      case DeepgramAgentState.listening:
        return WaveformState.listening;
      case DeepgramAgentState.speaking:
        return WaveformState.speaking;
      case DeepgramAgentState.processing:
        return WaveformState.processing;
      default:
        return WaveformState.idle;
    }
  }

  String _getStatusText(DeepgramAgentState state) {
    switch (state) {
      case DeepgramAgentState.listening:
        return 'Listening...';
      case DeepgramAgentState.speaking:
        return 'Speaking';
      case DeepgramAgentState.processing:
        return 'Processing...';
      case DeepgramAgentState.connecting:
        return 'Connecting...';
      case DeepgramAgentState.idle:
        return 'Ready';
      default:
        return 'Ready';
    }
  }

  Widget _buildMainScreen(DeepgramAgentProvider provider) {
    final messages = provider.messages;
    final currentMessage = messages.isNotEmpty ? messages.last : null;

    // Set the conversation state
    _isConversationActive = provider.state != DeepgramAgentState.idle;

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
      body: Stack(
        children: [
          // Main content area with dynamic layout
          Consumer(
            builder: (context, ref, child) {
              final imageState = ref.watch(generatedImageProvider);
              final hasSuccessfulImage = _imageGenerationEnabled && 
                  imageState.imageData != null && 
                  imageState.error == null;

              return Column(
                children: [
                  // Main content area with adaptive layout
                  Expanded(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      child: hasSuccessfulImage
                          ? _buildImageCenteredLayout(provider, imageState, currentMessage)
                          : _buildWaveformCenteredLayout(provider, currentMessage),
                    ),
                  ),
              
              // Bottom section for timers and controls
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    // Active Timers display (compact)
                    Consumer(
                      builder: (context, ref, child) {
                        final hasTimers = ref.watch(hasActiveTimersProvider);
                        if (!hasTimers) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: const ActiveTimersPanel(),
                        );
                      },
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
                                  icon: const Icon(Icons.stop_circle),
                                  onPressed: () {
                                    provider.stopConversation();
                                  },
                                  tooltip: 'Stop conversation',
                                  iconSize: 40,
                                  color: Colors.red,
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Start button
                                IconButton(
                                  icon: const Icon(Icons.play_circle_outline),
                                  onPressed: () {
                                    provider.startConversation();
                                  },
                                  tooltip: 'Start conversation',
                                  iconSize: 40,
                                  color: Colors.green,
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
            }
          ),
          
          // Chat transcript overlay (minimally visible)
          _buildChatOverlay(messages),
        ],
      ),
    );
  }

  Widget _buildImageCenteredLayout(DeepgramAgentProvider provider, GeneratedImageState imageState, DeepgramAgentMessage? currentMessage) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Status text (smaller)
        Text(
          _getStatusText(provider.state),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 20),
        
        // Main generated image (center of attention)
        Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    ),
                    child: child,
                  ),
                );
              },
              child: Image.memory(
                imageState.imageData!,
                key: ValueKey(imageState.lastInstruction),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Very compact waveform visualization
        SizedBox(
          height: 30,
          child: WaveformVisualization(
            state: _mapToWaveformState(provider.state),
          ),
        ),
      ],
    );
  }

  Widget _buildWaveformCenteredLayout(DeepgramAgentProvider provider, DeepgramAgentMessage? currentMessage) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Status text
        Text(
          _getStatusText(provider.state),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 40),
        
        // Full-size waveform visualization
        WaveformVisualization(
          state: _mapToWaveformState(provider.state),
        ),
        
        const SizedBox(height: 40),
        
        // Current message display
        if (currentMessage != null)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              currentMessage.content,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildChatOverlay(List<DeepgramAgentMessage> messages) {
    if (messages.length <= 1) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 100,
      right: 16,
      child: GestureDetector(
        onTap: () => _showFullChatHistory(messages),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                '${messages.length} messages',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullChatHistory(List<DeepgramAgentMessage> messages) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Conversation History',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message.type == DeepgramAgentMessageType.user ? Colors.blue.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.type == DeepgramAgentMessageType.user ? 'You' : 'Assistant',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: message.type == DeepgramAgentMessageType.user ? Colors.blue : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(message.content),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final provider = ref.watch(deepgramAgentProvider);
        return _buildMainScreen(provider);
      },
    );
  }

  Widget _buildStatusIndicator(DeepgramAgentState state) {
    IconData icon;
    Color color;

    switch (state) {
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