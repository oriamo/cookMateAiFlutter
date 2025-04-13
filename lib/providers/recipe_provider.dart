import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../dummy_data/dummy_recipes.dart';

class RecipeNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  RecipeNotifier() : super(const AsyncValue.loading()) {
    loadInitialRecipes();
  }

  Future<void> loadInitialRecipes() async {
    try {
      // Load our dummy recipes
      final recipes = List<Recipe>.from(dummyRecipes);
      
      // Extract categories from recipes
      final categories = <String>{};
      for (final recipe in recipes) {
        categories.add(recipe.category);
      }
      
      // Set the state with our dummy data
      state = AsyncValue.data({
        'recipes': recipes,
        'categories': ['All Recipes', ...categories.toList()],
      });
    } catch (e, st) {
      print('Error in loadInitialRecipes: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> changeCategory(String category) async {
    try {
      state.whenData((currentData) {
        final allRecipes = List<Recipe>.from(dummyRecipes);
        final recipes = category == 'All Recipes'
            ? allRecipes
            : allRecipes.where((recipe) => recipe.category == category).toList();
            
        state = AsyncValue.data({
          'recipes': recipes,
          'categories': currentData['categories'],
        });
      });
    } catch (e, st) {
      print('Error in changeCategory: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleFavorite(String recipeId) async {
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
        });
      }
    });
  }

  Future<void> loadMoreRecipes() async {
    // In demo mode, this is a no-op since we already loaded all recipes
    return;
  }

  bool get hasMore => false;
}

final recipeProvider =
    StateNotifierProvider<RecipeNotifier, AsyncValue<Map<String, dynamic>>>(
        (ref) {
  return RecipeNotifier();
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