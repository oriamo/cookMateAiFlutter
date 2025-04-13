import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../widgets/recipe_card.dart';
import 'package:animate_do/animate_do.dart';

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
    setState(() {
      _selectedCategory = category;
    });
    ref.read(recipeProvider.notifier).changeCategory(category);

    // Switch to the All Meals tab to show filtered results
    _tabController.animateTo(1);
  }

  void _clearFilter() {
    setState(() {
      _selectedCategory = null;
    });
    ref.read(recipeProvider.notifier).changeCategory('All Recipes');
    // Scroll back to top
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
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
    final isSelected = category == _selectedCategory;
    return InkWell(
      onTap: () => _selectCategory(category),
      child: Card(
        elevation: isSelected ? 8 : 4,
        color: isSelected ? Theme.of(context).primaryColor : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isSelected
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.7),
                      Theme.of(context).primaryColor,
                    ],
                  ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                capitalizeFirstLetter(category),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No recipes found',
              style: TextStyle(fontSize: 18),
            ),
            if (_selectedCategory != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCategory = null;
                  });
                  ref
                      .read(recipeProvider.notifier)
                      .changeCategory('All Recipes');
                },
                child: const Text('Show all recipes'),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
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
            duration: Duration(milliseconds: 300 + (index * 50)),
            child: RecipeCard(recipe: recipes[index]),
          ),
        );
      },
    );
  }

  Widget _buildRecipeInfo(AsyncValue<Map<String, dynamic>> recipesAsync) {
    return Column(
      children: [
        if (_selectedCategory != null)
          Padding(
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
        Expanded(
          child: recipesAsync.when(
            data: (data) {
              final recipesList =
                  (data['recipes'] as List<dynamic>).cast<Recipe>();
              return _buildRecipesList(recipesList);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
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
