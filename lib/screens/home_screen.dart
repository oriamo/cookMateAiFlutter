import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import '../providers/recipe_provider.dart';
import '../providers/category_provider.dart';
import '../models/recipe.dart';
import '../models/category.dart';
import '../widgets/category_card.dart';
import '../widgets/recipe_card.dart';
import '../widgets/shimmers/recipe_card_shimmer.dart';
import '../widgets/shimmers/category_card_shimmer.dart';
import '../dummy_data/dummy_recipes.dart';
import '../dummy_data/dummy_categories.dart';

// DEMO MODE: Direct access to dummy data for more reliable rendering
final dummyFeaturedRecipesProvider = Provider<List<Recipe>>((ref) {
  // Get first 5 recipes from dummy data
  return dummyRecipes.take(5).toList();
});

final dummyPopularRecipesProvider = Provider<List<Recipe>>((ref) {
  // Sort by rating and get top 6
  final recipes = List<Recipe>.from(dummyRecipes)
    ..sort((a, b) => b.rating.compareTo(a.rating));
  return recipes.take(6).toList();
});

final dummyCategoriesProvider = Provider<List<Category>>((ref) {
  return dummyCategories;
});

// Keeping the original providers as fallback, but we'll primarily use the dummy ones
final featuredRecipesProvider = Provider<AsyncValue<List<Recipe>>>((ref) {
  return ref.watch(recipeProvider).whenData((data) {
    final recipes = (data['recipes'] as List<dynamic>).cast<Recipe>();
    return recipes.take(5).toList();
  });
});

final popularRecipesProvider = Provider<AsyncValue<List<Recipe>>>((ref) {
  return ref.watch(recipeProvider).whenData((data) {
    final recipes = (data['recipes'] as List<dynamic>).cast<Recipe>().toList();
    recipes.sort((a, b) => b.rating.compareTo(a.rating));
    return recipes.sublist(0, recipes.length > 6 ? 6 : recipes.length);
  });
});

// Categories provider - uses existing category provider
final categoriesProvider = Provider<List<Category>>((ref) {
  return ref.watch(categoryProvider);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isSearchBarVisible = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 180 && !_isSearchBarVisible) {
      setState(() => _isSearchBarVisible = true);
    } else if (_scrollController.offset <= 180 && _isSearchBarVisible) {
      setState(() => _isSearchBarVisible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // DEMO MODE: Use dummy data providers directly for immediate rendering
    final dummyFeatured = ref.watch(dummyFeaturedRecipesProvider);
    final dummyPopular = ref.watch(dummyPopularRecipesProvider);
    final dummyCategories = ref.watch(dummyCategoriesProvider);
    
    // Also watch the original providers as fallback
    final featuredRecipes = ref.watch(featuredRecipesProvider);
    final popularRecipes = ref.watch(popularRecipesProvider);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor:
                _isSearchBarVisible ? Colors.green : Colors.transparent,
            foregroundColor: Colors.white,
            elevation: _isSearchBarVisible ? 4 : 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.shade400,
                      Colors.green.shade700,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Row(
                          children: [
                            const Text(
                              'CookMate',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'AI',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ),
                            // Removing the Spacer and shopping cart icon to fix overflow
                          ],
                        ),
                      ),
                      // Add new meal and grocery list buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => context.go('/upload-meal'),
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Add New Meal'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => context.go('/ingredients'),
                                icon: const Icon(Icons.shopping_cart_outlined),
                                label: const Text('Grocery List'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.85),
                                  foregroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What would you like to cook today?',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () {
                                context.go('/search');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.search),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Search for recipes or ingredients',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              collapseMode: CollapseMode.pin,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => context.go('/ingredients'),
                tooltip: 'Grocery List',
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => context.go('/upload-meal'),
                tooltip: 'Add New Meal',
              ),
            ],
          ),

          // Categories section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Categories',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/explore'),
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
          ),

          // SliverToBoxAdapter(
          //   child: SizedBox(
          //     height: 120,
          //     child: categories.isEmpty
          //         ? _buildCategoryShimmers()
          //         : _buildCategories(categories),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Use dummy categories directly in demo mode
                  return FadeInUp(
                    duration: Duration(milliseconds: 300 + (index * 50)),
                    child: CategoryCard(
                      category: dummyCategories[index],
                    ),
                  );
                },
                childCount: dummyCategories.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
            ),
          ),

          // Featured recipes section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Featured',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'HOT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.push('/explore'),
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: 300,
              // In demo mode, use dummy data directly
              child: _buildFeaturedRecipes(dummyFeatured),
            ),
          ),

          // Popular recipes section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Popular Recipes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/explore'),
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            // In demo mode, use dummy data directly
            sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: dummyPopular.length,
                itemBuilder: (context, index) {
                  return FadeInUp(
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    child: RecipeCard(recipe: dummyPopular[index]),
                  );
                },
              ),
            ),
          ),

          // AI Assistant banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: GestureDetector(
                  onTap: () {
                    context.go('/ai-chat');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.purple.shade400,
                          Colors.deepPurple.shade700,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ask Chef AI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Need help with a recipe? Get instant cooking advice!',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white.withOpacity(0.8),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories(List<Category> categories) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: FadeInRight(
            duration: Duration(milliseconds: 300 + (index * 100)),
            child: CategoryCard(category: categories[index]),
          ),
        );
      },
    );
  }

  Widget _buildCategoryShimmers() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: 5,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(right: 16),
          child: CategoryCardShimmer(),
        );
      },
    );
  }

  Widget _buildFeaturedRecipes(List<Recipe> recipes) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: SizedBox(
            width: 220,
            child: FadeInRight(
              duration: Duration(milliseconds: 300 + (index * 100)),
              child: RecipeCard(recipe: recipes[index]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipeShimmers() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(right: 16),
          child: SizedBox(
            width: 220,
            child: RecipeCardShimmer(),
          ),
        );
      },
    );
  }
}
