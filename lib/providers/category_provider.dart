import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';

// Sample data for categories
final List<Category> _sampleCategories = [
  Category(
    id: '1',
    name: 'Italian',
    imageUrl: 'https://images.unsplash.com/photo-1498579150354-977475b7ea0b?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
    description: 'Traditional Italian recipes featuring pasta, pizza, risotto, and more.',
    recipeCount: 42,
  ),
  Category(
    id: '2',
    name: 'Asian',
    imageUrl: 'https://images.unsplash.com/photo-1541696490-8744a5dc0228?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
    description: 'Explore flavors from China, Japan, Thailand, Vietnam, and more.',
    recipeCount: 38,
  ),
  Category(
    id: '3',
    name: 'Vegetarian',
    imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
    description: 'Delicious meat-free dishes packed with vegetables, grains, and plant proteins.',
    recipeCount: 53,
  ),
  Category(
    id: '4',
    name: 'Desserts',
    imageUrl: 'https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
    description: 'Sweet treats including cakes, cookies, pies, and frozen delights.',
    recipeCount: 35,
  ),
  Category(
    id: '5',
    name: 'Quick & Easy',
    imageUrl: 'https://images.unsplash.com/photo-1556761223-4c4282c73f77?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
    description: 'Fast recipes ready in 30 minutes or less, perfect for busy weeknights.',
    recipeCount: 48,
  ),
  Category(
    id: '6',
    name: 'Healthy',
    imageUrl: 'https://images.unsplash.com/photo-1490645935967-10de6ba17061?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
    description: 'Nutritious meals focusing on balanced ingredients and wholesome cooking methods.',
    recipeCount: 61,
  ),
  Category(
    id: '7',
    name: 'Breakfast',
    imageUrl: 'https://images.unsplash.com/photo-1533089860892-a9b5be1a8f09?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
    description: 'Start your day right with these delicious breakfast and brunch recipes.',
    recipeCount: 29,
  ),
  Category(
    id: '8',
    name: 'Grilling',
    imageUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
    description: 'Fire up the grill for these smoky and flavorful outdoor cooking recipes.',
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
final categoryProvider = StateNotifierProvider<CategoryNotifier, List<Category>>((ref) {
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