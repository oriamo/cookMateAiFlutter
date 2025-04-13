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
  late AnimationController _rotationController;
  late AnimationController _waveController;
  late List<AnimationController> _individualControllers;
  
  final int _numberOfCircles = 10; // Number of circular lines
  final List<Color> _circleColors = [];
  final List<double> _circleSizes = [];
  final List<List<double>> _waveAmplitudes = [];
  
  // Random generator for consistent colors and sizes
  final _random = math.Random(42);
  
  @override
  void initState() {
    super.initState();
    
    // Initialize colors and sizes for each circle
    _initializeCircleProperties();
    
    // Main rotation animation
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 10000),
      vsync: this,
    )..repeat();
    
    // Wave animation for AI speaking
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    // Individual animations for each circle
    _individualControllers = List.generate(
      _numberOfCircles,
      (index) => AnimationController(
        duration: Duration(milliseconds: 3000 + (_random.nextInt(5) * 500)),
        vsync: this,
      )..repeat(reverse: true),
    );
    
    _updateAnimationSpeed();
  }
  
  void _initializeCircleProperties() {
    // Base colors to choose from
    final baseColors = [
      Colors.deepPurple,
      Colors.purple,
      Colors.indigo,
      Colors.blue,
      Colors.blueAccent,
      Colors.deepPurple.shade300,
      Colors.purple.shade300,
      Colors.purpleAccent,
      Colors.indigoAccent,
      Colors.blue.shade300,
    ];
    
    // Generate unique colors and sizes for each circle
    for (int i = 0; i < _numberOfCircles; i++) {
      // Get two random colors for the gradient
      final color1 = baseColors[_random.nextInt(baseColors.length)];
      final color2 = baseColors[_random.nextInt(baseColors.length)];
      
      // Create a slightly different shade for each
      final customColor = Color.lerp(
        color1, 
        color2,
        0.3 + (_random.nextDouble() * 0.7),
      )!;
      
      _circleColors.add(customColor);
      
      // Generate a unique size factor (between 0.3 and 0.95)
      final sizeFactor = 0.3 + (0.65 * i / (_numberOfCircles - 1));
      _circleSizes.add(sizeFactor);
      
      // Generate random wave amplitudes for this circle
      // Each circle gets 8 amplitude points around the circle
      final wavePoints = List.generate(
        8, 
        (_) => 0.5 + _random.nextDouble() * 1.5,
      );
      _waveAmplitudes.add(wavePoints);
    }
    
    // Sort sizes to ensure proper layering (largest first)
    _circleSizes.sort((a, b) => b.compareTo(a));
  }
  
  @override
  void dispose() {
    _rotationController.dispose();
    _waveController.dispose();
    for (var controller in _individualControllers) {
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
        _rotationController.duration = const Duration(milliseconds: 15000);
        _waveController.duration = const Duration(milliseconds: 3000);
        _waveController.stop();
        break;
      case VisualizationState.userSpeaking:
        _rotationController.duration = const Duration(milliseconds: 6000);
        _waveController.duration = const Duration(milliseconds: 2000);
        _waveController.stop(); // No wave effect during user speaking
        break;
      case VisualizationState.aiSpeaking:
        _rotationController.duration = const Duration(milliseconds: 10000);
        _waveController.duration = const Duration(milliseconds: 1200);
        if (!_waveController.isAnimating) {
          _waveController.reset();
          _waveController.repeat();
        }
        break;
    }
    
    // Reset rotation animation for smooth transitions
    if (_rotationController.isAnimating) {
      final value = _rotationController.value;
      _rotationController.reset();
      _rotationController.forward(from: value);
    } else {
      _rotationController.repeat();
    }
    
    // Adjust individual circle animations
    for (int i = 0; i < _numberOfCircles; i++) {
      _individualControllers[i].duration = Duration(
        milliseconds: widget.state == VisualizationState.aiSpeaking
            ? 1000 + (_random.nextInt(10) * 200)
            : 3000 + (_random.nextInt(5) * 500),
      );
      
      final value = _individualControllers[i].value;
      _individualControllers[i].reset();
      _individualControllers[i].forward(from: value);
      _individualControllers[i].repeat(reverse: true);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.85;
        
        return Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _rotationController, 
              _waveController,
              ..._individualControllers,
            ]),
            builder: (context, child) {
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background subtle glow
                    Container(
                      width: size * 0.9,
                      height: size * 0.9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    
                    // Circular lines from largest to smallest
                    ...List.generate(_numberOfCircles, (index) {
                      // Get the circle properties
                      final circleColor = _circleColors[index];
                      final circleSize = _circleSizes[index];
                      final waveAmplitudes = _waveAmplitudes[index];
                      
                      // Rotation angle based on index and animation
                      final baseRotation = index % 2 == 0 ? 1.0 : -1.0;
                      final rotationValue = baseRotation * _rotationController.value * 2 * math.pi;
                      final rotationSpeed = 0.3 + (index / _numberOfCircles) * 0.7;
                      
                      // Individual animation for additional variance
                      final individualAnimation = _individualControllers[index].value;
                      
                      return Transform.rotate(
                        angle: rotationValue * rotationSpeed,
                        child: CustomPaint(
                          size: Size(size * circleSize, size * circleSize),
                          painter: CircularLinePainter(
                            color: circleColor,
                            strokeWidth: 2 + (index % 3),
                            waveAmplitudes: waveAmplitudes,
                            wavePhase: widget.state == VisualizationState.aiSpeaking 
                                ? _waveController.value * 2 * math.pi 
                                : 0,
                            individualFactor: individualAnimation,
                            isAiSpeaking: widget.state == VisualizationState.aiSpeaking,
                          ),
                        ),
                      );
                    }),
                    
                    // Center circle
                    Container(
                      width: size * 0.12,
                      height: size * 0.12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.9),
                            Colors.deepPurple.shade300,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
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

/// Custom painter for drawing the circular lines with wave distortion
class CircularLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final List<double> waveAmplitudes;
  final double wavePhase;
  final double individualFactor;
  final bool isAiSpeaking;
  
  CircularLinePainter({
    required this.color,
    required this.strokeWidth,
    required this.waveAmplitudes,
    required this.wavePhase,
    required this.individualFactor,
    required this.isAiSpeaking,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Create gradient shader
    final gradient = SweepGradient(
      colors: [
        color.withOpacity(0.7),
        color,
        color.withOpacity(0.9),
        color.withOpacity(0.7),
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );
    
    final rect = Rect.fromCircle(center: center, radius: radius);
    final shader = gradient.createShader(rect);
    
    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    // Draw circle with wave distortion when AI is speaking
    final path = Path();
    
    // Number of points to draw
    const numPoints = 100;
    
    // If AI is speaking, deform the circle with wave patterns
    if (isAiSpeaking) {
      for (int i = 0; i <= numPoints; i++) {
        final angle = (i / numPoints) * 2 * math.pi;
        
        // Calculate wave distortion
        // Use multiple sine waves with different frequencies for more complex waves
        double waveDistortion = 0;
        
        // Apply multiple wavs based on the amplitude points
        for (int w = 0; w < waveAmplitudes.length; w++) {
          final waveFreq = w + 1;
          final amplitude = waveAmplitudes[w] * individualFactor;
          waveDistortion += math.sin(angle * waveFreq + wavePhase) * amplitude;
        }
        
        // Scale the distortion based on state
        final scaledDistortion = isAiSpeaking ? waveDistortion * strokeWidth : 0;
        
        // Calculate point position
        final x = center.dx + (radius + scaledDistortion) * math.cos(angle);
        final y = center.dy + (radius + scaledDistortion) * math.sin(angle);
        
        // Draw the path
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      // Close the path
      path.close();
    } else {
      // For user speaking or idle, just draw a perfect circle
      path.addOval(rect);
    }
    
    // Draw the path
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CircularLinePainter oldDelegate) {
    return oldDelegate.wavePhase != wavePhase ||
        oldDelegate.individualFactor != individualFactor ||
        oldDelegate.isAiSpeaking != isAiSpeaking;
  }
}