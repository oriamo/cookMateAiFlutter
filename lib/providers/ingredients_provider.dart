import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ingredient.dart';
import '../dummy_data/dummy_ingredients.dart';
import 'package:uuid/uuid.dart';

class IngredientsNotifier extends StateNotifier<List<Ingredient>> {
  static const String _storageKey = 'user_ingredients_data';
  final _uuid = const Uuid();
  bool _isInitialDataLoaded = false;

  IngredientsNotifier() : super([]) {
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    try {
      // Demo mode: load dummy ingredients first if no saved data
      if (!_isInitialDataLoaded) {
        state = List<Ingredient>.from(dummyIngredients);
        _isInitialDataLoaded = true;
        
        // Save to SharedPreferences for persistence
        await _saveIngredients();
      }
      
      // Try to load from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final ingredientsJson = prefs.getString(_storageKey);

      if (ingredientsJson != null && ingredientsJson.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(ingredientsJson);
        state = decodedList.map((item) => Ingredient.fromJson(item)).toList();
      }
    } catch (e) {
      _logDebug('Error loading ingredients: $e');
    }
  }

  Future<void> _saveIngredients() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedList = state.map((item) => item.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(encodedList));
    } catch (e) {
      _logDebug('Error saving ingredients: $e');
    }
  }

  // Add a new ingredient to the list
  Future<void> addIngredient({
    required String name,
    String? quantity,
    String? unit,
    String? category,
    String? recipeId,
  }) async {
    final newIngredient = Ingredient(
      id: _uuid.v4(),
      name: name,
      quantity: quantity,
      unit: unit,
      category: category,
      recipeId: recipeId,
    );

    state = [...state, newIngredient];
    await _saveIngredients();
  }

  // Remove an ingredient from the list
  Future<void> removeIngredient(String id) async {
    state = state.where((ingredient) => ingredient.id != id).toList();
    await _saveIngredients();
  }

  // Toggle purchased status of an ingredient
  Future<void> togglePurchased(String id) async {
    state = state.map((ingredient) {
      if (ingredient.id == id) {
        return ingredient.copyWith(isPurchased: !ingredient.isPurchased);
      }
      return ingredient;
    }).toList();
    await _saveIngredients();
  }

  // Edit an existing ingredient
  Future<void> editIngredient({
    required String id,
    String? name,
    String? quantity,
    String? unit,
    String? category,
    String? recipeId,
    bool? isPurchased,
  }) async {
    state = state.map((ingredient) {
      if (ingredient.id == id) {
        return ingredient.copyWith(
          name: name,
          quantity: quantity,
          unit: unit,
          category: category,
          recipeId: recipeId,
          isPurchased: isPurchased,
        );
      }
      return ingredient;
    }).toList();
    await _saveIngredients();
  }

  // Add multiple ingredients at once (e.g., from a recipe)
  Future<void> addIngredientsFromRecipe({
    required List<Ingredient> ingredients,
    required String recipeId,
  }) async {
    // Add ingredients that don't exist yet
    final newIngredients = ingredients.map((ingredient) {
      return ingredient.copyWith(
        id: _uuid.v4(),
        recipeId: recipeId,
      );
    }).toList();

    state = [...state, ...newIngredients];
    await _saveIngredients();
  }

  // Clear all purchased ingredients
  Future<void> clearPurchased() async {
    state = state.where((ingredient) => !ingredient.isPurchased).toList();
    await _saveIngredients();
  }

  // Get ingredients by recipe
  List<Ingredient> getIngredientsByRecipe(String recipeId) {
    return state
        .where((ingredient) => ingredient.recipeId == recipeId)
        .toList();
  }

  void _logDebug(String message) {
    // Only log in debug mode
    assert(() {
      print('[IngredientsNotifier] $message');
      return true;
    }());
  }
}

final ingredientsProvider =
    StateNotifierProvider<IngredientsNotifier, List<Ingredient>>((ref) {
  return IngredientsNotifier();
});

// Additional providers for filtering ingredients
final unpurchasedIngredientsProvider = Provider<List<Ingredient>>((ref) {
  final ingredients = ref.watch(ingredientsProvider);
  return ingredients.where((ingredient) => !ingredient.isPurchased).toList();
});

final purchasedIngredientsProvider = Provider<List<Ingredient>>((ref) {
  final ingredients = ref.watch(ingredientsProvider);
  return ingredients.where((ingredient) => ingredient.isPurchased).toList();
});

// Provider to group ingredients by category
final groupedIngredientsProvider =
    Provider<Map<String?, List<Ingredient>>>((ref) {
  final ingredients = ref.watch(ingredientsProvider);
  return ingredients.fold<Map<String?, List<Ingredient>>>(
    {},
    (map, ingredient) {
      final category = ingredient.category ?? 'Other';
      if (!map.containsKey(category)) {
        map[category] = [];
      }
      map[category]!.add(ingredient);
      return map;
    },
  );
});