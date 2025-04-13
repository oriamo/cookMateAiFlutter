import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient.dart';
import '../providers/ingredients_provider.dart';

class AddToShoppingListButton extends ConsumerWidget {
  final List<Ingredient> ingredients;
  final String recipeId;
  final String recipeName;

  const AddToShoppingListButton({
    super.key,
    required this.ingredients,
    required this.recipeId,
    required this.recipeName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.shopping_cart),
      label: const Text('Add to Shopping List'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      onPressed: () => _handleAddIngredients(context, ref),
    );
  }

  void _handleAddIngredients(BuildContext context, WidgetRef ref) {
    // Check if there are ingredients to add
    if (ingredients.isEmpty) {
      _showSnackBar(context, 'No ingredients available to add');
      return;
    }

    // Add ingredients to the shopping list using the provider notifier
    ref.read(ingredientsProvider.notifier).addIngredientsFromRecipe(
          ingredients: ingredients,
          recipeId: recipeId,
        );

    // Show confirmation message with an action to view the shopping list
    _showSnackBar(
      context,
      'Added ${ingredients.length} ingredients to your shopping list',
      actionLabel: 'View',
      action: () {
        // Check if the widget is still in the widget tree before navigating
        if (context.mounted) {
          Navigator.pushNamed(context, '/ingredients');
        }
      },
    );
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? action,
  }) {
    final snackBar = SnackBar(
      content: Text(message),
      action: actionLabel != null && action != null
          ? SnackBarAction(
              label: actionLabel,
              onPressed: action,
            )
          : null,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
