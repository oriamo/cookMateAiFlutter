import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../widgets/recipe_card.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Helper function to capitalize first letter
String capitalizeFirstLetter(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}

// Provider to get unique categories from recipes
final uniqueCategoriesProvider = Provider<AsyncValue<List<String>>>((ref) {
  return ref.watch(recipeProvider).whenData((data) {
    final recipes = (data['recipes'] as List<dynamic>).cast<Recipe>();
    final categories = recipes.map((r) => r.category).toSet().toList()
      ..sort(); // Sort alphabetically
    return categories;
  });
});

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  bool _isLoading = false;
  late TabController _tabController;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (ref.read(recipeProvider).hasValue &&
          ref.read(recipeProvider.notifier).hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(recipeProvider.notifier).loadMoreRecipes();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _selectCategory(String category) {
    // First animate to the All Meals tab
    _tabController.animateTo(1, duration: const Duration(milliseconds: 300));

    // Then after the tab animation, update the category
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _selectedCategory = category;
      });
      ref.read(recipeProvider.notifier).changeCategory(category);
    });
  }

  void _clearFilter() {
    setState(() {
      _selectedCategory = null;
    });
    ref.read(recipeProvider.notifier).changeCategory('All Recipes');

    // Scroll back to top with animation
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildCategoryGrid() {
    final categoriesAsync = ref.watch(uniqueCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return FadeInUp(
            duration: Duration(milliseconds: 300 + (index * 50)),
            child: _buildCategoryCard(category),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildCategoryCard(String category) {
    return InkWell(
      onTap: () => _selectCategory(category),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: _getCategoryImage(category),
              fit: BoxFit.cover,
              memCacheWidth: 800,
              fadeInDuration: const Duration(milliseconds: 300),
              placeholder: (context, url) => Container(
                color: Colors.grey.shade100,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.7),
                      Theme.of(context).primaryColor,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          // Category name
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                capitalizeFirstLetter(category),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3.0,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryImage(String category) {
    // Map categories to curated Unsplash food images with consistent style and overhead shots
    final categoryImages = {
      'Breakfast':
          'https://images.unsplash.com/photo-1484723091739-30a097e8f929?auto=format&fit=crop&w=800&q=80',
      'Lunch':
          'https://images.unsplash.com/photo-1543352634-a1c51d9f1fa7?auto=format&fit=crop&w=800&q=80',
      'Dinner':
          'https://images.unsplash.com/photo-1535473895227-bdecb20fb157?auto=format&fit=crop&w=800&q=80',
      'Side Dish':
          'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80',
      'Snacks':
          'https://images.unsplash.com/photo-1599490659213-e2b9527bd087?auto=format&fit=crop&w=800&q=80',
      'Condiment':
          'https://images.unsplash.com/photo-1472476443507-c7a5948772fc?auto=format&fit=crop&w=800&q=80',
      'Desserts':
          'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=800&q=80',
      'Grilling':
          'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=800&q=80',
    };

    // Return the matching image URL or a default food image
    return categoryImages[category] ??
        'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80';
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : TextButton(
                onPressed: _loadMore,
                child: const Text('Load More'),
              ),
      ),
    );
  }

  Widget _buildRecipesList(List<Recipe> recipes) {
    if (recipes.isEmpty) {
      return FadeInUp(
        duration: const Duration(milliseconds: 300),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'No recipes found',
                style: TextStyle(fontSize: 18),
              ),
              if (_selectedCategory != null)
                TextButton(
                  onPressed: _clearFilter,
                  child: const Text('Show all recipes'),
                ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      key: ValueKey(
          _selectedCategory), // Add key to force rebuild on filter change
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      itemCount: recipes.length + 1,
      itemBuilder: (context, index) {
        if (index == recipes.length) {
          return _buildLoadingIndicator();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: FadeInUp(
            duration: Duration(milliseconds: 200 + (index * 50)),
            from: 50,
            child: SlideInLeft(
              duration: Duration(milliseconds: 200 + (index * 50)),
              from: 50,
              child: RecipeCard(recipe: recipes[index]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipeInfo(AsyncValue<Map<String, dynamic>> recipesAsync) {
    return Column(
      children: [
        if (_selectedCategory != null)
          FadeInDown(
            duration: const Duration(milliseconds: 300),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    'Showing ${capitalizeFirstLetter(_selectedCategory!)} recipes',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearFilter,
                    child: const Text('Clear filter'),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: recipesAsync.when(
            data: (data) {
              final recipesList =
                  (data['recipes'] as List<dynamic>).cast<Recipe>();
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildRecipesList(recipesList),
              );
            },
            loading: () => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _selectedCategory != null
                        ? 'Loading ${_selectedCategory!.toLowerCase()} recipes...'
                        : 'Loading all recipes...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            error: (error, stack) => Center(
              child: Text('Error: $error'),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Categories'),
            Tab(text: 'All Meals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryGrid(),
          _buildRecipeInfo(recipesAsync),
        ],
      ),
    );
  }
}
