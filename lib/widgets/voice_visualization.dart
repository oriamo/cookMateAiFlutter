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

class _VoiceVisualizationState extends State<VoiceVisualization> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  
  @override
  void initState() {
    super.initState();
    
    // Animation controller for any fallback animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    // Initialize video based on initial state
    _initializeVideo();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _videoController?.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(VoiceVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update video when visualization state changes
    if (widget.state != oldWidget.state) {
      _updateVideoState();
    }
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
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: ClipOval(
              child: _buildVideoPlayer(),
            ),
          ),
        );
      },
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

