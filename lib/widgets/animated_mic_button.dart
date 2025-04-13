// lib/widgets/animated_mic_button.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'pulsing_dot.dart';

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
  late Animation<double> _scaleAnimation;
  final List<Color> _randomColors = [
    Colors.red,
    Colors.blue.shade700,
    Colors.purple,
    Colors.teal.shade700,
    Colors.orange.shade800,
  ];
  
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
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
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
    final activeColor = widget.activeColor ?? Colors.green;
    final currentColor = widget.isActive ? activeColor : baseColor;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GestureDetector(
          onTap: widget.onPressed,
          child: Transform.scale(
            scale: widget.isActive ? _scaleAnimation.value : 1.0,
            child: Container(
              width: 160,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
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
                    blurRadius: 12 * (widget.isActive ? _pulseAnimation.value : 1.0),
                    spreadRadius: 3 * (widget.isActive ? _pulseAnimation.value : 1.0),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Enhanced animated background particles for active state
                  if (widget.isActive)
                    ...List.generate(8, (index) {
                      final random = math.Random(index);
                      final randomAngle = random.nextDouble() * math.pi * 2;
                      final randomDistance = (40.0 + (random.nextDouble() * 20.0)) * _pulseAnimation.value;
                      final randomColor = _randomColors[index % _randomColors.length];
                      final randomSize = 6.0 + (random.nextDouble() * 4.0);
                      final speedMultiplier = 0.8 + (random.nextDouble() * 0.4);
                      
                      // Calculate initial position
                      final baseX = 80 + math.cos(randomAngle) * randomDistance;
                      final baseY = 30 + math.sin(randomAngle) * randomDistance / 2;
                      
                      // Add some wobble movement
                      final wobbleX = math.sin(_rotationAnimation.value * speedMultiplier * 2) * 5;
                      final wobbleY = math.cos(_rotationAnimation.value * speedMultiplier * 2) * 3;
                      
                      return Positioned(
                        left: baseX + wobbleX,
                        top: baseY + wobbleY,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 800),
                          builder: (context, value, child) {
                            // Fade in the particles
                            return Opacity(
                              opacity: 0.7 * _pulseAnimation.value * value,
                              child: Transform.scale(
                                scale: value,
                                child: Container(
                                  width: randomSize,
                                  height: randomSize,
                                  decoration: BoxDecoration(
                                    color: randomColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: randomColor.withOpacity(0.7),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.white,
                                        randomColor,
                                      ],
                                      stops: const [0.2, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  
                  // Enhanced rotating gradient overlay for active state
                  if (widget.isActive)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Stack(
                        children: [
                          // Base rotating gradient layer
                          Transform.rotate(
                            angle: _rotationAnimation.value,
                            child: Container(
                              width: 160,
                              height: 60,
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
                          // Additional shimmer effect
                          Transform.rotate(
                            angle: -_rotationAnimation.value * 0.7, // Rotate in opposite direction
                            child: Opacity(
                              opacity: 0.4,
                              child: Container(
                                width: 160,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.0),
                                      Colors.white.withOpacity(0.6),
                                      Colors.white.withOpacity(0.0),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Enhanced button content with animated icon and text effects
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated icon with pulse effect
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: widget.isActive ? 28 : 24,
                        width: widget.isActive ? 28 : 24,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Icon(
                            widget.isActive ? Icons.mic : Icons.mic_none,
                            key: ValueKey(widget.isActive),
                            color: Colors.white,
                            size: widget.isActive ? 24 : 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Animated text with transitions
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.3),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          widget.isActive ? 'Listening...' : 'Start Talking',
                          key: ValueKey(widget.isActive),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: widget.isActive ? 17 : 16,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(widget.isActive ? 0.4 : 0.2),
                                blurRadius: widget.isActive ? 4 : 2,
                                offset: Offset(0, widget.isActive ? 2 : 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Animated dot for listening state
                      if (widget.isActive)
                        Padding(
                          padding: const EdgeInsets.only(left: 2.0),
                          child: PulsingDot(color: Colors.white),
                        ),
                    ],
                  ),
                  
                  // Subtle border overlay
                  Container(
                    width: 160,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}