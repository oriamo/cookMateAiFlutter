// lib/widgets/voice_visualization.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

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

class _VoiceVisualizationState extends State<VoiceVisualization> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late List<AnimationController> _lineControllers;
  
  final int _numberOfLines = 12; // Number of lines in the visualization
  
  @override
  void initState() {
    super.initState();
    
    // Main pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    // Rotation animation
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    )..repeat();
    
    // Individual line animations
    _lineControllers = List.generate(
      _numberOfLines,
      (index) => AnimationController(
        duration: Duration(milliseconds: 1000 + (index * 100)),
        vsync: this,
      )..repeat(reverse: true),
    );
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    for (var controller in _lineControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  @override
  void didUpdateWidget(VoiceVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update animation speed based on state
    if (widget.state != oldWidget.state) {
      _updateAnimationSpeed();
    }
  }
  
  void _updateAnimationSpeed() {
    switch (widget.state) {
      case VisualizationState.idle:
        _pulseController.duration = const Duration(milliseconds: 1500);
        _rotationController.duration = const Duration(milliseconds: 8000);
        break;
      case VisualizationState.userSpeaking:
        _pulseController.duration = const Duration(milliseconds: 800);
        _rotationController.duration = const Duration(milliseconds: 5000);
        break;
      case VisualizationState.aiSpeaking:
        _pulseController.duration = const Duration(milliseconds: 1000);
        _rotationController.duration = const Duration(milliseconds: 6000);
        break;
    }
    
    // Reset animations to apply the new durations
    _pulseController.reset();
    _pulseController.repeat(reverse: true);
    _rotationController.reset();
    _rotationController.repeat();
  }
  
  @override
  Widget build(BuildContext context) {
    // Different colors based on state
    List<Color> colors;
    switch (widget.state) {
      case VisualizationState.idle:
        colors = [
          Colors.deepPurple.shade300,
          Colors.deepPurple.shade500,
          Colors.deepPurple.shade700,
        ];
        break;
      case VisualizationState.userSpeaking:
        colors = [
          Colors.blue.shade300,
          Colors.deepPurple.shade400,
          Colors.indigo.shade600,
        ];
        break;
      case VisualizationState.aiSpeaking:
        colors = [
          Colors.purple.shade300,
          Colors.pink.shade400,
          Colors.deepPurple.shade500,
        ];
        break;
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.8;
        
        return Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulseController, _rotationController]),
            builder: (context, child) {
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors[1].withOpacity(0.3),
                      blurRadius: 30 * _pulseController.value,
                      spreadRadius: 10 * _pulseController.value,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Base circular gradient
                    Container(
                      width: size * 0.2,
                      height: size * 0.2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            colors[0],
                            colors[1].withOpacity(0.7),
                            colors[2].withOpacity(0.0),
                          ],
                          stops: const [0.1, 0.4, 1.0],
                        ),
                      ),
                    ),
                    
                    // Rotating visualization lines
                    ...List.generate(_numberOfLines, (index) {
                      final angle = (index / _numberOfLines) * 2 * math.pi;
                      final rotationAngle = angle + (_rotationController.value * 2 * math.pi);
                      final lineLength = size * 0.5 * (0.5 + (_lineControllers[index].value * 0.5));
                      
                      return Positioned.fill(
                        child: Center(
                          child: Transform.rotate(
                            angle: rotationAngle,
                            child: AnimatedBuilder(
                              animation: _lineControllers[index],
                              builder: (context, child) {
                                return Container(
                                  width: lineLength,
                                  height: 2.0 + (widget.state == VisualizationState.idle ? 0.0 : 1.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    gradient: LinearGradient(
                                      colors: [
                                        colors[0].withOpacity(0.1),
                                        colors[1],
                                        colors[2].withOpacity(0.3),
                                      ],
                                      stops: const [0.0, 0.7, 1.0],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    }),
                    
                    // Center circle
                    Center(
                      child: Container(
                        width: size * 0.15,
                        height: size * 0.15,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(0.9),
                              colors[0],
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors[1].withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}