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
  late VadHandler _vadHandler;

  // Stream subscriptions
  StreamSubscription? _speechStartSubscription;
  StreamSubscription? _speechEndSubscription;
  StreamSubscription? _errorSubscription;

  // Speech state
  VadState _state = VadState.idle;

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
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        _errorController.add(Exception('Microphone permission denied'));
        return false;
      }

      // Initialize VAD Handler
      _vadHandler = VadHandler.create(isDebug: true);

      // Set up stream subscriptions for VAD events
      _setupStreams();

      return true;
    } catch (e) {
      _errorController.add(Exception('Failed to initialize VAD: $e'));
      return false;
    }
  }

  /// Set up stream subscriptions for VAD events
  void _setupStreams() {
    // Handle speech start events
    _speechStartSubscription = _vadHandler.onSpeechStart.listen((_) {
      _state = VadState.listening;
      _stateController.add(_state);
      _speechStartController.add(null);
      debugPrint('VAD: Speech started');
    });

    // Handle speech end events
    _speechEndController.add([]);
    _speechEndSubscription = _vadHandler.onSpeechEnd.listen((audio) {
      _state = VadState.processing;
      _stateController.add(_state);
      _speechEndController.add(audio);
      debugPrint('VAD: Speech ended');
    });

    // Handle error events
    _errorSubscription = _vadHandler.onError.listen((error) {
      _errorController.add(error);
      debugPrint('VAD Error: ${error.toString()}');
    });
  }

  /// Start listening for voice activity
  Future<void> startListening() async {
    if (_state != VadState.idle) return;

    try {
      // Start VAD with default parameters
      _vadHandler.startListening(
        positiveSpeechThreshold: 0.5,
        negativeSpeechThreshold: 0.35,
        minSpeechFrames: 5,
        redemptionFrames: 30,
      );
      _state = VadState.listening;
      _stateController.add(_state);
      debugPrint('VAD: Started listening');
    } catch (e) {
      _errorController.add(Exception('Failed to start VAD: $e'));
    }
  }

  /// Stop listening for voice activity
  Future<void> stopListening() async {
    if (_state == VadState.idle) return;

    try {
      _vadHandler.stopListening();
      _state = VadState.idle;
      _stateController.add(_state);
      debugPrint('VAD: Stopped listening');
    } catch (e) {
      _errorController.add(Exception('Failed to stop VAD: $e'));
    }
  }

  /// Adjust the sensitivity of the VAD detection
  void adjustSensitivity(double threshold) {
    // Threshold should be between 0 and 1
    // Lower values make the VAD more sensitive (detects more speech)
    if (threshold < 0 || threshold > 1) {
      throw ArgumentError('Threshold must be between 0 and 1');
    }

    // Start listening with updated parameters
    stopListening();
    _vadHandler.startListening(
      positiveSpeechThreshold: threshold,
      negativeSpeechThreshold: threshold - 0.15, // Adjust negative threshold accordingly
      minSpeechFrames: 5,
      redemptionFrames: 30,
    );
  }

  /// Clean up resources
  void dispose() {
    stopListening();

    _speechStartSubscription?.cancel();
    _speechEndSubscription?.cancel();
    _errorSubscription?.cancel();

    _speechStartController.close();
    _speechEndController.close();
    _errorController.close();
    _stateController.close();

    _vadHandler.dispose();
  }
}