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
    String? fallbackImageUrl, // Recipe step image URL as fallback
  }) async {
    debugPrint('GeneratedImageProvider: Generating image for instruction: "$instruction"');
    debugPrint('GeneratedImageProvider: Recipe context: "$recipeContext"');
    
    // Don't regenerate if it's the same instruction
    if (state.lastInstruction == instruction && state.imageData != null) {
      debugPrint('GeneratedImageProvider: Skipping generation - same instruction already generated');
      return;
    }

    debugPrint('GeneratedImageProvider: Starting image generation...');
    state = state.copyWith(
      isLoading: true,
      error: null,
      lastInstruction: instruction,
    );

    try {
      final imageData = await GeminiImageService.generateCookingImage(
        instruction: instruction,
        recipeContext: recipeContext,
        fallbackImageUrl: fallbackImageUrl,
      );

      if (imageData != null) {
        debugPrint('GeneratedImageProvider: Image generated successfully! Size: ${imageData.length} bytes');
        state = state.copyWith(
          imageData: imageData,
          isLoading: false,
          error: null,
        );
      } else {
        debugPrint('GeneratedImageProvider: Image generation returned null');
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to generate image - API returned no data',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('GeneratedImageProvider: Error generating image: $e');
      debugPrint('GeneratedImageProvider: Stack trace: $stackTrace');
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

/// Helper provider to get current step image URL
final currentStepImageUrlProvider = Provider<String?>((ref) {
  final cookingSession = ref.watch(cookingSessionProvider);
  if (cookingSession == null) {
    return null;
  }
  
  final currentStep = cookingSession.currentStep;
  if (currentStep == null || currentStep.imageUrl.isEmpty) {
    return null;
  }
  
  return currentStep.imageUrl;
});