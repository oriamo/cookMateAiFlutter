import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';

// Sample data for recipes
final List<Recipe> _sampleRecipes = [
  Recipe(
    id: '1',
    title: 'Classic Margherita Pizza',
    description: 'A traditional Italian pizza topped with tomato sauce, fresh mozzarella cheese, basil leaves, and a drizzle of olive oil.',
    imageUrl: 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
    totalTimeMinutes: 45,
    prepTimeMinutes: 15,
    cookTimeMinutes: 30,
    difficulty: 'Medium',
    servings: 4,
    calories: 285,
    chefName: 'Marco Rossi',
    rating: 4.8,
    ingredients: [
      '1 pizza dough (store-bought or homemade)',
      '1/4 cup tomato sauce',
      '200g fresh mozzarella cheese, sliced',
      'Fresh basil leaves',
      '2 tablespoons extra virgin olive oil',
      'Salt and pepper to taste',
      '1 clove garlic, minced (optional)'
    ],
    instructions: [
      'Preheat your oven to 475°F (245°C) and place a pizza stone or baking sheet in the oven to heat.',
      'On a floured surface, stretch or roll out the pizza dough to a 12-inch circle.',
      'Transfer the dough to a piece of parchment paper or a floured pizza peel.',
      'Spread the tomato sauce evenly over the dough, leaving a 1/2-inch border around the edge.',
      'Arrange the mozzarella slices evenly over the sauce.',
      'Slide the pizza onto the preheated stone or baking sheet and bake for 10-12 minutes, until the crust is golden and the cheese is bubbly.',
      'Remove from the oven and immediately garnish with fresh basil leaves.',
      'Drizzle with olive oil, and season with salt and pepper if desired.',
      'Slice and serve hot.'
    ],
    tags: ['Italian', 'Pizza', 'Vegetarian', 'Dinner'],
    aiTips: 'For the best texture, let your dough come to room temperature before stretching. If you want a crispier crust, try brushing the edge with olive oil before baking. Fresh mozzarella can release water during cooking - pat it dry with paper towels before adding to the pizza.',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
    categoryId: '1',
    isFavorite: true,
  ),
  Recipe(
    id: '2',
    title: 'Chicken Tikka Masala',
    description: 'A flavorful Indian curry dish with marinated chicken pieces in a creamy, spiced tomato sauce.',
    imageUrl: 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
    totalTimeMinutes: 60,
    prepTimeMinutes: 20,
    cookTimeMinutes: 40,
    difficulty: 'Medium',
    servings: 6,
    calories: 420,
    chefName: 'Priya Sharma',
    rating: 4.9,
    ingredients: [
      '800g boneless, skinless chicken thighs, cut into bite-sized pieces',
      '1 cup plain yogurt',
      '2 tablespoons lemon juice',
      '6 cloves garlic, minced',
      '2 tablespoons ginger, grated',
      '2 teaspoons cumin powder',
      '2 teaspoons garam masala',
      '2 teaspoons paprika',
      '1 large onion, finely chopped',
      '3 tablespoons vegetable oil',
      '2 cups tomato puree',
      '1 cup heavy cream',
      'Fresh cilantro for garnish',
      'Salt to taste'
    ],
    instructions: [
      'In a large bowl, combine yogurt, lemon juice, half the garlic, half the ginger, 1 tsp cumin, 1 tsp garam masala, 1 tsp paprika, and salt. Add chicken and toss to coat. Marinate for at least 1 hour, preferably overnight.',
      'Preheat oven to 425°F (220°C). Place marinated chicken on a baking sheet and bake for 15 minutes until slightly charred.',
      'Meanwhile, heat oil in a large pot over medium heat. Add onions and sauté until soft and translucent.',
      'Add remaining garlic and ginger, and cook for 1-2 minutes until fragrant.',
      'Add remaining spices and cook for another minute.',
      'Stir in tomato puree and bring to a simmer. Cook for 10-15 minutes until sauce thickens.',
      'Add heavy cream and simmer for 5 minutes.',
      'Add the baked chicken pieces and simmer for another 5-10 minutes.',
      'Garnish with fresh cilantro and serve with rice or naan bread.'
    ],
    tags: ['Indian', 'Curry', 'Chicken', 'Dinner', 'Spicy'],
    aiTips: 'For a deeper flavor, toast whole spices and grind them yourself instead of using pre-ground spices. If you find the sauce too acidic, add 1/2 teaspoon of sugar to balance it. For a lighter version, you can substitute coconut milk for the heavy cream.',
    createdAt: DateTime.now().subtract(const Duration(days: 7)),
    categoryId: '2',
    isFavorite: false,
  ),
  Recipe(
    id: '3',
    title: 'Fresh Summer Pasta Salad',
    description: 'A refreshing pasta salad with seasonal vegetables, herbs, and a light lemon dressing. Perfect for picnics and summer gatherings.',
    imageUrl: 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
    totalTimeMinutes: 30,
    prepTimeMinutes: 15,
    cookTimeMinutes: 15,
    difficulty: 'Easy',
    servings: 8,
    calories: 320,
    chefName: 'Emma Wilson',
    rating: 4.5,
    ingredients: [
      '500g short pasta (like rotini or penne)',
      '1 cup cherry tomatoes, halved',
      '1 cucumber, diced',
      '1 bell pepper, diced',
      '1/2 red onion, finely sliced',
      '100g feta cheese, crumbled',
      '1/4 cup pitted black olives, halved',
      '1/4 cup fresh basil leaves, torn',
      '3 tablespoons extra virgin olive oil',
      '2 tablespoons lemon juice',
      '1 teaspoon lemon zest',
      '2 cloves garlic, minced',
      '1 teaspoon dried oregano',
      'Salt and pepper to taste'
    ],
    instructions: [
      'Cook pasta according to package instructions until al dente. Drain and rinse with cold water to stop the cooking process.',
      'While pasta is cooking, prepare the dressing by whisking together olive oil, lemon juice, lemon zest, garlic, oregano, salt, and pepper in a small bowl.',
      'In a large bowl, combine the cooled pasta, tomatoes, cucumber, bell pepper, red onion, olives, and half of the feta cheese.',
      'Pour the dressing over the pasta mixture and toss to coat evenly.',
      'Refrigerate for at least 30 minutes to allow flavors to blend.',
      'Before serving, add the torn basil leaves and remaining feta cheese. Toss gently.',
      'Taste and adjust seasoning if necessary. Serve chilled.'
    ],
    tags: ['Pasta', 'Salad', 'Vegetarian', 'Summer', 'Quick'],
    aiTips: 'Cook the pasta slightly less than al dente since it will continue to absorb the dressing as it sits. For the best flavor, bring the salad to room temperature about 15 minutes before serving. Add a can of drained tuna or grilled chicken for a protein boost.',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    categoryId: '3',
    isFavorite: true,
  ),
];

class RecipeNotifier extends StateNotifier<List<Recipe>> {
  RecipeNotifier() : super(_sampleRecipes);

  Recipe? getRecipeById(String id) {
    try {
      return state.firstWhere((recipe) => recipe.id == id);
    } catch (e) {
      return null;
    }
  }

  void toggleFavorite(String id) {
    state = state.map((recipe) {
      if (recipe.id == id) {
        return recipe.copyWith(isFavorite: !recipe.isFavorite);
      }
      return recipe;
    }).toList();
  }

  List<Recipe> getRecipesByCategory(String categoryId) {
    return state.where((recipe) => recipe.categoryId == categoryId).toList();
  }

  List<Recipe> getFavoriteRecipes() {
    return state.where((recipe) => recipe.isFavorite).toList();
  }

  List<Recipe> searchRecipes(String query) {
    if (query.isEmpty) return state;
    
    final normalizedQuery = query.toLowerCase();
    return state.where((recipe) {
      return recipe.title.toLowerCase().contains(normalizedQuery) ||
          recipe.description.toLowerCase().contains(normalizedQuery) ||
          recipe.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));
    }).toList();
  }
}

// Main recipes provider
final recipeProvider = StateNotifierProvider<RecipeNotifier, List<Recipe>>((ref) {
  return RecipeNotifier();
});

// Provider for a single recipe by ID
final recipeDetailProvider = Provider.family<Recipe?, String>((ref, id) {
  return ref.watch(recipeProvider.notifier).getRecipeById(id);
});

// Provider for recipes by category
final recipesByCategoryProvider = Provider.family<List<Recipe>, String>((ref, categoryId) {
  return ref.watch(recipeProvider.notifier).getRecipesByCategory(categoryId);
});

// Provider for favorite recipes
final favoriteRecipesProvider = Provider<List<Recipe>>((ref) {
  return ref.watch(recipeProvider.notifier).getFavoriteRecipes();
});

// Provider for searched recipes
final searchRecipesProvider = Provider.family<List<Recipe>, String>((ref, query) {
  return ref.watch(recipeProvider.notifier).searchRecipes(query);
});