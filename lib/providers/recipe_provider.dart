import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';

// Sample data for initial state
final sampleRecipes = [
  Recipe(
    id: 'sample-recipe-1',
    title: 'Delicious Pasta Primavera',
    description: 'A light and fresh pasta dish packed with seasonal vegetables.',
    ingredients: [
      '8 oz pasta',
      '2 tablespoons olive oil',
      '1 zucchini, sliced',
      '1 yellow squash, sliced',
      '1 red bell pepper, chopped',
      '1 cup cherry tomatoes, halved',
      '3 cloves garlic, minced',
      '1/4 cup grated Parmesan cheese',
      'Fresh basil for garnish',
      'Salt and pepper to taste'
    ],
    instructions: [
      'Bring a large pot of salted water to a boil. Cook pasta according to package directions until al dente.',
      'While pasta is cooking, heat olive oil in a large skillet over medium-high heat.',
      'Add zucchini, squash, and bell pepper. Sauté for 3-4 minutes until vegetables begin to soften.',
      'Add cherry tomatoes and garlic. Cook for another 2 minutes.',
      'Drain pasta and add it to the skillet with vegetables. Toss to combine.',
      'Remove from heat and stir in Parmesan cheese. Season with salt and pepper.',
      'Garnish with fresh basil before serving.'
    ],
    aiTips: 'For a creamier texture, try adding a splash of heavy cream at the end. You can also substitute the vegetables with any seasonal ones you have on hand.',
  ),
];

// State notifier to manage the recipes
class RecipeNotifier extends StateNotifier<List<Recipe>> {
  RecipeNotifier() : super(sampleRecipes);

  void addRecipe(Recipe recipe) {
    state = [...state, recipe];
  }

  Recipe? getRecipeById(String id) {
    try {
      return state.firstWhere((recipe) => recipe.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Recipe> searchRecipes(String query) {
    final lowercaseQuery = query.toLowerCase();
    return state.where((recipe) {
      return recipe.title.toLowerCase().contains(lowercaseQuery) ||
          recipe.ingredients.any((ingredient) => 
              ingredient.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }
}

// Recipe providers
final recipeProvider = StateNotifierProvider<RecipeNotifier, List<Recipe>>((ref) {
  return RecipeNotifier();
});

// Single recipe provider
final recipeDetailProvider = Provider.family<Recipe?, String>((ref, id) {
  final recipeNotifier = ref.watch(recipeProvider.notifier);
  return recipeNotifier.getRecipeById(id);
});

// Search results provider
final searchResultsProvider = Provider.family<List<Recipe>, String>((ref, query) {
  if (query.isEmpty) return [];
  
  final recipeNotifier = ref.watch(recipeProvider.notifier);
  return recipeNotifier.searchRecipes(query);
});