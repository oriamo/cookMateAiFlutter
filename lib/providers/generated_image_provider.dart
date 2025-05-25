import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gemini_image_service.dart';
import '../services/cooking_session_service.dart';

/// State for generated cooking images
class GeneratedImageState {
  final Uint8List? imageData;
  final bool isLoading;
  final String? error;
  final String? lastInstruction;

  const GeneratedImageState({
    this.imageData,
    this.isLoading = false,
    this.error,
    this.lastInstruction,
  });

  GeneratedImageState copyWith({
    Uint8List? imageData,
    bool? isLoading,
    String? error,
    String? lastInstruction,
  }) {
    return GeneratedImageState(
      imageData: imageData ?? this.imageData,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      lastInstruction: lastInstruction ?? this.lastInstruction,
    );
  }
}

/// Provider for managing generated cooking images
class GeneratedImageNotifier extends StateNotifier<GeneratedImageState> {
  GeneratedImageNotifier() : super(const GeneratedImageState());

  /// Generate image for a cooking instruction
  Future<void> generateImageForInstruction({
    required String instruction,
    required String recipeContext,
  }) async {
    // Don't regenerate if it's the same instruction
    if (state.lastInstruction == instruction && state.imageData != null) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      lastInstruction: instruction,
    );

    try {
      final imageData = await GeminiImageService.generateCookingImage(
        instruction: instruction,
        recipeContext: recipeContext,
      );

      if (imageData != null) {
        state = state.copyWith(
          imageData: imageData,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to generate image',
        );
      }
    } catch (e) {
      debugPrint('GeneratedImageProvider: Error generating image: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Error generating image: $e',
      );
    }
  }

  /// Clear the current image
  void clearImage() {
    state = const GeneratedImageState();
  }
}

/// Provider instance
final generatedImageProvider = StateNotifierProvider<GeneratedImageNotifier, GeneratedImageState>(
  (ref) => GeneratedImageNotifier(),
);

/// Helper provider to get recipe context
final recipeContextProvider = Provider<String>((ref) {
  final cookingSession = ref.watch(cookingSessionProvider);
  if (cookingSession == null) {
    return 'General cooking instruction';
  }
  
  return '${cookingSession.recipe.title} - ${cookingSession.recipe.description}';
});