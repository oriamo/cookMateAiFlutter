import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../providers/ingredients_provider.dart';
import '../providers/recipe_provider.dart';

class IngredientDetailScreen extends ConsumerWidget {
  final String ingredientId;

  const IngredientDetailScreen({
    super.key,
    required this.ingredientId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allIngredients = ref.watch(ingredientsProvider);
    final ingredient = allIngredients.firstWhere(
      (item) => item.id == ingredientId,
      orElse: () => Ingredient(id: '', name: 'Ingredient not found'),
    );

    // If ingredient not found, show error
    if (ingredient.id.isEmpty) {
      return _buildNotFoundScreen(context);
    }

    // If ingredient found, show details
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with curved bottom and hero image effect
          _buildSliverAppBar(context, ref, ingredient),

          // Main content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badges
                  _buildStatusBadges(context, ingredient),

                  // Action buttons
                  _buildActionButtons(context, ref, ingredient),

                  // Ingredient details
                  _buildDetailsSection(context, ingredient),

                  // Nutritional info placeholder (for future enhancement)
                  _buildNutritionalInfo(context),

                  // Recipe info if associated with a recipe
                  if (ingredient.recipeId != null)
                    _buildRecipeInfo(context, ref, ingredient),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingredient Not Found'),
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 80,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ingredient Not Found',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'The requested ingredient could not be found in your grocery list',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go('/ingredients'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Ingredients'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(
      BuildContext context, WidgetRef ref, Ingredient ingredient) {
    final categoryName = ingredient.category ?? 'Uncategorized';
    final categoryIcon = _getCategoryIcon(categoryName);
    final categoryColor = _getCategoryColor(categoryName);

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          ingredient.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3.0,
                color: Color.fromARGB(130, 0, 0, 0),
              ),
            ],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                categoryColor.withOpacity(0.6),
                categoryColor.withOpacity(0.9),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Background patterns
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: CustomPaint(
                    painter: BackgroundPatternPainter(categoryIcon),
                  ),
                ),
              ),
              // Centered icon
              Center(
                child: Icon(
                  categoryIcon,
                  size: 80,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
              // Gradient overlay for text legibility
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 100,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.5),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/ingredients'),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete),
          tooltip: 'Delete Ingredient',
          onPressed: () {
            _showDeleteConfirmation(context, ref, ingredient);
          },
        ),
      ],
    );
  }

  Widget _buildStatusBadges(BuildContext context, Ingredient ingredient) {
    final categoryName = ingredient.category ?? 'Uncategorized';
    final categoryIcon = _getCategoryIcon(categoryName);
    final categoryColor = _getCategoryColor(categoryName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(
            avatar: CircleAvatar(
              backgroundColor: Colors.transparent,
              child: Icon(
                categoryIcon,
                size: 18,
                color: categoryColor,
              ),
            ),
            label: Text(categoryName),
            backgroundColor: categoryColor.withOpacity(0.1),
            side: BorderSide(color: categoryColor.withOpacity(0.3)),
          ),
          Chip(
            avatar: CircleAvatar(
              backgroundColor: Colors.transparent,
              child: Icon(
                ingredient.isPurchased
                    ? Icons.check_circle
                    : Icons.shopping_cart,
                size: 18,
                color: ingredient.isPurchased ? Colors.green : Colors.orange,
              ),
            ),
            label: Text(ingredient.isPurchased ? 'Purchased' : 'To Buy'),
            backgroundColor: ingredient.isPurchased
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            side: BorderSide(
                color: ingredient.isPurchased
                    ? Colors.green.withOpacity(0.3)
                    : Colors.orange.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, Ingredient ingredient) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 2,
              ),
              onPressed: () {
                // Navigate back and trigger edit dialog
                Navigator.pop(context, {'action': 'edit', 'id': ingredient.id});
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(
                ingredient.isPurchased
                    ? Icons.remove_shopping_cart
                    : Icons.shopping_cart_checkout,
              ),
              label: Text(
                ingredient.isPurchased ? 'Mark as To Buy' : 'Mark as Purchased',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor:
                    ingredient.isPurchased ? Colors.orange : Colors.green,
                foregroundColor: Colors.white,
                elevation: 2,
              ),
              onPressed: () {
                ref
                    .read(ingredientsProvider.notifier)
                    .togglePurchased(ingredient.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    content: Text(
                      ingredient.isPurchased
                          ? '${ingredient.name} marked as to buy'
                          : '${ingredient.name} marked as purchased',
                    ),
                    duration: const Duration(seconds: 2),
                    action: SnackBarAction(
                      label: 'UNDO',
                      onPressed: () {
                        ref
                            .read(ingredientsProvider.notifier)
                            .togglePurchased(ingredient.id);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context, Ingredient ingredient) {
    final hasQuantity =
        ingredient.quantity != null && ingredient.quantity!.isNotEmpty;
    final hasUnit = ingredient.unit != null && ingredient.unit!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (hasQuantity || hasUnit)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.straighten,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: const Text('Amount'),
                    subtitle: Text(
                      [
                        if (hasQuantity) ingredient.quantity,
                        if (hasUnit) ingredient.unit,
                      ].join(' '),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.grey,
                      ),
                    ),
                    title: const Text('No quantity specified'),
                    subtitle: const Text(
                      'Add quantity details by editing this ingredient',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionalInfo(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.restaurant,
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Nutritional Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Text(
                    'Coming Soon',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Colors.grey,
                    ),
                  ),
                  title: const Text('Nutritional data not available yet'),
                  subtitle: const Text(
                    'We\'re working on adding detailed nutritional information for all ingredients.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeInfo(
      BuildContext context, WidgetRef ref, Ingredient ingredient) {
    final recipes = ref.watch(recipeProvider);
    final relatedRecipe = recipes.firstWhere(
      (recipe) => recipe.id == ingredient.recipeId,
      orElse: () => Recipe(
        id: '',
        title: 'Recipe not found',
        description: 'No description available',
        totalTimeMinutes: 0,
        prepTimeMinutes: 0,
        cookTimeMinutes: 0,
        difficulty: 'Easy',
        servings: 0,
        calories: 0,
        chefName: 'Unknown',
        rating: 0.0,
        reviewCount: 0,
        ingredients: [],
        instructions: [],
        tags: [],
        createdAt: DateTime.now(),
        categoryId: '',
        cuisineType: '',
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.menu_book,
                  color: Colors.purple,
                ),
                SizedBox(width: 12),
                Text(
                  'From Recipe',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (relatedRecipe.id.isNotEmpty)
                  InkWell(
                    onTap: () {
                      context.push('/recipe/${relatedRecipe.id}');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          if (relatedRecipe.imageUrl != null &&
                              relatedRecipe.imageUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                relatedRecipe.imageUrl!,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.purple.shade100,
                                    ),
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.purple),
                                  );
                                },
                              ),
                            )
                          else
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.purple.shade100,
                              ),
                              child: const Icon(Icons.restaurant,
                                  color: Colors.purple),
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  relatedRecipe.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (relatedRecipe.difficulty.isNotEmpty ||
                                    relatedRecipe.totalTimeMinutes > 0)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.timer,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${relatedRecipe.totalTimeMinutes} min',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.bar_chart,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        relatedRecipe.difficulty,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Tap to view recipe details',
                                        style: TextStyle(
                                          color: Colors.purple.shade300,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 16,
                                      color: Colors.purple.shade300,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.grey,
                      ),
                    ),
                    title: const Text('Recipe not found'),
                    subtitle: const Text(
                      'This ingredient was added from a recipe that may have been deleted.',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, WidgetRef ref, Ingredient ingredient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${ingredient.name}?'),
        content: const Text(
            'Are you sure you want to remove this ingredient from your grocery list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              ref
                  .read(ingredientsProvider.notifier)
                  .removeIngredient(ingredient.id);
              Navigator.pop(context); // Close dialog
              context.go('/ingredients'); // Go back to ingredients screen
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Helper function to get icon for category
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Produce':
        return Icons.eco;
      case 'Meat & Seafood':
        return Icons.food_bank;
      case 'Dairy':
        return Icons.egg;
      case 'Grains & Bread':
        return Icons.bakery_dining;
      case 'Canned Goods':
        return Icons.inventory_2;
      case 'Spices':
        return Icons.spa;
      case 'Baking':
        return Icons.cake;
      case 'Frozen':
        return Icons.ac_unit;
      case 'Snacks':
        return Icons.cookie;
      case 'Beverages':
        return Icons.local_drink;
      case 'Other':
      default:
        return Icons.shopping_basket;
    }
  }

  // Helper function to get color for category
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Produce':
        return Colors.green;
      case 'Meat & Seafood':
        return Colors.red;
      case 'Dairy':
        return Colors.blue;
      case 'Grains & Bread':
        return Colors.amber;
      case 'Canned Goods':
        return Colors.indigo;
      case 'Spices':
        return Colors.deepOrange;
      case 'Baking':
        return Colors.brown;
      case 'Frozen':
        return Colors.lightBlue;
      case 'Snacks':
        return Colors.purple;
      case 'Beverages':
        return Colors.teal;
      case 'Other':
      default:
        return Colors.grey;
    }
  }
}

// Custom painter for the background pattern
class BackgroundPatternPainter extends CustomPainter {
  final IconData icon;

  BackgroundPatternPainter(this.icon);

  @override
  void paint(Canvas canvas, Size size) {
    final iconPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 24,
          fontFamily: icon.fontFamily,
          color: Colors.white,
        ),
      ),
    );

    iconPainter.layout();

    for (int i = -1; i < size.width / 50; i++) {
      for (int j = -1; j < size.height / 50; j++) {
        iconPainter.paint(canvas, Offset(i * 50.0, j * 50.0));
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
