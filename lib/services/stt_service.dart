import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service that handles speech-to-text conversion
class SttService {
  // Speech to text instance
  final SpeechToText _speechToText = SpeechToText();

  // State tracking
  bool _isInitialized = false;
  bool _isListening = false;

  // Add timeout tracking
  Timer? _listenTimeout;

  // Controllers for streams
  final _resultController = StreamController<SpeechRecognitionResult>.broadcast();
  final _errorController = StreamController<SpeechRecognitionError>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  // Expose streams
  Stream<SpeechRecognitionResult> get onResult => _resultController.stream;
  Stream<SpeechRecognitionError> get onError => _errorController.stream;
  Stream<String> get onStatus => _statusController.stream;

  // Status getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  /// Initialize the speech to text service
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('STT_DEBUG: Already initialized, skipping initialization');
      return true;
    }

    try {
      debugPrint('STT_DEBUG: Requesting microphone permission');
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        debugPrint('STT_DEBUG: Microphone permission denied: $status');
        return false;
      }
      debugPrint('STT_DEBUG: Microphone permission granted');

      // Log available speech recognition engines
      debugPrint('STT_DEBUG: Initializing speech recognition engine');
      
      // Initialize the speech to text engine with detailed logs
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          debugPrint('STT_DEBUG: Error from speech recognition: ${error.errorMsg} (${error.permanent})');
          _errorController.add(error);
        },
        onStatus: (status) {
          debugPrint('STT_DEBUG: Speech recognition status changed: $status');
          _statusController.add(status);
        },
        debugLogging: true,
      );

      if (_isInitialized) {
        debugPrint('STT_DEBUG: Speech recognition initialized successfully');
        
        // Check if device has speech recognition capability
        final hasSpeech = await _speechToText.hasSpeech;
        debugPrint('STT_DEBUG: Device has speech recognition capability: $hasSpeech');
        
        // Get available locales for debugging
        final locales = await _speechToText.locales();
        debugPrint('STT_DEBUG: Available locales: ${locales.map((l) => "${l.localeId} (${l.name})").join(", ")}');
      } else {
        debugPrint('STT_DEBUG: Failed to initialize speech recognition');
      }

      return _isInitialized;
    } catch (e) {
      debugPrint('STT_DEBUG: Exception during initialization: $e');
      return false;
    }
  }

  /// Get available locales for speech recognition
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      debugPrint('STT_DEBUG: Getting locales - initializing first');
      await initialize();
    }
    final locales = await _speechToText.locales();
    debugPrint('STT_DEBUG: Retrieved ${locales.length} locales');
    return locales;
  }

  /// Start listening for speech
  Future<bool> startListening({
    String? localeId,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
    bool onDevice = false,
    bool partialResults = true,
  }) async {
    if (!_isInitialized) {
      debugPrint('STT_DEBUG: Start listening - not initialized, initializing first');
      final initialized = await initialize();
      if (!initialized) {
        debugPrint('STT_DEBUG: Initialization failed, cannot start listening');
        return false;
      }
    }

    if (_isListening) {
      debugPrint('STT_DEBUG: Already listening, ignoring start request');
      return true;
    }

    // Cancel any existing timeout
    _listenTimeout?.cancel();

    try {
      debugPrint('STT_DEBUG: Starting to listen with params: localeId=$localeId, listenFor=${listenFor.inSeconds}s, pauseFor=${pauseFor.inSeconds}s, onDevice=$onDevice, partialResults=$partialResults');
      
      // Use the default locale if none provided
      final selectedLocale = localeId ?? '';
      
      _isListening = await _speechToText.listen(
        onResult: (result) {
          debugPrint('STT_DEBUG: Result received - words: "${result.recognizedWords}", final: ${result.finalResult}, confidence: ${result.confidence}');
          
          // Only process results that have actual content
          if (result.recognizedWords.isNotEmpty) {
            _resultController.add(result);
          } else {
            debugPrint('STT_DEBUG: Received empty result, ignoring');
          }
          
          // If we got a final result, ensure we stop listening after a timeout
          if (result.finalResult) {
            debugPrint('STT_DEBUG: Final result received, will stop listening soon');
            _setupAutoStop();
          }
        },
        localeId: selectedLocale,
        listenFor: listenFor,
        pauseFor: pauseFor,
        onDevice: onDevice,
        partialResults: partialResults,
        listenMode: ListenMode.confirmation, // This mode waits for a pause before returning final result
      );

      debugPrint('STT_DEBUG: Listen method returned: $_isListening');
      
      if (_isListening) {
        // Set up a timeout to stop listening if nothing happens
        _setupListenTimeout(listenFor);
      } else {
        debugPrint('STT_DEBUG: Listening failed to start');
      }
      
      return _isListening;
    } catch (e) {
      debugPrint('STT_DEBUG: Exception during startListening: $e');
      return false;
    }
  }

  /// Set up a timeout to stop listening after the specified duration
  void _setupListenTimeout(Duration duration) {
    _listenTimeout?.cancel();
    _listenTimeout = Timer(duration, () {
      debugPrint('STT_DEBUG: Listen timeout reached after ${duration.inSeconds}s, stopping');
      stopListening();
    });
  }

  /// Set up auto-stop for after receiving a final result
  void _setupAutoStop() {
    // Stop listening after a short delay to ensure any additional processing is complete
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isListening) {
        debugPrint('STT_DEBUG: Auto-stopping after final result');
        stopListening();
      }
    });
  }

  /// Stop listening for speech
  Future<void> stopListening() async {
    if (!_isListening) {
      debugPrint('STT_DEBUG: Not currently listening, ignoring stop request');
      return;
    }

    _listenTimeout?.cancel();
    _listenTimeout = null;

    debugPrint('STT_DEBUG: Stopping speech recognition...');
    try {
      await _speechToText.stop();
      _isListening = false;
      debugPrint('STT_DEBUG: Speech recognition stopped successfully');
    } catch (e) {
      debugPrint('STT_DEBUG: Exception during stopListening: $e');
      _isListening = false; // Force state update even if stop failed
    }
  }

  /// Cancel speech recognition
  Future<void> cancelListening() async {
    if (!_isListening) {
      debugPrint('STT_DEBUG: Not currently listening, ignoring cancel request');
      return;
    }

    _listenTimeout?.cancel();
    _listenTimeout = null;

    debugPrint('STT_DEBUG: Cancelling speech recognition...');
    try {
      await _speechToText.cancel();
      _isListening = false;
      debugPrint('STT_DEBUG: Speech recognition cancelled successfully');
    } catch (e) {
      debugPrint('STT_DEBUG: Exception during cancelListening: $e');
      _isListening = false; // Force state update even if cancel failed
    }
  }

  /// Get currently available speech recognition words
  List<String> getRecognizedWords() {
    final words = _speechToText.lastRecognizedWords;
    debugPrint('STT_DEBUG: Last recognized words: "$words"');
    return words.split(' ')..retainWhere((word) => word.isNotEmpty);
  }

  /// Check current status of speech recognition
  void logSpeechStatus() {
    final statusText = '''
STT_DEBUG: Speech status:
- Initialized: $_isInitialized
- Has speech: ${_speechToText.hasSpeech}
- Is listening: $_isListening
- System is listening: ${_speechToText.isListening}
- Available: ${_speechToText.isAvailable}
- Last words: "${_speechToText.lastRecognizedWords}"
''';
    debugPrint(statusText);
  }

  /// Clean up resources
  void dispose() {
    debugPrint('STT_DEBUG: Disposing STT service');
    _listenTimeout?.cancel();
    
    if (_isListening) {
      _speechToText.cancel();
    }

    _resultController.close();
    _errorController.close();
    _statusController.close();
  }
}