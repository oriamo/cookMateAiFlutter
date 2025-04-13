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

// Define providers for home screen
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
    return recipes.sublist(
        0,
        recipes.length > 6
            ? 6
            : recipes.length); // Take exactly 6 items or all if less than 6
  });
});

// Use the existing categoriesProvider from category_provider.dart
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
    final featuredRecipes = ref.watch(featuredRecipesProvider);
    final popularRecipes = ref.watch(popularRecipesProvider);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 200,
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
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined,
                                  color: Colors.white),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
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
                            const SizedBox(height: 16),
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
                icon: const Icon(Icons.add),
                onPressed: () => context.go('/upload-meal'),
                tooltip: 'Upload New Meal',
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
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
                    onPressed: () {
                      context.go('/explore');
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (categories.isEmpty) {
                    return const CategoryCardShimmer();
                  }
                  return FadeInUp(
                    duration: Duration(milliseconds: 300 + (index * 50)),
                    child: CategoryCard(
                      category: categories[index],
                    ),
                  );
                },
                childCount: categories.isEmpty ? 4 : categories.length,
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
              child: featuredRecipes.when(
                data: (recipes) => _buildFeaturedRecipes(recipes),
                loading: () => _buildRecipeShimmers(),
                error: (error, stack) => Center(
                  child: Text('Error: $error'),
                ),
              ),
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
            sliver: popularRecipes.when(
              data: (recipes) => SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  return FadeInUp(
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    child: RecipeCard(recipe: recipes[index]),
                  );
                },
              ),
              loading: () => SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: 4,
                itemBuilder: (context, index) {
                  return const RecipeCardShimmer();
                },
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: Center(
                  child: Text('Error: $error'),
                ),
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
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: SizedBox(
            width: 220,
            child: RecipeCardShimmer(),
          ),
        );
      },
    );
  }
}
