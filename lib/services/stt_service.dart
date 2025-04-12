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
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        debugPrint('Microphone permission denied');
        return false;
      }

      // Initialize the speech to text engine
      _isInitialized = await _speechToText.initialize(
        onError: (error) => _errorController.add(error),
        onStatus: (status) => _statusController.add(status),
      );

      return _isInitialized;
    } catch (e) {
      debugPrint('Failed to initialize speech to text: $e');
      return false;
    }
  }

  /// Get available locales for speech recognition
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) await initialize();
    return await _speechToText.locales();
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
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isListening) return true;

    try {
      _isListening = await _speechToText.listen(
        onResult: (result) {
          _resultController.add(result);
          debugPrint('STT result: ${result.recognizedWords}');
        },
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: pauseFor,
        onDevice: onDevice,
        partialResults: partialResults,
      );

      return _isListening;
    } catch (e) {
      debugPrint('Failed to start speech recognition: $e');
      return false;
    }
  }

  /// Stop listening for speech
  Future<void> stopListening() async {
    if (!_isListening) return;

    await _speechToText.stop();
    _isListening = false;
  }

  /// Cancel speech recognition
  Future<void> cancelListening() async {
    if (!_isListening) return;

    await _speechToText.cancel();
    _isListening = false;
  }

  /// Get currently available speech recognition words
  /// Useful for showing the user what commands are available
  List<String> getRecognizedWords() {
    return _speechToText.lastRecognizedWords.split(' ')
      ..retainWhere((word) => word.isNotEmpty);
  }

  /// Clean up resources
  void dispose() {
    if (_isListening) {
      _speechToText.cancel();
    }

    _resultController.close();
    _errorController.close();
    _statusController.close();
  }
}