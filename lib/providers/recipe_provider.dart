import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../providers/user_provider.dart';

class RecipeNotifier extends StateNotifier<List<Recipe>> {
  final Ref _ref;

  RecipeNotifier(this._ref) : super([]) {
    _initializeRecipes();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      // Get user's favorite recipe IDs from userProfileProvider
      final userProfile = _ref.read(userProfileProvider);
      final favoriteIds = userProfile.favoriteRecipes;

      // Mark recipes as favorites based on user profile
      if (favoriteIds.isNotEmpty) {
        state = state.map((recipe) {
          if (favoriteIds.contains(recipe.id)) {
            return recipe.copyWith(isFavorite: true);
          }
          return recipe;
        }).toList();
      }
    } catch (e) {
      // Log error without using print in production
      // Consider using a proper logging package in a real app
      _logError('Error loading favorites', e);
    }
  }

  // A safer logging method that can be replaced with a proper logger
  void _logError(String message, Object error) {
    // In production, this would use a proper logging framework
    // like logger package instead of print
    assert(() {
      // This code only runs in debug mode
      // ignore: avoid_print
      print('$message: $error');
      return true;
    }());
  }

  void _initializeRecipes() {
    // Sample recipes data - in a real app, this would come from an API
    state = [
      Recipe(
        id: '1',
        title: 'Creamy Garlic Pasta',
        description:
            'A delicious creamy garlic pasta that\'s quick and easy to make. Perfect for weeknight dinners!',
        ingredients: [
          '250g pasta',
          '4 cloves garlic, minced',
          '2 tbsp butter',
          '1 cup heavy cream',
          '1/2 cup grated Parmesan cheese',
          'Salt and pepper to taste',
          'Fresh parsley for garnish'
        ],
        instructions: [
          'Cook pasta according to package instructions.',
          'In a large skillet, melt butter over medium heat.',
          'Add minced garlic and sauté until fragrant, about 1 minute.',
          'Pour in heavy cream and bring to a simmer.',
          'Add Parmesan cheese and stir until smooth.',
          'Season with salt and pepper.',
          'Drain pasta and add to the sauce, tossing to coat.',
          'Garnish with fresh parsley and serve.'
        ],
        prepTimeMinutes: 10,
        cookTimeMinutes: 15,
        totalTimeMinutes: 25,
        servings: 4,
        difficulty: 'Easy',
        cuisineType: 'Italian',
        calories: 450,
        rating: 4.7,
        reviewCount: 128,
        imageUrl:
            'https://images.unsplash.com/photo-1555072956-7758afb20e8f?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1287&q=80',
        tags: ['pasta', 'quick', 'dinner', 'vegetarian'],
        chefName: 'Jamie Oliver',
        isFavorite: false,
        categoryId: 'pasta',
        createdAt: DateTime.now(),
      ),
      Recipe(
        id: '2',
        title: 'Chicken Teriyaki Stir-Fry',
        description:
            'A flavorful chicken teriyaki stir-fry with colorful vegetables. Quick, healthy, and delicious!',
        ingredients: [
          '500g chicken breast, sliced',
          '1 bell pepper, sliced',
          '1 carrot, julienned',
          '1 cup broccoli florets',
          '1/4 cup teriyaki sauce',
          '2 tbsp vegetable oil',
          '2 cloves garlic, minced',
          '1 tbsp ginger, grated',
          'Sesame seeds for garnish',
          'Green onions, sliced, for garnish'
        ],
        instructions: [
          'Heat oil in a large wok or skillet over medium-high heat.',
          'Add chicken and cook until browned, about 5-6 minutes.',
          'Add garlic and ginger, sauté for 1 minute.',
          'Add vegetables and stir-fry for 3-4 minutes until crisp-tender.',
          'Pour in teriyaki sauce and stir to coat everything.',
          'Cook for another 2 minutes until sauce is thick and glossy.',
          'Garnish with sesame seeds and sliced green onions.',
          'Serve hot with rice or noodles.'
        ],
        prepTimeMinutes: 15,
        cookTimeMinutes: 15,
        totalTimeMinutes: 30,
        servings: 4,
        difficulty: 'Medium',
        cuisineType: 'Asian',
        calories: 380,
        rating: 4.5,
        reviewCount: 92,
        imageUrl:
            'https://images.unsplash.com/photo-1512058556646-c4da40fba323?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1172&q=80',
        tags: ['chicken', 'stir-fry', 'Asian', 'dinner'],
        chefName: 'Gordon Ramsay',
        isFavorite: false,
        categoryId: 'chicken',
        createdAt: DateTime.now(),
      ),
      // More sample recipes...
    ];
  }

  // Toggle favorite status for a recipe
  void toggleFavorite(String recipeId) {
    // Update recipe state
    state = state.map((recipe) {
      if (recipe.id == recipeId) {
        final newValue = !recipe.isFavorite;

        // Update user profile
        if (newValue) {
          _ref.read(userProfileProvider.notifier).addFavoriteRecipe(recipeId);
        } else {
          _ref
              .read(userProfileProvider.notifier)
              .removeFavoriteRecipe(recipeId);
        }

        return recipe.copyWith(isFavorite: newValue);
      }
      return recipe;
    }).toList();
  }

  // Get only favorite recipes
  List<Recipe> getFavorites() {
    return state.where((recipe) => recipe.isFavorite).toList();
  }

  // Search recipes
  List<Recipe> searchRecipes(String query) {
    if (query.isEmpty) return state;

    final normalizedQuery = query.toLowerCase();

    // Add to recent searches in user profile
    _ref.read(userProfileProvider.notifier).addRecentSearch(query);

    return state.where((recipe) {
      final inTitle = recipe.title.toLowerCase().contains(normalizedQuery);
      final inDescription =
          recipe.description.toLowerCase().contains(normalizedQuery);
      final inTags =
          recipe.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));
      final inIngredients = recipe.ingredients.any(
          (ingredient) => ingredient.toLowerCase().contains(normalizedQuery));

      return inTitle || inDescription || inTags || inIngredients;
    }).toList();
  }

  // Get recipe by ID
  Recipe? getRecipeById(String id) {
    try {
      return state.firstWhere((recipe) => recipe.id == id);
    } catch (e) {
      return null; // Return null if recipe not found
    }
  }

  // Filter recipes by category/tag
  List<Recipe> getRecipesByCategory(String category) {
    return state.where((recipe) {
      return recipe.tags.contains(category.toLowerCase()) ||
          recipe.cuisineType.toLowerCase() == category.toLowerCase();
    }).toList();
  }
}

final recipeProvider =
    StateNotifierProvider<RecipeNotifier, List<Recipe>>((ref) {
  return RecipeNotifier(ref);
});

// Provider for favorite recipes
final favoriteRecipesProvider = Provider<List<Recipe>>((ref) {
  final recipes = ref.watch(recipeProvider);
  return recipes.where((recipe) => recipe.isFavorite).toList();
});

// Provider for getting recipe details by ID
final recipeDetailProvider = Provider.family<Recipe?, String>((ref, id) {
  final recipes = ref.watch(recipeProvider);
  try {
    return recipes.firstWhere((recipe) => recipe.id == id);
  } catch (e) {
    return null;
  }
});
