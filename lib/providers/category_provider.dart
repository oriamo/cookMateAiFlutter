import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../services/azure_function_service.dart';
import '../services/azure_function_service_provider.dart';

class CategoryNotifier extends StateNotifier<List<Category>> {
  final AzureFunctionService _azureFunctionService;
  
  CategoryNotifier(this._azureFunctionService) : super([]) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      // Get categories from the backend
      final data = await _azureFunctionService.getPaginatedMeals();
      
      // Extract category information
      final categories = (data['categories'] as List<String>).map((category) => Category(
        id: category,
        name: category,
        imageUrl: 'https://source.unsplash.com/400x300/?$category,food',
        recipeCount: 0, // We don't have counts in this implementation
      )).toList();
      
      state = categories;
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

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
  final azureFunctionService = ref.watch(azureFunctionServiceProvider);
  return CategoryNotifier(azureFunctionService);
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