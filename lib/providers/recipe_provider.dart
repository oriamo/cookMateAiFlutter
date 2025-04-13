import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../dummy_data/dummy_recipes.dart';
import '../dummy_data/dummy_categories.dart';
import '../services/azure_function_service.dart';
import '../services/azure_function_service_provider.dart';

class RecipeNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final AzureFunctionService _azureFunctionService;

  RecipeNotifier(this._azureFunctionService) : super(const AsyncValue.loading()) {
    loadInitialRecipes();
  }

  Future<void> loadInitialRecipes() async {
    try {
      state = const AsyncValue.loading();
      
      // Use dummy data for demonstration
      final recipes = List<Recipe>.from(dummyRecipes);
      
      // Extract categories from dummy categories
      final categoryNames = dummyCategories.map((cat) => cat.name).toList();
      final categories = ['All Recipes', ...categoryNames];
      
      state = AsyncValue.data({
        'recipes': recipes,
        'categories': categories,
        'continuationToken': null, // No pagination in demo mode
      });
      
      // Also try the real API in the background
      try {
        final data = await _azureFunctionService.getPaginatedMeals();
        // If we get data back, we would update here but for demo we'll ignore
      } catch (apiError) {
        // Silently fail - we already have dummy data
        print('API error (expected in demo mode): $apiError');
      }
    } catch (e, st) {
      print('Error in loadInitialRecipes: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> changeCategory(String category) async {
    try {
      state = const AsyncValue.loading();
      
      // Use dummy data filtered by category
      final allRecipes = List<Recipe>.from(dummyRecipes);
      final filteredRecipes = category == 'All Recipes' 
          ? allRecipes 
          : allRecipes.where((recipe) => 
              recipe.category.toLowerCase() == category.toLowerCase()).toList();
      
      // Create new state with filtered recipes but keep categories
      state.whenData((currentData) {
        state = AsyncValue.data({
          'recipes': filteredRecipes,
          'categories': currentData['categories'],
          'continuationToken': null, // No pagination in demo mode
        });
      });
    } catch (e, st) {
      print('Error in changeCategory: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleFavorite(String recipeId) async {
    try {
      // In demo mode, we just update local state
      state.whenData((currentData) {
        final recipes = List<Recipe>.from(currentData['recipes'] as List<Recipe>);
        final index = recipes.indexWhere((recipe) => recipe.id == recipeId);
        if (index != -1) {
          recipes[index] = recipes[index].copyWith(
            isFavorite: !recipes[index].isFavorite,
          );
          state = AsyncValue.data({
            'recipes': recipes,
            'categories': currentData['categories'],
            'continuationToken': currentData['continuationToken'],
          });
        }
      });
      
      // Try API call in background (will be mocked in demo mode)
      try {
        await _azureFunctionService.toggleFavorite(recipeId);
      } catch (e) {
        // Silently ignore API errors in demo mode
      }
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  Future<void> loadMoreRecipes() async {
    // In demo mode, we don't have pagination - all recipes are already loaded
    // This is a no-op function for demo mode
    return;
  }

  // In demo mode, we always have all recipes loaded
  bool get hasMore => false;
}

final recipeProvider =
    StateNotifierProvider<RecipeNotifier, AsyncValue<Map<String, dynamic>>>((ref) {
  final azureFunctionService = ref.watch(azureFunctionServiceProvider);
  return RecipeNotifier(azureFunctionService);
});

// Provider for favorite recipes
final favoriteRecipesProvider = Provider<List<Recipe>>((ref) {
  return ref.watch(recipeProvider).whenData((data) {
        if (data['recipes'] is List<Recipe>) {
          final recipes = data['recipes'] as List<Recipe>;
          return recipes.where((recipe) => recipe.isFavorite).toList();
        } else if (data['recipes'] is List) {
          final recipes = (data['recipes'] as List).map((item) {
            if (item is Recipe) return item;
            return Recipe.fromJson(item as Map<String, dynamic>);
          }).toList();
          return recipes.where((recipe) => recipe.isFavorite).toList();
        }
        return <Recipe>[];
      }).valueOrNull ??
      [];
});

// Provider for getting recipe details by ID
final recipeDetailProvider = Provider.family<Recipe?, String>((ref, id) {
  return ref.watch(recipeProvider).whenData((data) {
    final recipes = data['recipes'] as List<Recipe>;
    try {
      return recipes.firstWhere((recipe) => recipe.id == id);
    } catch (e) {
      return null;
    }
  }).valueOrNull;
});