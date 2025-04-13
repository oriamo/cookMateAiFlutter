// lib/services/tts_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused, continued }

/// Service that handles text-to-speech conversion
class TtsService {
  // Text to speech instance
  final FlutterTts _flutterTts = FlutterTts();

  // TTS state
  TtsState _ttsState = TtsState.stopped;

  // Controllers for streams
  final _stateController = StreamController<TtsState>.broadcast();
  final _progressController = StreamController<ProgressEvent>.broadcast();
  final _completionController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Expose streams
  Stream<TtsState> get onStateChange => _stateController.stream;
  Stream<ProgressEvent> get onProgress => _progressController.stream;
  Stream<String> get onCompletion => _completionController.stream;
  Stream<String> get onError => _errorController.stream;

  // Status getter
  TtsState get state => _ttsState;

  // Voice settings
  String _currentVoice = '';
  final Map<String, double> _settings = {
    'volume': 1.0,
    'pitch': 1.0,
    'rate': 0.5,
  };

  /// Initialize the TTS service
  Future<bool> initialize() async {
    try {
      // Set up event handlers
      _flutterTts.setStartHandler(() {
        _ttsState = TtsState.playing;
        _stateController.add(_ttsState);
        debugPrint('TTS: Started speaking');
      });

      _flutterTts.setCompletionHandler(() {
        _ttsState = TtsState.stopped;
        _stateController.add(_ttsState);
        _completionController.add('Completed');
        debugPrint('TTS: Completed speaking');
      });

      _flutterTts.setCancelHandler(() {
        _ttsState = TtsState.stopped;
        _stateController.add(_ttsState);
        debugPrint('TTS: Cancelled');
      });

      _flutterTts.setPauseHandler(() {
        _ttsState = TtsState.paused;
        _stateController.add(_ttsState);
        debugPrint('TTS: Paused');
      });

      _flutterTts.setContinueHandler(() {
        _ttsState = TtsState.continued;
        _stateController.add(_ttsState);
        debugPrint('TTS: Continued');
      });

      _flutterTts.setErrorHandler((msg) {
        _errorController.add(msg);
        debugPrint('TTS Error: $msg');
      });

      _flutterTts.setProgressHandler((text, start, end, word) {
        _progressController.add(ProgressEvent(text, start, end, word));
      });

      // Set initial settings
      await _applySettings();

      // Set language
      await _flutterTts.setLanguage('en-US');

      return true;
    } catch (e) {
      debugPrint('Failed to initialize TTS: $e');
      return false;
    }
  }

  /// Get available TTS voices
  Future<List<Map<String, String>>> getAvailableVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      return List<Map<String, String>>.from(voices);
    } catch (e) {
      debugPrint('Failed to get voices: $e');
      return [];
    }
  }

  /// Set the TTS voice
  Future<bool> setVoice(String voiceName, {String? identifier}) async {
    try {
      // On iOS and macOS, we can use the voice identifier
      if (identifier != null) {
        await _flutterTts.setVoice({"name": voiceName, "locale": "en-US", "identifier": identifier});
      } else {
        await _flutterTts.setVoice({"name": voiceName, "locale": "en-US"});
      }

      _currentVoice = voiceName;
      return true;
    } catch (e) {
      debugPrint('Failed to set voice: $e');
      return false;
    }
  }

  /// Speak the given text
  Future<bool> speak(String text) async {
    if (text.isEmpty) return false;

    try {
      // Stop any ongoing speech
      if (_ttsState != TtsState.stopped) {
        await stop();
      }

      // Apply current settings
      await _applySettings();

      // Speak the text
      await _flutterTts.speak(text);
      return true;
    } catch (e) {
      debugPrint('Failed to speak: $e');
      return false;
    }
  }

  /// Find a voice similar to "alloy" (used in OpenAI's TTS)
  Future<bool> useAlloyLikeVoice() async {
    try {
      final voices = await getAvailableVoices();

      // Priority list of voice names that might sound similar to "alloy"
      // These are common voices that have a neutral, clear sound
      final priorityVoices = [
        'Karen', 'Samantha', 'Daniel', 'Alex', 'Moira',  // English voices on iOS
        'en-us-x-tpd-network', 'en-us-x-tpf-local',      // Android voices
      ];

      // Try to find a voice from our priority list
      for (final voiceName in priorityVoices) {
        final voice = voices.firstWhere(
              (v) => v['name']?.toLowerCase().contains(voiceName.toLowerCase()) ?? false,
          orElse: () => {},
        );

        if (voice.isNotEmpty) {
          return await setVoice(
            voice['name'] ?? '',
            identifier: voice['identifier'],
          );
        }
      }

      // If we can't find a specific voice, use the first available one
      if (voices.isNotEmpty) {
        return await setVoice(
          voices.first['name'] ?? '',
          identifier: voices.first['identifier'],
        );
      }

      return false;
    } catch (e) {
      debugPrint('Failed to set Alloy-like voice: $e');
      return false;
    }
  }

  /// Stop speaking
  Future<bool> stop() async {
    try {
      await _flutterTts.stop();
      return true;
    } catch (e) {
      debugPrint('Failed to stop TTS: $e');
      return false;
    }
  }

  /// Pause speaking
  Future<bool> pause() async {
    try {
      final result = await _flutterTts.pause();
      return result == 1;
    } catch (e) {
      debugPrint('Failed to pause TTS: $e');
      return false;
    }
  }

  /// Set the volume (0.0 to 1.0)
  Future<bool> setVolume(double volume) async {
    if (volume < 0.0 || volume > 1.0) {
      throw ArgumentError('Volume must be between 0.0 and 1.0');
    }

    _settings['volume'] = volume;
    return true;
  }

  /// Set the pitch (0.5 to 2.0)
  Future<bool> setPitch(double pitch) async {
    if (pitch < 0.5 || pitch > 2.0) {
      throw ArgumentError('Pitch must be between 0.5 and 2.0');
    }

    _settings['pitch'] = pitch;
    return true;
  }

  /// Set the speech rate (0.0 to 1.0)
  Future<bool> setRate(double rate) async {
    if (rate < 0.0 || rate > 1.0) {
      throw ArgumentError('Rate must be between 0.0 and 1.0');
    }

    _settings['rate'] = rate;
    return true;
  }

  /// Apply all current settings to the TTS engine
  Future<void> _applySettings() async {
    await _flutterTts.setVolume(_settings['volume']!);
    await _flutterTts.setPitch(_settings['pitch']!);
    await _flutterTts.setSpeechRate(_settings['rate']!);
  }

  /// Clean up resources
  void dispose() {
    stop();

    _stateController.close();
    _progressController.close();
    _completionController.close();
    _errorController.close();
  }
}

/// Event for tracking TTS progress
class ProgressEvent {
  final String text;
  final int start;
  final int end;
  final String word;

  ProgressEvent(this.text, this.start, this.end, this.word);
}