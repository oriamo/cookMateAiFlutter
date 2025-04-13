// lib/widgets/pulsing_dot.dart
import 'package:flutter/material.dart';

// A pulsing dot widget for the animated mic button
class PulsingDot extends StatefulWidget {
  final Color color;
  
  const PulsingDot({
    Key? key,
    required this.color,
  }) : super(key: key);
  
  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 4 + (_animation.value * 2),
          height: 4 + (_animation.value * 2),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.5 + (_animation.value * 0.5)),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3 * _animation.value),
                blurRadius: 4,
                spreadRadius: _animation.value * 2,
              ),
            ],
          ),
        );
      },
    );
  }
}