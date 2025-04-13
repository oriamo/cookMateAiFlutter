import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../services/azure_function_service.dart';
import '../services/azure_function_service_provider.dart';

class RecipeNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final AzureFunctionService _service;
  String? _currentCategory;
  String? _continuationToken;
  bool _hasMore = true;

  RecipeNotifier(this._service) : super(const AsyncValue.loading()) {
    loadInitialRecipes();
  }

  Future<void> loadInitialRecipes() async {
    try {
      print('\n==== Loading Initial Recipes ====');
      state = const AsyncValue.loading();
      final result = await _service.getPaginatedMeals();
      print('API Response for initial load:');
      print('Items count: ${(result['items'] as List).length}');
      print('Categories: ${result['categories']}');
      print('First item sample: ${(result['items'] as List).first}');

      final recipes = (result['items'] as List).map((item) {
        print('\nProcessing recipe item:');
        print('Raw item: $item');
        final recipe = Recipe.fromJson(item);
        print('Processed into Recipe object successfully');
        return recipe;
      }).toList();

      state = AsyncValue.data({
        'recipes': recipes,
        'categories': ['All Recipes', ...result['categories'] as List<String>],
      });

      _continuationToken = result['continuationToken'];
      _hasMore = _continuationToken != null;
      print('==== Initial Load Complete ====\n');
    } catch (e, st) {
      print('!!!! Error in loadInitialRecipes !!!!');
      print('Error: $e');
      print('Stack trace: $st');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMoreRecipes() async {
    if (!_hasMore || state.isLoading) return;

    try {
      print('\n==== Loading More Recipes ====');
      print('Current category: $_currentCategory');
      print('Continuation token: $_continuationToken');

      final result = await _service.getPaginatedMeals(
        category: _currentCategory,
        continuationToken: _continuationToken,
      );

      print('API Response for load more:');
      print('Items count: ${(result['items'] as List).length}');
      print('First item sample: ${(result['items'] as List).first}');

      final newRecipes = (result['items'] as List).map((item) {
        print('\nProcessing recipe item:');
        print('Raw item: $item');
        final recipe = Recipe.fromJson(item);
        print('Processed into Recipe object successfully');
        return recipe;
      }).toList();

      state.whenData((currentData) {
        final currentRecipes = currentData['recipes'] as List<Recipe>;
        state = AsyncValue.data({
          'recipes': [...currentRecipes, ...newRecipes],
          'categories': currentData['categories'],
        });
      });

      _continuationToken = result['continuationToken'];
      _hasMore = _continuationToken != null;
      print('==== Load More Complete ====\n');
    } catch (e, st) {
      print('!!!! Error in loadMoreRecipes !!!!');
      print('Error: $e');
      print('Stack trace: $st');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> changeCategory(String category) async {
    if (_currentCategory == category) return;

    try {
      print('\n==== Changing Category ====');
      print('From: $_currentCategory');
      print('To: $category');

      _currentCategory = category == 'All Recipes' ? null : category;
      _continuationToken = null;
      _hasMore = true;

      final result =
          await _service.getPaginatedMeals(category: _currentCategory);
      print('API Response for category change:');
      print('Items count: ${(result['items'] as List).length}');
      print('First item sample: ${(result['items'] as List).first}');

      final recipes = (result['items'] as List).map((item) {
        print('\nProcessing recipe item:');
        print('Raw item: $item');
        final recipe = Recipe.fromJson(item);
        print('Processed into Recipe object successfully');
        return recipe;
      }).toList();

      state.whenData((currentData) {
        state = AsyncValue.data({
          'recipes': recipes,
          'categories': currentData['categories'],
        });
      });

      _continuationToken = result['continuationToken'];
      _hasMore = _continuationToken != null;
      print('==== Category Change Complete ====\n');
    } catch (e, st) {
      print('!!!! Error in changeCategory !!!!');
      print('Error: $e');
      print('Stack trace: $st');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleFavorite(String recipeId) async {
    state.whenData((currentData) {
      final recipes = List<Recipe>.from(currentData['recipes'] as List<Recipe>);
      final index = recipes.indexWhere((recipe) => recipe.id == recipeId);
      if (index != -1) {
        recipes[index] = recipes[index].copyWith(
          isFavorite: !recipes[index].isFavorite,
        );
        state = AsyncValue.data({
          'recipes': recipes,
          'categories': currentData['categories'],
        });
      }
    });
  }

  Future<void> fetchRecipes({String? category}) async {
    try {
      _currentCategory = category == 'All Recipes' ? null : category;
      _continuationToken = null;
      _hasMore = true;

      final result =
          await _service.getPaginatedMeals(category: _currentCategory);
      print('Raw API response: $result'); // Debug log

      state.whenData((currentData) {
        print('Processing items from API...'); // Debug log
        final items = result['items'] as List;
        print('Number of items to process: ${items.length}'); // Debug log

        final recipes = items.map((item) {
          print('Processing item: $item'); // Debug log
          return Recipe.fromJson(item);
        }).toList();

        print('Successfully processed ${recipes.length} recipes'); // Debug log

        state = AsyncValue.data({
          'recipes': recipes,
          'categories': currentData['categories'],
        });
      });

      _continuationToken = result['continuationToken'];
      _hasMore = _continuationToken != null;
    } catch (e, st) {
      print('Error fetching recipes: $e'); // Debug log
      print('Stack trace: $st'); // Debug log
      state = AsyncValue.error(e, st);
    }
  }

  bool get hasMore => _hasMore;
}

final recipeProvider =
    StateNotifierProvider<RecipeNotifier, AsyncValue<Map<String, dynamic>>>(
        (ref) {
  final service = ref.read(azureFunctionServiceProvider);
  return RecipeNotifier(service);
});

// Provider for favorite recipes
final favoriteRecipesProvider = Provider<List<Recipe>>((ref) {
  return ref.watch(recipeProvider).whenData((data) {
        if (data['recipes'] is List<Recipe>) {
          final recipes = data['recipes'] as List<Recipe>;
          return recipes.where((recipe) => recipe.isFavorite).toList();
        } else if (data['recipes'] is List) {
          final recipes = (data['recipes'] as List).map((item) {
            if (item is Recipe) return item;
            return Recipe.fromJson(item as Map<String, dynamic>);
          }).toList();
          return recipes.where((recipe) => recipe.isFavorite).toList();
        }
        return <Recipe>[];
      }).valueOrNull ??
      [];
});

// Provider for getting recipe details by ID
final recipeDetailProvider = Provider.family<Recipe?, String>((ref, id) {
  return ref.watch(recipeProvider).whenData((data) {
    final recipes = data['recipes'] as List<Recipe>;
    try {
      return recipes.firstWhere((recipe) => recipe.id == id);
    } catch (e) {
      return null;
    }
  }).valueOrNull;
});
