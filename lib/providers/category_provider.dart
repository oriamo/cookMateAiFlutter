import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';

// Sample data for categories
final List<Category> _sampleCategories = [
  Category(
    id: '1',
    name: 'Lunch',
    imageUrl:
        'https://images.unsplash.com/photo-1543352634-a1c51d9f1fa7?auto=format&fit=crop&w=800&q=80',
    description: 'Delicious lunch options for a satisfying midday meal.',
    recipeCount: 42,
  ),
  Category(
    id: '2',
    name: 'Dinner',
    imageUrl:
        'https://images.unsplash.com/photo-1535473895227-bdecb20fb157?auto=format&fit=crop&w=800&q=80',
    description: 'Hearty dinner recipes for the perfect evening meal.',
    recipeCount: 38,
  ),
  Category(
    id: '3',
    name: 'Breakfast',
    imageUrl:
        'https://images.unsplash.com/photo-1484723091739-30a097e8f929?auto=format&fit=crop&w=800&q=80',
    description: 'Start your day right with these breakfast favorites.',
    recipeCount: 53,
  ),
  Category(
    id: '4',
    name: 'Side Dish',
    imageUrl:
        'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80',
    description: 'Perfect accompaniments to complete your meal.',
    recipeCount: 35,
  ),
  Category(
    id: '5',
    name: 'Snacks',
    imageUrl:
        'https://images.unsplash.com/photo-1599490659213-e2b9527bd087?auto=format&fit=crop&w=800&q=80',
    description: 'Quick and tasty bites for any time of day.',
    recipeCount: 48,
  ),
  Category(
    id: '6',
    name: 'Condiment',
    imageUrl:
        'https://images.unsplash.com/photo-1472476443507-c7a5948772fc?auto=format&fit=crop&w=800&q=80',
    description: 'Sauces, dressings, and other flavor enhancers.',
    recipeCount: 30,
  ),
  Category(
    id: '7',
    name: 'Desserts',
    imageUrl:
        'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=800&q=80',
    description: 'Sweet treats to satisfy your cravings.',
    recipeCount: 29,
  ),
  Category(
    id: '8',
    name: 'Grilling',
    imageUrl:
        'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=800&q=80',
    description: 'Fire up the grill for these smoky and flavorful dishes.',
    recipeCount: 33,
  ),
];

class CategoryNotifier extends StateNotifier<List<Category>> {
  CategoryNotifier() : super(_sampleCategories);

  Category? getCategoryById(String id) {
    try {
      return state.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Category> getFeaturedCategories() {
    // Return top 4 categories with most recipes
    return List<Category>.from(state)
      ..sort((a, b) => b.recipeCount.compareTo(a.recipeCount))
      ..take(4).toList();
  }
}

// Main categories provider
final categoryProvider =
    StateNotifierProvider<CategoryNotifier, List<Category>>((ref) {
  return CategoryNotifier();
});

// Provider for a single category by ID
final categoryDetailProvider = Provider.family<Category?, String>((ref, id) {
  return ref.watch(categoryProvider.notifier).getCategoryById(id);
});

// Provider for featured categories
final featuredCategoriesProvider = Provider<List<Category>>((ref) {
  final categories = ref.watch(categoryProvider);
  // Return first 4 categories for featured section
  return categories.take(4).toList();
});
