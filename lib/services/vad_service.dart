// lib/services/vad_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vad/vad.dart';

enum VadState {
  idle,
  listening,
  processing,
}

/// Voice Activity Detection service that handles detecting when a user is speaking
class VadService {
  // VAD controller instance
  late dynamic _vadHandler;

  // Stream subscriptions
  StreamSubscription? _speechStartSubscription;
  StreamSubscription? _speechEndSubscription;
  StreamSubscription? _errorSubscription;

  // Speech state
  VadState _state = VadState.idle;
  
  // Timeout to ensure we get a speech end event
  Timer? _forceEndTimeout;
  bool _didForceSpeechEnd = false;

  // Controller for speech events
  final _speechStartController = StreamController<void>.broadcast();
  final _speechEndController = StreamController<List<num>>.broadcast();
  final _errorController = StreamController<Exception>.broadcast();
  final _stateController = StreamController<VadState>.broadcast();

  // Expose streams
  Stream<void> get onSpeechStart => _speechStartController.stream;
  Stream<List<num>> get onSpeechEnd => _speechEndController.stream;
  Stream<Exception> get onError => _errorController.stream;
  Stream<VadState> get onStateChange => _stateController.stream;

  VadState get currentState => _state;

  /// Initialize the VAD service
  Future<bool> initialize() async {
    try {
      // Request microphone permission
      debugPrint('VAD_DEBUG: Requesting microphone permission');
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        debugPrint('VAD_DEBUG: Microphone permission denied: $status');
        _errorController.add(Exception('Microphone permission denied'));
        return false;
      }
      debugPrint('VAD_DEBUG: Microphone permission granted');

      // Initialize VAD Handler
      debugPrint('VAD_DEBUG: Creating VAD handler');
      _vadHandler = VadHandler.create(isDebug: true);
      debugPrint('VAD_DEBUG: VAD handler created successfully');

      // Set up stream subscriptions for VAD events
      _setupStreams();

      return true;
    } catch (e) {
      debugPrint('VAD_DEBUG: Exception during initialization: $e');
      _errorController.add(Exception('Failed to initialize VAD: $e'));
      return false;
    }
  }

  /// Set up stream subscriptions for VAD events
  void _setupStreams() {
    debugPrint('VAD_DEBUG: Setting up event streams');
    
    // Handle speech start events
    _speechStartSubscription = _vadHandler.onSpeechStart?.listen((_) {
      _state = VadState.listening;
      _stateController.add(_state);
      _speechStartController.add(null);
      _didForceSpeechEnd = false;
      debugPrint('VAD_DEBUG: Speech start detected');
      
      // Set a max timeout for speech capture
      _setupForceEndTimeout();
    });

    // Handle speech end events
    _speechEndSubscription = _vadHandler.onSpeechEnd?.listen((audio) {
      _state = VadState.processing;
      _stateController.add(_state);
      _speechEndController.add(audio);
      _cancelForceEndTimeout();
      debugPrint('VAD_DEBUG: Speech end detected, audio length: ${audio.length}, format: ${audio.runtimeType}');
    });

    // Handle error events
    _errorSubscription = _vadHandler.onError?.listen((error) {
      _errorController.add(Exception(error));
      debugPrint('VAD_DEBUG: Error occurred: $error');
    });
    
    debugPrint('VAD_DEBUG: Event streams set up successfully');
  }

  /// Set up a timeout to force a speech end event if none is detected naturally
  void _setupForceEndTimeout() {
    _cancelForceEndTimeout();
    
    _forceEndTimeout = Timer(const Duration(seconds: 10), () {
      if (_state == VadState.listening) {
        debugPrint('VAD_DEBUG: Force-triggering speech end after timeout');
        _didForceSpeechEnd = true;
        
        // Create an empty audio array as we don't have the actual audio data
        final emptyAudio = <num>[];
        
        _state = VadState.processing;
        _stateController.add(_state);
        _speechEndController.add(emptyAudio);
        
        // Stop listening after forcing an end
        stopListening();
      }
    });
  }
  
  /// Cancel the force end timeout
  void _cancelForceEndTimeout() {
    _forceEndTimeout?.cancel();
    _forceEndTimeout = null;
  }

  /// Start listening for voice activity
  Future<void> startListening() async {
    if (_state != VadState.idle) {
      debugPrint('VAD_DEBUG: Already listening or processing, stopping first');
      await stopListening();
    }

    try {
      debugPrint('VAD_DEBUG: Starting VAD listening');
      
      // Start VAD with adjusted parameters for better sensitivity
      _vadHandler.start(
        positiveSpeechThreshold: 0.7,    // Higher means less sensitive
        negativeSpeechThreshold: 0.3,    // Lower means end speech detection is more sensitive
        minSpeechFrames: 3,              // Fewer frames needed to start detecting speech
        redemptionFrames: 15,            // Fewer frames to wait before ending speech
      );
      
      _state = VadState.listening;
      _stateController.add(_state);
      _didForceSpeechEnd = false;
      debugPrint('VAD_DEBUG: VAD listening started successfully');
    } catch (e) {
      debugPrint('VAD_DEBUG: Exception while starting VAD: $e');
      _errorController.add(Exception('Failed to start VAD: $e'));
    }
  }

  /// Stop listening for voice activity
  Future<void> stopListening() async {
    if (_state == VadState.idle) {
      debugPrint('VAD_DEBUG: Already idle, nothing to stop');
      return;
    }

    try {
      debugPrint('VAD_DEBUG: Stopping VAD listening');
      _cancelForceEndTimeout();
      
      _vadHandler.stop();
      _state = VadState.idle;
      _stateController.add(_state);
      debugPrint('VAD_DEBUG: VAD listening stopped successfully');
    } catch (e) {
      debugPrint('VAD_DEBUG: Exception while stopping VAD: $e');
      _errorController.add(Exception('Failed to stop VAD: $e'));
    }
  }

  /// Adjust the sensitivity of the VAD detection
  void adjustSensitivity(double threshold) {
    // Threshold should be between 0 and 1
    // Lower values make the VAD more sensitive (detects more speech)
    if (threshold < 0 || threshold > 1) {
      debugPrint('VAD_DEBUG: Invalid threshold value: $threshold');
      throw ArgumentError('Threshold must be between 0 and 1');
    }

    debugPrint('VAD_DEBUG: Adjusting sensitivity to $threshold');
    
    // Stop and restart with new parameters
    stopListening();
    _vadHandler.start(
      positiveSpeechThreshold: threshold,
      negativeSpeechThreshold: threshold - 0.2, // Adjust negative threshold accordingly
      minSpeechFrames: 3,
      redemptionFrames: 20,
    );
    
    _state = VadState.listening;
    _stateController.add(_state);
    debugPrint('VAD_DEBUG: Sensitivity adjusted successfully');
  }

  /// Clean up resources
  void dispose() {
    debugPrint('VAD_DEBUG: Disposing VAD service');
    stopListening();
    _cancelForceEndTimeout();

    _speechStartSubscription?.cancel();
    _speechEndSubscription?.cancel();
    _errorSubscription?.cancel();

    _speechStartController.close();
    _speechEndController.close();
    _errorController.close();
    _stateController.close();

    _vadHandler.dispose();
    debugPrint('VAD_DEBUG: VAD service disposed successfully');
  }
}