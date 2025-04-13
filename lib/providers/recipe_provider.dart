import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
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
      // Fetch paginated meals data from Azure Functions
      final data = await _azureFunctionService.getPaginatedMeals();
      
      // Extract recipes and categories
      final recipes = (data['items'] as List).map((item) => 
        Recipe.fromJson(item as Map<String, dynamic>)).toList();
      
      final categories = ['All Recipes', ...data['categories'] as List<String>];
      
      state = AsyncValue.data({
        'recipes': recipes,
        'categories': categories,
        'continuationToken': data['continuationToken'],
      });
    } catch (e, st) {
      print('Error in loadInitialRecipes: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> changeCategory(String category) async {
    try {
      state = const AsyncValue.loading();
      // Fetch filtered meals by category
      final data = await _azureFunctionService.getPaginatedMeals(
        category: category == 'All Recipes' ? null : category
      );
      
      // Create new state with filtered recipes but keep categories
      state.whenData((currentData) {
        final recipes = (data['items'] as List).map((item) => 
          Recipe.fromJson(item as Map<String, dynamic>)).toList();
          
        state = AsyncValue.data({
          'recipes': recipes,
          'categories': currentData['categories'],
          'continuationToken': data['continuationToken'],
        });
      });
    } catch (e, st) {
      print('Error in changeCategory: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleFavorite(String recipeId) async {
    try {
      // Call API to toggle favorite status
      await _azureFunctionService.toggleFavorite(recipeId);
      
      // Update local state
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
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  Future<void> loadMoreRecipes() async {
    try {
      final currentState = state.valueOrNull;
      if (currentState == null) return;
      
      final continuationToken = currentState['continuationToken'];
      if (continuationToken == null) return; // No more recipes to load
      
      // Get current category
      String? category;
      state.whenData((data) {
        final recipes = data['recipes'] as List<Recipe>;
        if (recipes.isNotEmpty) {
          category = recipes.first.category;
        }
      });
      
      // Fetch next page
      final data = await _azureFunctionService.getPaginatedMeals(
        continuationToken: continuationToken,
        category: category == 'All Recipes' ? null : category
      );
      
      // Update state with new recipes
      state.whenData((currentData) {
        final currentRecipes = currentData['recipes'] as List<Recipe>;
        final newRecipes = (data['items'] as List).map((item) => 
          Recipe.fromJson(item as Map<String, dynamic>)).toList();
          
        state = AsyncValue.data({
          'recipes': [...currentRecipes, ...newRecipes],
          'categories': currentData['categories'],
          'continuationToken': data['continuationToken'],
        });
      });
    } catch (e) {
      print('Error loading more recipes: $e');
    }
  }

  bool get hasMore => 
    state.valueOrNull?['continuationToken'] != null;
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