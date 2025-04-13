import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../dummy_data/dummy_categories.dart';

class CategoryNotifier extends StateNotifier<List<Category>> {
  CategoryNotifier() : super(dummyCategories);

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