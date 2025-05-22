import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'azure_function_service.dart';
import '../models/recipe.dart';

// Provider that creates and returns the AzureFunctionService instance
final azureFunctionServiceProvider = Provider<AzureFunctionService>((ref) {
  return AzureFunctionServiceMock();
});

// Mock implementation for demo UI purposes
class AzureFunctionServiceMock implements AzureFunctionService {
  @override
  Future<Map<String, dynamic>> getPaginatedMeals({
    String? category,
    String? searchTerm,
    String? continuationToken,
    int pageSize = 15,
  }) async {
    // Return an empty response to force the app to use our dummy data
    return {
      'items': [],
      'categories': [],
      'continuationToken': null,
    };
  }

  @override
  Future<dynamic> callAzureFunction(String functionName, Map<String, dynamic> body,
      {bool? returnRawResponse}) async {
    // Mock implementation - returns an empty response
    return {};
  }
  
  @override
  Future<Map<String, dynamic>> createMeal({
    required String name,
    required List<Map<String, dynamic>> ingredients,
    required List<String> instructions,
    required int cookingTime,
    required int servings,
    required String category,
    required String difficulty,
    int? calories,
  }) async {
    // Mock implementation for demo mode
    return {'id': 'mock-id-${DateTime.now().millisecondsSinceEpoch}'};
  }
  
  @override
  Future<List<String>> getCategories() async {
    // Mock implementation for demo mode
    return [];
  }
  @override
  Future<Recipe> getMeal(String id) async {
    // Mock implementation for demo mode
    return Recipe(
      id: id,
      title: 'Mock Recipe',
      ingredients: [],
      instructions: [],
      prepTimeMinutes: 20,
      totalTimeMinutes: 3,
      description: 'This is a mock recipe for demo purposes.',
      servings: 1,
      category: 'Mock Category',
      difficulty: 'Easy',
      calories: 0,
    );
  }

  @override
  Future<void> toggleFavorite(String recipeId) async {
    // Mock implementation for demo mode
    return;
  }
}