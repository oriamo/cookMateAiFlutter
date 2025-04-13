// lib/widgets/voice_visualization.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:developer' as developer;
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
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _particleController; // For particle effects
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  
  // For advanced animation
  final int _barCount = 18; // Increased for smoother visualization
  final List<double> _barHeights = [];
  final List<Color> _barColors = [];
  final List<Particle> _particles = []; // For particle effect
  
  @override
  void initState() {
    super.initState();
    
    // Primary animation controller for bar animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Pulse animation for the background circle
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );
    
    // Rotation animation for the outer ring
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear)
    );
    
    // Particle animation controller (faster refresh rate)
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(_updateParticles);
    
    // Initialize random bar heights and colors
    _initializeBarValues();
    
    // Start bar animation if needed
    if (widget.state != VisualizationState.idle) {
      _startBarAnimation();
      _particleController.repeat();
    }
    
    // Initialize video based on initial state
    _initializeVideo();
  }
  
  void _initializeBarValues() {
    final random = math.Random();
    
    // Generate random heights for bars
    for (int i = 0; i < _barCount; i++) {
      _barHeights.add(0.3 + random.nextDouble() * 0.2);
    }
    
    // Generate colors from a gradient
    final List<Color> gradientColors = [
      Colors.blue.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.orange.shade400,
      Colors.green.shade400,
    ];
    
    for (int i = 0; i < _barCount; i++) {
      final colorIndex = i % gradientColors.length;
      final nextColorIndex = (i + 1) % gradientColors.length;
      final mixFactor = (i % 1.0);
      
      // Mix colors for smoother gradient
      final Color color = Color.lerp(
        gradientColors[colorIndex],
        gradientColors[nextColorIndex],
        mixFactor,
      )!;
      
      _barColors.add(color);
    }
  }
  
  void _startBarAnimation() {
    // Reset animation controller
    _animationController.reset();
    
    // Define behavior for animation update
    _animationController.addListener(() {
      if (mounted) {
        setState(() {
          // Update bar heights based on state
          for (int i = 0; i < _barHeights.length; i++) {
            if (widget.state == VisualizationState.idle) {
              // In idle state, bars should gradually reduce to minimum height
              _barHeights[i] = math.max(0.1, _barHeights[i] - 0.05);
            } else {
              // In active states, bars should randomly fluctuate
              final random = math.Random();
              final changeAmount = (random.nextDouble() - 0.5) * 0.3;
              
              if (widget.state == VisualizationState.userSpeaking) {
                // User speaking - more active, higher bars
                _barHeights[i] = (_barHeights[i] + changeAmount).clamp(0.3, 0.9);
              } else if (widget.state == VisualizationState.aiSpeaking) {
                // AI speaking - medium activity
                _barHeights[i] = (_barHeights[i] + changeAmount * 0.8).clamp(0.2, 0.7);
              }
            }
          }
        });
      }
    });
    
    // Start animation with repeat
    _animationController.repeat(period: const Duration(milliseconds: 150));
  }
  
  // Update particles and generate new ones based on state
  void _updateParticles() {
    if (!mounted) return;
    
    // Update existing particles
    for (int i = _particles.length - 1; i >= 0; i--) {
      _particles[i].update();
      
      // Remove particles that are too small or transparent
      if (_particles[i].size < 0.5 || _particles[i].opacity < 0.05) {
        _particles.removeAt(i);
      }
    }
    
    // Generate new particles based on state
    if (widget.state != VisualizationState.idle) {
      final random = math.Random();
      final centerX = MediaQuery.of(context).size.width / 2;
      final centerY = MediaQuery.of(context).size.height / 2;
      
      // Determine how many particles to generate based on state
      int particlesToGenerate = 0;
      if (widget.state == VisualizationState.userSpeaking) {
        particlesToGenerate = random.nextInt(3); // More particles during user speech
      } else if (widget.state == VisualizationState.aiSpeaking) {
        particlesToGenerate = random.nextInt(2); // Fewer particles during AI speech
      }
      
      // Generate particles
      for (int i = 0; i < particlesToGenerate; i++) {
        // Generate random position near the center
        final radius = 30.0 + random.nextDouble() * 60.0;
        final angle = random.nextDouble() * 2 * math.pi;
        final posX = centerX + math.cos(angle) * radius;
        final posY = centerY + math.sin(angle) * radius;
        
        // Get a color from the bar colors
        final colorIndex = random.nextInt(_barColors.length);
        
        // Create a new particle
        _particles.add(Particle(
          position: Offset(posX, posY),
          size: 2.0 + random.nextDouble() * 5.0,
          color: _barColors[colorIndex],
          speed: 0.5 + random.nextDouble() * 1.5,
          angle: random.nextDouble() * 2 * math.pi,
          opacity: 0.4 + random.nextDouble() * 0.6,
        ));
      }
    }
    
    // Update UI
    setState(() {});
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _particleController.dispose();
    _videoController?.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(VoiceVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update video when visualization state changes
    if (widget.state != oldWidget.state) {
      _updateVideoState();
      
      // Update animation state based on new state
      if (widget.state == VisualizationState.idle) {
        // Gradually fade out animation
        _animationController.stop();
        _particleController.stop();
        _startBarAnimation(); // For fade-out effect
      } else if (oldWidget.state == VisualizationState.idle) {
        // Start animations if coming from idle
        _startBarAnimation();
        _particleController.repeat();
        
        // Add a burst of particles for visual feedback
        _addParticleBurst();
      } else {
        // State change between active states (user->AI or AI->user)
        // Add a small particle burst for transition
        _addParticleBurst(count: 5);
      }
    }
  }
  
  // Add a burst of particles for visual feedback on state changes
  void _addParticleBurst({int count = 10}) {
    if (!mounted) return;
    
    final random = math.Random();
    final centerX = MediaQuery.of(context).size.width / 2;
    final centerY = MediaQuery.of(context).size.height / 2;
    
    // Generate a burst of particles from center
    for (int i = 0; i < count; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final speed = 1.0 + random.nextDouble() * 3.0;
      
      // Use color based on state
      Color particleColor;
      if (widget.state == VisualizationState.userSpeaking) {
        particleColor = Colors.blue.shade400;
      } else if (widget.state == VisualizationState.aiSpeaking) {
        particleColor = Colors.purple.shade400;
      } else {
        particleColor = _barColors[random.nextInt(_barColors.length)];
      }
      
      _particles.add(Particle(
        position: Offset(centerX, centerY),
        size: 3.0 + random.nextDouble() * 6.0,
        color: particleColor,
        speed: speed,
        angle: angle,
        opacity: 0.7 + random.nextDouble() * 0.3,
      ));
    }
    
    // Force UI update
    setState(() {});
  }
  
  Future<void> _initializeVideo() async {
    // Select appropriate video based on state
    final String videoAsset = widget.state == VisualizationState.aiSpeaking
        ? 'assets/mov/talking.mov'
        : 'assets/mov/listening.mov';
    
    developer.log('Initializing video: $videoAsset', name: 'VoiceVisualization');
    
    try {
      // Dispose of old controller if it exists
      await _videoController?.dispose();
      
      // Create and initialize new controller
      _videoController = VideoPlayerController.asset(videoAsset);
      await _videoController!.initialize();
      
      // Set to loop and update state
      _videoController!.setLooping(true);
      _isVideoInitialized = true;
      
      // Start/stop video based on current state
      _updateVideoState();
      
      // Force UI update
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      developer.log('Error initializing video: $e', name: 'VoiceVisualization');
      _isVideoInitialized = false;
      if (mounted) {
        setState(() {});
      }
    }
  }
  
  void _updateVideoState() {
    if (_videoController == null || !_isVideoInitialized) {
      _initializeVideo();
      return;
    }
    
    // Check if we need to switch videos
    if ((_videoController!.dataSource.contains('talking.mov') && widget.state != VisualizationState.aiSpeaking) ||
        (_videoController!.dataSource.contains('listening.mov') && widget.state == VisualizationState.aiSpeaking)) {
      _initializeVideo();
      return;
    }
    
    // Otherwise just play/pause current video
    switch (widget.state) {
      case VisualizationState.idle:
        _videoController!.pause();
        break;
      case VisualizationState.userSpeaking:
      case VisualizationState.aiSpeaking:
        if (!_videoController!.value.isPlaying) {
          _videoController!.play();
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer rotating gradient ring
              AnimatedBuilder(
                animation: _rotateAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotateAnimation.value,
                    child: Container(
                      width: size * 1.1,
                      height: size * 1.1,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Colors.blue.shade400,
                            Colors.purple.shade400,
                            Colors.red.shade400,
                            Colors.orange.shade400,
                            Colors.blue.shade400,
                          ],
                          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              // Circular mask for the ring
              Container(
                width: size * 1.07,
                height: size * 1.07,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
              ),
              
              // Background pulsing circle
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  // Determine background color based on state
                  Color bgColor;
                  switch (widget.state) {
                    case VisualizationState.idle:
                      bgColor = Colors.grey.shade200;
                      break;
                    case VisualizationState.userSpeaking:
                      bgColor = Colors.blue.shade100;
                      break;
                    case VisualizationState.aiSpeaking:
                      bgColor = Colors.purple.shade100;
                      break;
                  }
                  
                  return Transform.scale(
                    scale: widget.state == VisualizationState.idle ? 1.0 : _pulseAnimation.value,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bgColor,
                        boxShadow: [
                          BoxShadow(
                            color: bgColor.withOpacity(0.5),
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              // Main content (video or animation)
              Container(
                width: size * 0.9,
                height: size * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _buildVideoPlayer(),
                ),
              ),
              
              // Visualization bars (will show around the edge when video is not available)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _isVideoInitialized ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: _buildBars(size),
                ),
              ),
              
              // Improved status indicator with animation
              Positioned(
                bottom: 10,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor().withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: widget.state == VisualizationState.idle ? 1 : 3,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated icon
                      AnimatedSwitcher(
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
                          _getStatusIcon(),
                          key: ValueKey<VisualizationState>(widget.state),
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status text with animation
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.3, 0.0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          _getStatusText(),
                          key: ValueKey<String>(_getStatusText()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      // Adding animated dots for listening/speaking
                      if (widget.state != VisualizationState.idle) ...[
                        const SizedBox(width: 4),
                        _buildAnimatedDots(),
                      ],
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
  
  Widget _buildBars(double size) {
    return CustomPaint(
      size: Size(size, size),
      painter: BarVisualizer(
        barCount: _barCount,
        barHeights: _barHeights,
        barColors: _barColors,
        state: widget.state,
        particles: _particles,
      ),
    );
  }
  
  Widget _buildVideoPlayer() {
    if (_videoController != null && _isVideoInitialized) {
      // Return the video player when initialized
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      );
    } else {
      // Return a placeholder while video is loading
      return _buildPlaceholderAnimation();
    }
  }
  
  Widget _buildPlaceholderAnimation() {
    // Ultimate fallback if video fails to load
    developer.log('Using placeholder animation', name: 'VoiceVisualization');
    
    // Choose icon based on state
    IconData icon;
    switch (widget.state) {
      case VisualizationState.idle:
        icon = Icons.mic_none;
        break;
      case VisualizationState.userSpeaking:
        icon = Icons.mic;
        break;
      case VisualizationState.aiSpeaking:
        icon = Icons.volume_up;
        break;
    }
    
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.state == VisualizationState.idle ? 1.0 : _pulseAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getStatusColor().withOpacity(0.2),
                border: Border.all(
                  color: _getStatusColor(),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Icon(
                  icon,
                  size: 48,
                  color: _getStatusColor(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Color _getStatusColor() {
    switch (widget.state) {
      case VisualizationState.idle:
        return Colors.grey.shade500;
      case VisualizationState.userSpeaking:
        return Colors.blue.shade600;
      case VisualizationState.aiSpeaking:
        return Colors.purple.shade600;
    }
  }
  
  IconData _getStatusIcon() {
    switch (widget.state) {
      case VisualizationState.idle:
        return Icons.mic_off;
      case VisualizationState.userSpeaking:
        return Icons.mic;
      case VisualizationState.aiSpeaking:
        return Icons.volume_up;
    }
  }
  
  String _getStatusText() {
    switch (widget.state) {
      case VisualizationState.idle:
        return 'Ready';
      case VisualizationState.userSpeaking:
        return 'Listening';
      case VisualizationState.aiSpeaking:
        return 'Speaking';
    }
  }
  
  // Build animated dots for active states (listening/speaking)
  Widget _buildAnimatedDots() {
    return SizedBox(
      width: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end, 
        children: List.generate(3, (index) {
          // Use different delays for each dot
          return Padding(
            padding: EdgeInsets.only(left: index > 0 ? 2 : 0),
            child: _AnimatedDot(
              delay: index * 0.2,
            ),
          );
        }),
      ),
    );
  }
}

// Separated animated dot widget for cleaner animation cycles
class _AnimatedDot extends StatefulWidget {
  final double delay;
  
  const _AnimatedDot({
    Key? key,
    required this.delay,
  }) : super(key: key);
  
  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Create delayed, repeating animation
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(widget.delay, widget.delay + 0.5, curve: Curves.easeInOut),
      ),
    );
    
    // Start with delay based on index
    Future.delayed(Duration(milliseconds: (widget.delay * 300).toInt()), () {
      if (mounted) {
        _controller.repeat();
      }
    });
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
        // Calculate current value with pulse effect
        final pulseValue = math.sin(_animation.value * math.pi);
        
        return Transform.scale(
          scale: 0.5 + (pulseValue * 0.5),
          child: Opacity(
            opacity: 0.4 + (pulseValue * 0.6),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

// Particle class for enhanced visualization
class Particle {
  Offset position;
  double size;
  Color color;
  double speed;
  double angle;
  double opacity;
  
  Particle({
    required this.position,
    required this.size,
    required this.color,
    required this.speed,
    required this.angle,
    required this.opacity,
  });
  
  void update() {
    // Move particle based on angle and speed
    position = Offset(
      position.dx + math.cos(angle) * speed,
      position.dy + math.sin(angle) * speed
    );
    
    // Gradually decrease opacity
    opacity = (opacity * 0.98).clamp(0.0, 1.0);
    
    // Gradually decrease size
    size = size * 0.97;
  }
}

// Custom painter for bar visualization
class BarVisualizer extends CustomPainter {
  final int barCount;
  final List<double> barHeights;
  final List<Color> barColors;
  final VisualizationState state;
  final List<Particle> particles;
  
  BarVisualizer({
    required this.barCount,
    required this.barHeights,
    required this.barColors,
    required this.state,
    this.particles = const [],
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Draw the subtle background glow effect
    if (state != VisualizationState.idle) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            state == VisualizationState.userSpeaking
                ? Colors.blue.withOpacity(0.3)
                : Colors.purple.withOpacity(0.3),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(center, radius * 0.9, glowPaint);
    }
    
    // Draw bars around the circle
    for (int i = 0; i < barCount; i++) {
      final angle = 2 * math.pi * i / barCount;
      
      // Calculate bar dimensions - use smoother variation with sine wave
      final double barHeight = barHeights[i] * radius * 0.4;
      final double barWidth = state == VisualizationState.idle ? 8 : 10;
      
      // Calculate bar position with slight outward offset
      final double outwardOffset = state == VisualizationState.idle ? 0 : 5;
      final double startX = center.dx + math.cos(angle) * (radius - barHeight - outwardOffset);
      final double startY = center.dy + math.sin(angle) * (radius - barHeight - outwardOffset);
      final double endX = center.dx + math.cos(angle) * (radius + outwardOffset);
      final double endY = center.dy + math.sin(angle) * (radius + outwardOffset);
      
      // Draw bar with gradient
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            barColors[i].withOpacity(state == VisualizationState.idle ? 0.3 : 0.7),
            barColors[i].withOpacity(state == VisualizationState.idle ? 0.5 : 1.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromPoints(Offset(startX, startY), Offset(endX, endY)))
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );
    }
    
    // Draw particles
    for (final particle in particles) {
      final particlePaint = Paint()
        ..color = particle.color.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        particle.position,
        particle.size,
        particlePaint,
      );
      
      // Draw glow effect for larger particles
      if (particle.size > 3) {
        final glowPaint = Paint()
          ..color = particle.color.withOpacity(particle.opacity * 0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        
        canvas.drawCircle(
          particle.position,
          particle.size * 1.8,
          glowPaint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(BarVisualizer oldDelegate) {
    return oldDelegate.barHeights != barHeights || 
           oldDelegate.state != state || 
           oldDelegate.particles.length != particles.length; // Consider particles
  }
}