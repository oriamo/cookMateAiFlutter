import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import '../providers/recipe_provider.dart';
import '../widgets/recipe_card.dart';
import '../widgets/shimmers/recipe_card_shimmer.dart';

class CategoryScreen extends ConsumerWidget {
  final String categoryId;
  final String categoryName;
  
  const CategoryScreen({
    super.key, 
    required this.categoryId,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(categoryRecipesProvider(categoryId));
    
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore $categoryName Recipes',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Find the best ${categoryName.toLowerCase()} dishes curated just for you',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                _buildFilterChip(context, 'All', true),
                _buildFilterChip(context, 'Popular', false),
                _buildFilterChip(context, 'Quick', false),
                _buildFilterChip(context, 'Easy', false),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${recipes.length} recipes found',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Recipe grid
          Expanded(
            child: recipes.isEmpty
                ? _buildRecipeShimmers()
                : _buildRecipeGrid(recipes),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(BuildContext context, String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      backgroundColor: Colors.grey.shade200,
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      checkmarkColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected 
            ? Theme.of(context).colorScheme.primary 
            : Colors.grey.shade800,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        // Filter logic to be implemented
      },
    );
  }
  
  Widget _buildRecipeGrid(List<dynamic> recipes) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        return FadeInUp(
          duration: Duration(milliseconds: 300 + (index * 50)),
          child: RecipeCard(recipe: recipes[index]),
        );
      },
    );
  }
  
  Widget _buildRecipeShimmers() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const RecipeCardShimmer();
      },
    );
  }
}