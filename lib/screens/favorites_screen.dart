import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe.dart';
import '../widgets/recipe_card.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteRecipes = ref.watch(favoriteRecipesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Recipes'),
        elevation: 0,
      ),
      body: favoriteRecipes.isEmpty 
          ? _buildEmptyState(context)
          : _buildFavoritesList(context, favoriteRecipes),
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No favorite recipes yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start adding recipes you love to your favorites',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.go('/');
            },
            icon: const Icon(Icons.explore),
            label: const Text('Explore Recipes'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFavoritesList(BuildContext context, List<Recipe> recipes) {
    return CustomScrollView(
      slivers: [
        // Header section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${recipes.length} Favorites',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your collection of favorite recipes',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Sort options
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Sort by:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: 'Date Added',
                  items: ['Date Added', 'Rating', 'Cooking Time', 'Alphabetical']
                      .map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (_) {},
                  underline: Container(),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.grid_view),
                  onPressed: () {},
                  color: Theme.of(context).colorScheme.primary,
                ),
                IconButton(
                  icon: const Icon(Icons.view_list),
                  onPressed: () {},
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
        
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return FadeInUp(
                  duration: Duration(milliseconds: 300 + (index * 50)),
                  child: RecipeCard(recipe: recipes[index]),
                );
              },
              childCount: recipes.length,
            ),
          ),
        ),
      ],
    );
  }
}