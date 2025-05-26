// lib/widgets/waveform_visualization.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

enum WaveformState {
  idle,
  listening,
  speaking,
  processing,
}

class WaveformVisualization extends StatefulWidget {
  final WaveformState state;

  const WaveformVisualization({
    Key? key,
    required this.state,
  }) : super(key: key);

  @override
  State<WaveformVisualization> createState() => _WaveformVisualizationState();
}

class _WaveformVisualizationState extends State<WaveformVisualization>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  
  final int _barCount = 60;
  final List<double> _barHeights = [];
  
  @override
  void initState() {
    super.initState();
    
    // Initialize bar heights
    for (int i = 0; i < _barCount; i++) {
      _barHeights.add(0.1);
    }
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240), // Slowed down by 60% (150 * 1.6)
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200), // Slowed down by 60% (2000 * 1.6)
    );
    
    _updateAnimation();
  }

  @override
  void didUpdateWidget(WaveformVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    switch (widget.state) {
      case WaveformState.idle:
        _animationController.stop();
        _pulseController.repeat();
        _generateIdlePattern();
        break;
      case WaveformState.listening:
        _pulseController.stop();
        _animationController.repeat();
        _generateListeningPattern();
        break;
      case WaveformState.speaking:
        _pulseController.stop();
        _animationController.repeat();
        _generateSpeakingPattern();
        break;
      case WaveformState.processing:
        _pulseController.stop();
        _animationController.repeat();
        _generateProcessingPattern();
        break;
    }
  }

  void _generateIdlePattern() {
    for (int i = 0; i < _barCount; i++) {
      _barHeights[i] = 0.1 + (math.sin(i * 0.3) * 0.05).abs();
    }
  }

  void _generateListeningPattern() {
    _animationController.addListener(() {
      setState(() {
        for (int i = 0; i < _barCount; i++) {
          final phase = (_animationController.value * 2 * math.pi) + (i * 0.2);
          _barHeights[i] = 0.2 + (math.sin(phase) * 0.4).abs();
        }
      });
    });
  }

  void _generateSpeakingPattern() {
    _animationController.addListener(() {
      setState(() {
        for (int i = 0; i < _barCount; i++) {
          final phase1 = (_animationController.value * 4 * math.pi) + (i * 0.15);
          final phase2 = (_animationController.value * 6 * math.pi) + (i * 0.1);
          final height1 = (math.sin(phase1) * 0.5).abs();
          final height2 = (math.sin(phase2) * 0.3).abs();
          _barHeights[i] = 0.1 + height1 + height2;
        }
      });
    });
  }

  void _generateProcessingPattern() {
    _animationController.addListener(() {
      setState(() {
        for (int i = 0; i < _barCount; i++) {
          final wave = (_animationController.value * 3 + i * 0.1) % 1.0;
          _barHeights[i] = 0.1 + (math.sin(wave * 2 * math.pi) * 0.6).abs();
        }
      });
    });
  }

  Color _getBarColor() {
    switch (widget.state) {
      case WaveformState.idle:
        return Colors.grey.shade400;
      case WaveformState.listening:
        return Colors.green;
      case WaveformState.speaking:
        return Colors.blue;
      case WaveformState.processing:
        return Colors.orange;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      child: AnimatedBuilder(
        animation: Listenable.merge([_animationController, _pulseController]),
        builder: (context, child) {
          return CustomPaint(
            painter: WaveformPainter(
              barHeights: _barHeights,
              barColor: _getBarColor(),
              state: widget.state,
              pulseValue: _pulseController.value,
            ),
          );
        },
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> barHeights;
  final Color barColor;
  final WaveformState state;
  final double pulseValue;

  WaveformPainter({
    required this.barHeights,
    required this.barColor,
    required this.state,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final barWidth = size.width / barHeights.length;
    final centerY = size.height / 2;

    for (int i = 0; i < barHeights.length; i++) {
      final barHeight = barHeights[i] * size.height * 0.8;
      final x = i * barWidth;
      
      // Create rounded rectangle for each bar
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x + barWidth * 0.2,
          centerY - barHeight / 2,
          barWidth * 0.6,
          barHeight,
        ),
        Radius.circular(barWidth * 0.3),
      );

      // Add subtle gradient effect
      if (state == WaveformState.idle) {
        paint.color = barColor.withOpacity(0.3 + (pulseValue * 0.4));
      } else {
        // Fade effect from center outward
        final distanceFromCenter = (i - barHeights.length / 2).abs();
        final maxDistance = barHeights.length / 2;
        final fadeOpacity = 1.0 - (distanceFromCenter / maxDistance) * 0.3;
        paint.color = barColor.withOpacity(fadeOpacity);
      }

      canvas.drawRRect(rect, paint);
    }

    // Add center glow effect for speaking state
    if (state == WaveformState.speaking) {
      final glowPaint = Paint()
        ..color = barColor.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(size.width / 2, centerY),
        size.width * 0.3,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}