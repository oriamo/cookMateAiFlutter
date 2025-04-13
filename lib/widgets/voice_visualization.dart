// lib/widgets/voice_visualization.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'dart:io' as io;
import 'dart:developer' as developer;
import 'package:flutter/services.dart' show rootBundle;

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

class _VoiceVisualizationState extends State<VoiceVisualization> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  bool _debugChecked = false;
  String _debugMessage = '';
  bool _useJsonFallback = false;
  bool _useDotLottieFallback = false;
  
  // Animation files to try in order of preference
  final List<String> _animationFiles = [
    'assets/animations/listen.json',
    'assets/animations/talk.json',
    'assets/animations/listening.json',
    'assets/animations/talking.json',
    'assets/animations/listen.lottie',
    'assets/animations/talk.lottie',
    'assets/animations/listening.lottie',
    'assets/animations/talking.lottie',
  ];
  
  // Store which animation files actually exist
  final Map<String, bool> _fileExists = {};
  
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
    
    // Check which animation files exist
    _checkAnimationFiles();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  // Check which animation files actually exist
  Future<void> _checkAnimationFiles() async {
    if (_debugChecked) return;
    
    try {
      StringBuffer debug = StringBuffer('Animation file status:\n');
      
      for (final file in _animationFiles) {
        try {
          await rootBundle.load(file);
          _fileExists[file] = true;
          debug.write('✅ $file exists\n');
        } catch (e) {
          _fileExists[file] = false;
          debug.write('❌ $file does not exist: $e\n');
        }
      }
      
      _debugMessage = debug.toString();
      developer.log(_debugMessage, name: 'VoiceVisualization');
      _debugChecked = true;
      
      // Make sure to update the UI after we've checked the files
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      developer.log('Error checking animation files: $e', name: 'VoiceVisualization');
    }
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
            child: Stack(
              children: [
                _buildAnimation(),
                
                // Show debug overlay in debug mode
                if (_debugMessage.isNotEmpty && false) // Set to true to see debug info
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.black.withOpacity(0.7),
                      child: Text(
                        _debugMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildAnimation() {
    // Select the appropriate animation file based on state
    final String preferredFile = widget.state == VisualizationState.aiSpeaking
        ? 'assets/animations/talk.json'  // Main talking animation
        : 'assets/animations/listen.json'; // Main listening animation
    
    final String fallbackJsonFile = widget.state == VisualizationState.aiSpeaking
        ? 'assets/animations/talking.json' // Fallback talking animation
        : 'assets/animations/listening.json'; // Fallback listening animation
    
    final String dotLottieFile = widget.state == VisualizationState.aiSpeaking
        ? 'assets/animations/talking.lottie' // DotLottie talking animation
        : 'assets/animations/listening.lottie'; // DotLottie listening animation
    
    // Log which file we're trying to use
    developer.log('Trying to use animation file: $preferredFile', name: 'VoiceVisualization');
    
    // Check if file exists first to avoid unnecessary error
    if (_debugChecked && _fileExists[preferredFile] == true) {
      return Lottie.asset(
        preferredFile,
        controller: _animationController,
        animate: widget.state != VisualizationState.idle,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) {
          developer.log('Error loading preferred animation $preferredFile: $error', name: 'VoiceVisualization');
          _useJsonFallback = true;
          return _buildFallbackJsonAnimation(fallbackJsonFile);
        },
      );
    } else if (_debugChecked && _fileExists[fallbackJsonFile] == true) {
      return _buildFallbackJsonAnimation(fallbackJsonFile);
    } else if (_debugChecked && _fileExists[dotLottieFile] == true) {
      return _buildDotLottieAnimation(dotLottieFile);
    } else {
      // If we haven't checked files yet or no files exist
      return _buildPlaceholderAnimation();
    }
  }
  
  Widget _buildFallbackJsonAnimation(String file) {
    developer.log('Using fallback animation file: $file', name: 'VoiceVisualization');
    return Lottie.asset(
      file,
      controller: _animationController,
      animate: widget.state != VisualizationState.idle,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      errorBuilder: (context, error, stackTrace) {
        developer.log('Error loading fallback animation $file: $error', name: 'VoiceVisualization');
        _useDotLottieFallback = true;
        return _buildDotLottieAnimation(widget.state == VisualizationState.aiSpeaking
            ? 'assets/animations/talking.lottie'
            : 'assets/animations/listening.lottie');
      },
    );
  }
  
  Widget _buildDotLottieAnimation(String file) {
    developer.log('Using DotLottie animation file: $file', name: 'VoiceVisualization');
    return DotLottieLoader.fromAsset(
      file,
      controller: _animationController,
      animate: widget.state != VisualizationState.idle,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        developer.log('Error loading DotLottie animation $file: $error', name: 'VoiceVisualization');
        return _buildPlaceholderAnimation();
      },
    );
  }
  
  Widget _buildPlaceholderAnimation() {
    // Ultimate fallback if all animations fail
    developer.log('Using placeholder animation', name: 'VoiceVisualization');
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
  }
}

