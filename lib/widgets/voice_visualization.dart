// lib/widgets/voice_visualization.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

enum VisualizationState {
  idle,
  userSpeaking,
  aiSpeaking,
}

class VoiceVisualization extends StatefulWidget {
  final VisualizationState state;
  
  const VoiceVisualization({
    Key? key, 
    required this.state,
  }) : super(key: key);

  @override
  State<VoiceVisualization> createState() => _VoiceVisualizationState();
}

class _VoiceVisualizationState extends State<VoiceVisualization> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    
    // Animation controller for Lottie
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    // Start animation based on initial state
    if (widget.state == VisualizationState.aiSpeaking) {
      _animationController.repeat();
    } else {
      _animationController.value = 0.5; // Middle frame for idle/listening
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(VoiceVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update animation state when visualization state changes
    if (widget.state != oldWidget.state) {
      _updateAnimationState();
    }
  }
  
  void _updateAnimationState() {
    switch (widget.state) {
      case VisualizationState.idle:
        _animationController.stop();
        _animationController.value = 0.5; // Middle frame for idle
        break;
      case VisualizationState.userSpeaking:
        if (!_animationController.isAnimating) {
          _animationController.repeat(period: const Duration(milliseconds: 1500));
        }
        break;
      case VisualizationState.aiSpeaking:
        if (!_animationController.isAnimating) {
          _animationController.repeat(period: const Duration(milliseconds: 1000));
        }
        break;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.85;
        
        return Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: _buildAnimation(),
          ),
        );
      },
    );
  }
  
  Widget _buildAnimation() {
    // Choose the appropriate animation based on state
    // Check both file naming conventions to be flexible
    final animationPath = widget.state == VisualizationState.aiSpeaking
        ? 'assets/animations/talk.json'  // Try the name you specified first
        : 'assets/animations/listen.json'; // Try the name you specified first
    
    // Fallback to the files we created earlier if needed
    final fallbackPath = widget.state == VisualizationState.aiSpeaking
        ? 'assets/animations/talking.json'
        : 'assets/animations/listening.json';
        
    return Lottie.asset(
      animationPath,
      controller: _animationController,
      animate: widget.state != VisualizationState.idle,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      errorBuilder: (context, error, stackTrace) {
        // Try fallback animation if the first one fails
        return Lottie.asset(
          fallbackPath,
          controller: _animationController,
          animate: widget.state != VisualizationState.idle,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          errorBuilder: (context, error2, stackTrace2) {
            // Ultimate fallback if both animations fail
            return Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.deepPurple.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.deepPurple,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Icon(
                    widget.state == VisualizationState.aiSpeaking
                        ? Icons.volume_up
                        : Icons.mic,
                    size: 48,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Math is used in the layout calculations
import 'dart:math' as math;