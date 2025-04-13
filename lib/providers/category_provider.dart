import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../dummy_data/dummy_categories.dart';
import '../services/azure_function_service.dart';
import '../services/azure_function_service_provider.dart';

class CategoryNotifier extends StateNotifier<List<Category>> {
  final AzureFunctionService _azureFunctionService;
  
  CategoryNotifier(this._azureFunctionService) : super(dummyCategories) {
    // For demo mode, we're already loaded with dummy data
    // But we'll still try to fetch from the backend in case it works
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      // Try to get categories from the backend
      final data = await _azureFunctionService.getPaginatedMeals();
      
      // Only update if we get real data back
      if (data['categories'] != null && (data['categories'] as List).isNotEmpty) {
        // Extract category information
        final categories = (data['categories'] as List<String>).map((category) => Category(
          id: category,
          name: category,
          imageUrl: 'https://source.unsplash.com/400x300/?$category,food',
          description: 'Delicious $category recipes',
          recipeCount: 0, // We don't have counts in this implementation
        )).toList();
        
        state = categories.cast<Category>();
      }
    } catch (e) {
      print('Error loading categories: $e - using dummy data');
      // If error, we already have dummy data loaded
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