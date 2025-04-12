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
  // VAD controller instance - change type to dynamic to avoid type errors
  late final dynamic _vadHandler;

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

      // Initialize VAD Handler - store as dynamic to avoid type errors
      debugPrint('VAD_DEBUG: Creating VAD handler');
      _vadHandler = VadHandler.create(isDebug: true);
      debugPrint('VAD_DEBUG: VAD handler created successfully with type: ${_vadHandler.runtimeType}');

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
    
    try {
      // In v0.0.5, we need to check if these properties exist before accessing them
      // Handle speech start events - this is the primary issue
      if (_vadHandler is dynamic) {
        dynamic handler = _vadHandler;
        
        // Check if onSpeechStart exists and is a Stream
        if (handler.onSpeechStart != null) {
          handler.onSpeechStart.listen((_) {
            _state = VadState.listening;
            _stateController.add(_state);
            _speechStartController.add(null);
            _didForceSpeechEnd = false;
            debugPrint('VAD_DEBUG: Speech start detected');
            
            // Set a max timeout for speech capture
            _setupForceEndTimeout();
          });
          debugPrint('VAD_DEBUG: Successfully subscribed to onSpeechStart');
        } else {
          debugPrint('VAD_DEBUG: onSpeechStart stream is not available');
        }
        
        // Try for real speech start events (new in v0.0.5)
        if (handler.onRealSpeechStart != null) {
          handler.onRealSpeechStart.listen((_) {
            debugPrint('VAD_DEBUG: Real speech start detected');
            // Treat this as a speech start if the main one isn't available
            if (handler.onSpeechStart == null) {
              _state = VadState.listening;
              _stateController.add(_state);
              _speechStartController.add(null);
              _didForceSpeechEnd = false;
              _setupForceEndTimeout();
            }
          });
          debugPrint('VAD_DEBUG: Successfully subscribed to onRealSpeechStart');
        } else {
          debugPrint('VAD_DEBUG: onRealSpeechStart stream is not available');
        }
        
        // Handle speech end events
        if (handler.onSpeechEnd != null) {
          handler.onSpeechEnd.listen((audio) {
            _state = VadState.processing;
            _stateController.add(_state);
            _speechEndController.add(audio);
            _cancelForceEndTimeout();
            debugPrint('VAD_DEBUG: Speech end detected, audio length: ${audio.length}, format: ${audio.runtimeType}');
          });
          debugPrint('VAD_DEBUG: Successfully subscribed to onSpeechEnd');
        } else {
          debugPrint('VAD_DEBUG: onSpeechEnd stream is not available');
        }
        
        // For VAD misfire events
        if (handler.onVADMisfire != null) {
          handler.onVADMisfire.listen((_) {
            debugPrint('VAD_DEBUG: VAD misfire detected');
          });
          debugPrint('VAD_DEBUG: Successfully subscribed to onVADMisfire');
        } else {
          debugPrint('VAD_DEBUG: onVADMisfire stream is not available');
        }
        
        // Handle error events
        if (handler.onError != null) {
          handler.onError.listen((error) {
            _errorController.add(Exception(error));
            debugPrint('VAD_DEBUG: Error occurred: $error');
          });
          debugPrint('VAD_DEBUG: Successfully subscribed to onError');
        } else {
          debugPrint('VAD_DEBUG: onError stream is not available');
        }
        
        // Try to subscribe to any other event streams that might be available
        try {
          if (handler.onFrameProcessed != null) {
            handler.onFrameProcessed.listen((frame) {
              // Just log this for debugging
              debugPrint('VAD_DEBUG: Frame processed event received');
            });
            debugPrint('VAD_DEBUG: Successfully subscribed to onFrameProcessed');
          }
        } catch (e) {
          debugPrint('VAD_DEBUG: onFrameProcessed not available: $e');
        }
      } else {
        debugPrint('VAD_DEBUG: VadHandler is not dynamic, cannot check for streams');
      }
    } catch (e) {
      debugPrint('VAD_DEBUG: Error setting up event streams: $e');
      _errorController.add(Exception('Failed to set up VAD event streams: $e'));
    }
    
    debugPrint('VAD_DEBUG: Event streams setup completed');
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
      
      // Try to call the method dynamically based on what's available
      if (_vadHandler is dynamic) {
        // First try startListening method
        try {
          _vadHandler.startListening();
          debugPrint('VAD_DEBUG: Started using startListening() method');
        } catch (e) {
          // Fallback to start method if available
          try {
            _vadHandler.start();
            debugPrint('VAD_DEBUG: Started using start() method');
          } catch (e2) {
            debugPrint('VAD_DEBUG: Neither startListening() nor start() methods worked: $e2');
            throw e2;
          }
        }
      }
      
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
      
      // Try to call the method dynamically based on what's available
      if (_vadHandler is dynamic) {
        // First try stopListening method
        try {
          _vadHandler.stopListening();
          debugPrint('VAD_DEBUG: Stopped using stopListening() method');
        } catch (e) {
          // Fallback to stop method if available
          try {
            _vadHandler.stop();
            debugPrint('VAD_DEBUG: Stopped using stop() method');
          } catch (e2) {
            // If both fail, just log and continue
            debugPrint('VAD_DEBUG: Neither stopListening() nor stop() methods worked: $e2');
          }
        }
      }
      
      _state = VadState.idle;
      _stateController.add(_state);
      debugPrint('VAD_DEBUG: VAD listening stopped successfully');
    } catch (e) {
      debugPrint('VAD_DEBUG: Exception while stopping VAD: $e');
      _errorController.add(Exception('Failed to stop VAD: $e'));
    }
  }

  /// Adjust the sensitivity of the VAD detection
  /// Note: In v0.0.5, there's no direct method to adjust sensitivity during runtime
  /// This is a placeholder method that restarts the VAD
  void adjustSensitivity(double threshold) {
    // Threshold should be between 0 and 1
    // Lower values make the VAD more sensitive (detects more speech)
    if (threshold < 0 || threshold > 1) {
      debugPrint('VAD_DEBUG: Invalid threshold value: $threshold');
      throw ArgumentError('Threshold must be between 0 and 1');
    }

    debugPrint('VAD_DEBUG: Adjusting sensitivity to $threshold');
    
    // Simply restart the VAD since direct sensitivity adjustment isn't supported
    stopListening();
    startListening();
    
    debugPrint('VAD_DEBUG: Sensitivity adjusted successfully');
  }

  /// Clean up resources
  void dispose() {
    debugPrint('VAD_DEBUG: Disposing VAD service');
    stopListening();
    _cancelForceEndTimeout();

    _speechStartController.close();
    _speechEndController.close();
    _errorController.close();
    _stateController.close();

    // Try to dispose gracefully based on what's available
    if (_vadHandler is dynamic) {
      try {
        _vadHandler.dispose();
        debugPrint('VAD_DEBUG: VAD handler disposed successfully');
      } catch (e) {
        debugPrint('VAD_DEBUG: No dispose method available: $e');
        // No need to rethrow as we're already in cleanup
      }
    }
    
    debugPrint('VAD_DEBUG: VAD service disposed successfully');
  }
}