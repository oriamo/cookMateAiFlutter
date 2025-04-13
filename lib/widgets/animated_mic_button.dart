// lib/widgets/animated_mic_button.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedMicButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isActive;
  final Color? baseColor;
  final Color? activeColor;
  
  const AnimatedMicButton({
    Key? key,
    required this.onPressed,
    this.isActive = false,
    this.baseColor,
    this.activeColor,
  }) : super(key: key);

  @override
  State<AnimatedMicButton> createState() => _AnimatedMicButtonState();
}

class _AnimatedMicButtonState extends State<AnimatedMicButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
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
    final baseColor = widget.baseColor ?? Colors.deepPurple;
    final activeColor = widget.activeColor ?? Colors.purple;
    final currentColor = widget.isActive ? activeColor : baseColor;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 140,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  currentColor,
                  currentColor.withBlue((currentColor.blue + 40).clamp(0, 255)),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: currentColor.withOpacity(0.5),
                  blurRadius: 8 * (widget.isActive ? _pulseAnimation.value : 1.0),
                  spreadRadius: 2 * (widget.isActive ? _pulseAnimation.value : 1.0),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Rotating gradient overlay for active state
                if (widget.isActive)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Container(
                        width: 140,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: SweepGradient(
                            colors: [
                              currentColor,
                              activeColor.withOpacity(0.5),
                              currentColor,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // Button content
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isActive ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isActive ? 'Active' : 'Start',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}