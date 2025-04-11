import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';

// Mock data for initial state
final sampleRecipes = [
  Recipe(
    id: 'recipe-1',
    title: 'Creamy Garlic Parmesan Pasta',
    description: 'A rich and creamy pasta dish that\'s perfect for a quick weeknight dinner',
    ingredients: [
      '8 oz fettuccine pasta',
      '2 tablespoons butter',
      '4 cloves garlic, minced',
      '1 cup heavy cream',
      '1 cup grated Parmesan cheese',
      'Salt and pepper to taste',
      '¼ teaspoon red pepper flakes (optional)',
      'Fresh parsley, chopped'
    ],
    instructions: [
      'Cook pasta according to package directions until al dente. Reserve ½ cup pasta water before draining.',
      'In a large skillet, melt butter over medium heat. Add garlic and cook until fragrant, about 1 minute.',
      'Pour in heavy cream and bring to a simmer. Cook for 2-3 minutes until it starts to thicken.',
      'Reduce heat to low and gradually whisk in Parmesan cheese until smooth and creamy.',
      'Season with salt, pepper, and red pepper flakes if using.',
      'Add the drained pasta to the sauce and toss to coat. If needed, add a splash of reserved pasta water to reach desired consistency.',
      'Garnish with chopped parsley and additional Parmesan cheese before serving.'
    ],
    imageUrl: 'https://images.unsplash.com/photo-1608219992759-8d74ed8d76eb?q=80&w=1000',
    aiTips: 'For a healthier version, you can substitute half the cream with chicken broth. Add grilled chicken or sautéed shrimp for extra protein.',
    rating: 4.8,
    prepTimeMinutes: 10,
    cookTimeMinutes: 15,
    difficulty: 'Easy',
    categories: ['Pasta', 'Italian', 'Quick Meals'],
    chefName: 'Maria Rossi',
    calories: 450,
    servings: 4,
  ),
  Recipe(
    id: 'recipe-2',
    title: 'Asian-Inspired Salmon Bowl',
    description: 'A nutritious and flavorful bowl featuring glazed salmon and colorful vegetables',
    ingredients: [
      '4 salmon fillets (6 oz each)',
      '¼ cup soy sauce',
      '2 tablespoons honey',
      '1 tablespoon rice vinegar',
      '1 tablespoon sesame oil',
      '2 cloves garlic, minced',
      '1-inch piece ginger, grated',
      '2 cups cooked brown rice',
      '1 cucumber, sliced',
      '1 carrot, julienned',
      '1 avocado, sliced',
      '¼ cup edamame',
      'Sesame seeds and sliced green onions for garnish'
    ],
    instructions: [
      'In a bowl, mix soy sauce, honey, rice vinegar, sesame oil, garlic, and ginger to create the marinade.',
      'Place salmon in a shallow dish and pour half the marinade over it. Let marinate for 15-30 minutes.',
      'Preheat oven to 400°F (200°C). Place salmon on a lined baking sheet and bake for 12-15 minutes.',
      'While salmon is cooking, prepare bowls with brown rice as the base.',
      'Arrange cucumber, carrot, avocado, and edamame around the rice.',
      'When salmon is done, place on top of the rice.',
      'Drizzle with remaining marinade and garnish with sesame seeds and green onions.'
    ],
    imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=1000',
    aiTips: 'For meal prep, you can prepare all components ahead of time and assemble when ready to eat. The marinade also works great with chicken or tofu.',
    rating: 4.9,
    prepTimeMinutes: 20,
    cookTimeMinutes: 15,
    difficulty: 'Medium',
    categories: ['Seafood', 'Asian', 'Healthy', 'Bowls'],
    chefName: 'James Chen',
    calories: 520,
    servings: 4,
  ),
  Recipe(
    id: 'recipe-3',
    title: 'Mediterranean Chickpea Salad',
    description: 'A refreshing and protein-packed salad with Mediterranean flavors',
    ingredients: [
      '2 (15 oz) cans chickpeas, drained and rinsed',
      '1 English cucumber, diced',
      '1 pint cherry tomatoes, halved',
      '1 red bell pepper, diced',
      '½ red onion, finely chopped',
      '½ cup kalamata olives, halved',
      '½ cup crumbled feta cheese',
      '¼ cup fresh parsley, chopped',
      '3 tablespoons olive oil',
      '2 tablespoons lemon juice',
      '1 teaspoon dried oregano',
      'Salt and pepper to taste'
    ],
    instructions: [
      'In a large bowl, combine chickpeas, cucumber, tomatoes, bell pepper, red onion, olives, feta cheese, and parsley.',
      'In a small bowl, whisk together olive oil, lemon juice, oregano, salt, and pepper to make the dressing.',
      'Pour the dressing over the salad and toss gently to combine.',
      'Refrigerate for at least 30 minutes before serving to allow flavors to meld.',
      'Serve chilled as a main dish or side salad.'
    ],
    imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?q=80&w=1000',
    aiTips: 'This salad keeps well in the refrigerator for up to 3 days, making it perfect for meal prep. For a vegan version, omit the feta or substitute with a plant-based alternative.',
    rating: 4.7,
    prepTimeMinutes: 15,
    cookTimeMinutes: 0,
    difficulty: 'Easy',
    categories: ['Salad', 'Mediterranean', 'Vegetarian', 'No-Cook'],
    chefName: 'Elena Papadopoulos',
    calories: 320,
    servings: 6,
  ),
  Recipe(
    id: 'recipe-4',
    title: 'Homemade Beef Burgers',
    description: 'Classic juicy beef burgers with all the fixings',
    ingredients: [
      '2 lbs ground beef (80/20)',
      '1 tablespoon Worcestershire sauce',
      '2 cloves garlic, minced',
      '1 teaspoon onion powder',
      'Salt and pepper to taste',
      '6 hamburger buns',
      '6 slices cheese (cheddar or American)',
      'Lettuce leaves',
      'Tomato slices',
      'Red onion slices',
      'Dill pickle slices',
      'Ketchup, mustard, and mayonnaise'
    ],
    instructions: [
      'In a large bowl, combine ground beef, Worcestershire sauce, garlic, onion powder, salt, and pepper. Mix gently with your hands until just combined (don\'t overmix).',
      'Divide the mixture into 6 equal portions and form into patties about ½-inch thick. Press a slight dimple in the center of each patty to prevent bulging while cooking.',
      'Preheat grill or skillet to medium-high heat. Cook patties for 4-5 minutes per side for medium doneness.',
      'During the last minute of cooking, top each patty with a slice of cheese and toast the buns.',
      'Assemble burgers with desired toppings and condiments.'
    ],
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=1000',
    aiTips: 'For the juiciest burgers, avoid pressing down on the patties while cooking. You can also mix in different seasonings or finely chopped onions for extra flavor.',
    rating: 4.6,
    prepTimeMinutes: 15,
    cookTimeMinutes: 10,
    difficulty: 'Easy',
    categories: ['American', 'Grill', 'Beef'],
    chefName: 'Robert Johnson',
    calories: 580,
    servings: 6,
  ),
  Recipe(
    id: 'recipe-5',
    title: 'Vegetable Coconut Curry',
    description: 'A rich and aromatic vegetable curry with coconut milk',
    ingredients: [
      '2 tablespoons coconut oil',
      '1 onion, diced',
      '3 cloves garlic, minced',
      '1 tablespoon grated ginger',
      '2 tablespoons curry powder',
      '1 teaspoon ground turmeric',
      '1 red bell pepper, diced',
      '1 zucchini, diced',
      '1 sweet potato, peeled and diced',
      '1 cup cauliflower florets',
      '1 (15 oz) can chickpeas, drained and rinsed',
      '1 (14 oz) can coconut milk',
      '1 cup vegetable broth',
      'Salt and pepper to taste',
      'Fresh cilantro and lime wedges for serving',
      'Cooked rice for serving'
    ],
    instructions: [
      'Heat coconut oil in a large pot over medium heat. Add onion and cook until softened, about 5 minutes.',
      'Add garlic and ginger, cook for 1 minute until fragrant.',
      'Stir in curry powder and turmeric, cook for 30 seconds to bloom the spices.',
      'Add bell pepper, zucchini, sweet potato, and cauliflower. Stir to coat with spices.',
      'Pour in coconut milk and vegetable broth. Bring to a simmer.',
      'Cover and cook for 15-20 minutes, until vegetables are tender.',
      'Add chickpeas and simmer uncovered for 5 more minutes.',
      'Season with salt and pepper to taste.',
      'Serve over rice, garnished with cilantro and lime wedges.'
    ],
    imageUrl: 'https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?q=80&w=1000',
    aiTips: 'This curry tastes even better the next day after the flavors have had time to develop. Feel free to substitute any vegetables you have on hand – this recipe is very flexible.',
    rating: 4.8,
    prepTimeMinutes: 20,
    cookTimeMinutes: 30,
    difficulty: 'Medium',
    categories: ['Curry', 'Vegetarian', 'Indian-Inspired', 'One-Pot'],
    chefName: 'Priya Sharma',
    calories: 380,
    servings: 6,
  ),
  Recipe(
    id: 'recipe-6',
    title: 'Classic French Toast',
    description: 'A delicious breakfast classic with a hint of cinnamon and vanilla',
    ingredients: [
      '8 slices thick bread (preferably day-old or slightly stale)',
      '4 large eggs',
      '1 cup milk',
      '2 tablespoons sugar',
      '1 teaspoon vanilla extract',
      '1/2 teaspoon ground cinnamon',
      'Pinch of salt',
      '2 tablespoons butter for cooking',
      'Maple syrup for serving',
      'Fresh berries for serving (optional)',
      'Powdered sugar for dusting (optional)'
    ],
    instructions: [
      'In a shallow bowl, whisk together eggs, milk, sugar, vanilla, cinnamon, and salt.',
      'Melt some butter in a large skillet or griddle over medium heat.',
      'Dip each slice of bread in the egg mixture, allowing it to soak for about 10 seconds on each side.',
      'Place soaked bread on the hot skillet and cook until golden brown, about 2-3 minutes per side.',
      'Repeat with remaining slices, adding more butter to the pan as needed.',
      'Serve warm with maple syrup, fresh berries, and a dusting of powdered sugar if desired.'
    ],
    imageUrl: 'https://images.unsplash.com/photo-1484723091739-30a097e8f929?q=80&w=1000',
    aiTips: 'For extra flavor, try adding a tiny bit of orange zest to the egg mixture. Using slightly stale bread helps prevent the French toast from becoming too soggy.',
    rating: 4.9,
    prepTimeMinutes: 10,
    cookTimeMinutes: 15,
    difficulty: 'Easy',
    categories: ['Breakfast', 'Sweet', 'Quick'],
    chefName: 'Thomas Laurent',
    calories: 340,
    servings: 4,
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
          recipe.description.toLowerCase().contains(lowercaseQuery) ||
          recipe.ingredients.any((ingredient) => 
              ingredient.toLowerCase().contains(lowercaseQuery)) ||
          recipe.categories.any((category) =>
              category.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }
  
  List<Recipe> getRecipesByCategory(String category) {
    return state.where((recipe) => 
        recipe.categories.any((cat) => 
            cat.toLowerCase() == category.toLowerCase())).toList();
  }
  
  void toggleFavorite(String id) {
    state = state.map((recipe) => 
      recipe.id == id 
          ? recipe.copyWith(isFavorite: !recipe.isFavorite) 
          : recipe
    ).toList();
  }
  
  List<Recipe> getFavorites() {
    return state.where((recipe) => recipe.isFavorite).toList();
  }
  
  List<Recipe> getPopularRecipes() {
    final sortedList = [...state];
    sortedList.sort((a, b) => b.rating.compareTo(a.rating));
    return sortedList.take(5).toList();
  }
  
  List<Recipe> getQuickRecipes() {
    return state.where((recipe) => recipe.totalTimeMinutes <= 30).toList();
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

// Category recipes provider
final categoryRecipesProvider = Provider.family<List<Recipe>, String>((ref, category) {
  final recipeNotifier = ref.watch(recipeProvider.notifier);
  return recipeNotifier.getRecipesByCategory(category);
});

// Favorites provider
final favoritesProvider = Provider<List<Recipe>>((ref) {
  final recipeNotifier = ref.watch(recipeProvider.notifier);
  return recipeNotifier.getFavorites();
});

// Popular recipes provider
final popularRecipesProvider = Provider<List<Recipe>>((ref) {
  final recipeNotifier = ref.watch(recipeProvider.notifier);
  return recipeNotifier.getPopularRecipes();
});

// Quick meals provider
final quickRecipesProvider = Provider<List<Recipe>>((ref) {
  final recipeNotifier = ref.watch(recipeProvider.notifier);
  return recipeNotifier.getQuickRecipes();
});