import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../services/tts_service.dart';

/// TTS State for the provider
class TtsProviderState {
  final TtsState state;
  final bool isInitialized;
  final String? error;
  final String? currentSpeakingText;

  const TtsProviderState({
    this.state = TtsState.stopped,
    this.isInitialized = false,
    this.error,
    this.currentSpeakingText,
  });

  TtsProviderState copyWith({
    TtsState? state,
    bool? isInitialized,
    String? error,
    String? currentSpeakingText,
  }) {
    return TtsProviderState(
      state: state ?? this.state,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error ?? this.error,
      currentSpeakingText: currentSpeakingText ?? this.currentSpeakingText,
    );
  }
}

/// TTS Provider Notifier
class TtsNotifier extends StateNotifier<TtsProviderState> {
  final TtsService _ttsService;

  TtsNotifier(this._ttsService) : super(const TtsProviderState()) {
    _initialize();
  }

  /// Initialize TTS service
  Future<void> _initialize() async {
    try {
      final initialized = await _ttsService.initialize();
      
      if (initialized) {
        // Set up listeners
        _ttsService.onStateChange.listen((ttsState) {
          state = state.copyWith(
            state: ttsState,
            currentSpeakingText: ttsState == TtsState.stopped ? null : state.currentSpeakingText,
          );
        });

        _ttsService.onError.listen((error) {
          debugPrint('TTS Error: $error');
          state = state.copyWith(error: error);
        });

        _ttsService.onCompletion.listen((_) {
          state = state.copyWith(
            state: TtsState.stopped,
            currentSpeakingText: null,
          );
        });

        // Try to use Alloy-like voice
        await _ttsService.useAlloyLikeVoice();
        
        state = state.copyWith(isInitialized: true);
      } else {
        state = state.copyWith(error: 'Failed to initialize TTS');
      }
    } catch (e) {
      debugPrint('TTS initialization error: $e');
      state = state.copyWith(error: 'TTS initialization error: $e');
    }
  }

  /// Speak the given text
  Future<void> speak(String text) async {
    if (!state.isInitialized) {
      debugPrint('TTS not initialized, cannot speak');
      return;
    }

    try {
      state = state.copyWith(currentSpeakingText: text);
      await _ttsService.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
      state = state.copyWith(error: 'Failed to speak: $e');
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    if (!state.isInitialized) return;

    try {
      await _ttsService.stop();
      state = state.copyWith(
        state: TtsState.stopped,
        currentSpeakingText: null,
      );
    } catch (e) {
      debugPrint('TTS stop error: $e');
      state = state.copyWith(error: 'Failed to stop TTS: $e');
    }
  }

  /// Pause speaking
  Future<void> pause() async {
    if (!state.isInitialized) return;

    try {
      await _ttsService.pause();
    } catch (e) {
      debugPrint('TTS pause error: $e');
      state = state.copyWith(error: 'Failed to pause TTS: $e');
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    if (!state.isInitialized) return;

    try {
      await _ttsService.setVolume(volume);
    } catch (e) {
      debugPrint('TTS volume error: $e');
      state = state.copyWith(error: 'Failed to set volume: $e');
    }
  }

  /// Set speech rate (0.0 to 1.0)
  Future<void> setRate(double rate) async {
    if (!state.isInitialized) return;

    try {
      await _ttsService.setRate(rate);
    } catch (e) {
      debugPrint('TTS rate error: $e');
      state = state.copyWith(error: 'Failed to set rate: $e');
    }
  }

  /// Set pitch (0.5 to 2.0)
  Future<void> setPitch(double pitch) async {
    if (!state.isInitialized) return;

    try {
      await _ttsService.setPitch(pitch);
    } catch (e) {
      debugPrint('TTS pitch error: $e');
      state = state.copyWith(error: 'Failed to set pitch: $e');
    }
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }
}

/// TTS Service Provider
final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

/// TTS Provider
final ttsProvider = StateNotifierProvider<TtsNotifier, TtsProviderState>((ref) {
  final ttsService = ref.watch(ttsServiceProvider);
  return TtsNotifier(ttsService);
});

/// Helper provider to check if TTS is currently speaking
final isSpeakingProvider = Provider<bool>((ref) {
  final ttsState = ref.watch(ttsProvider);
  return ttsState.state == TtsState.playing;
});