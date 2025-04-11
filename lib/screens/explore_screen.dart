import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import '../models/category.dart';
import '../models/recipe.dart';
import '../widgets/category_card.dart';
import '../widgets/recipe_card.dart';
import '../widgets/shimmers/category_card_shimmer.dart';
import '../widgets/shimmers/recipe_card_shimmer.dart';

// Define providers for explore screen
final exploreRecipesProvider = Provider<List<Recipe>>((ref) {
  // This would normally fetch from a repository or API
  // For now, we return an empty list
  return [];
});

final exploreCategoriesProvider = Provider<List<Category>>((ref) {
  // This would normally fetch from a repository or API
  // For now, we return an empty list
  return [];
});

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchController;
  bool _isSearching = false;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController = TextEditingController();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }
  
  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }
  
  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(exploreCategoriesProvider);
    final allRecipes = ref.watch(exploreRecipesProvider);
    
    // Filter recipes based on search
    final filteredRecipes = _searchQuery.isEmpty
        ? allRecipes
        : allRecipes.where((recipe) =>
            recipe.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            recipe.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            recipe.ingredients.any((ingredient) =>
                ingredient.toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList();
    
    // Filter categories based on search
    final filteredCategories = _searchQuery.isEmpty
        ? categories
        : categories.where((category) =>
            category.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: !_isSearching
            ? const Text(
                'Explore',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              )
            : TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search recipes, ingredients...',
                  border: InputBorder.none,
                ),
                onChanged: _updateSearchQuery,
                autofocus: true,
              ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.black),
              onPressed: _startSearch,
            )
          else
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: _stopSearch,
            ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onPressed: () {
              _showFilterBottomSheet(context);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'Categories'),
            Tab(text: 'All Recipes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Categories Tab
          _buildCategoriesTab(filteredCategories),
          
          // All Recipes Tab
          _buildRecipesTab(filteredRecipes),
        ],
      ),
    );
  }
  
  Widget _buildCategoriesTab(List<Category> categories) {
    if (categories.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoResultsFound();
    }
    
    return categories.isEmpty
        ? _buildCategoryShimmers()
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              return FadeInUp(
                duration: Duration(milliseconds: 300 + (index * 50)),
                child: CategoryCard(
                  category: categories[index],
                  isFeatured: false,
                ),
              );
            },
          );
  }
  
  Widget _buildRecipesTab(List<Recipe> recipes) {
    if (recipes.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoResultsFound();
    }
    
    return recipes.isEmpty
        ? _buildRecipeShimmers()
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              return FadeInUp(
                duration: Duration(milliseconds: 300 + (index * 50)),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: RecipeCard(
                    recipe: recipes[index],
                    isHorizontal: true,
                  ),
                ),
              );
            },
          );
  }
  
  Widget _buildCategoryShimmers() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const CategoryCardShimmer();
      },
    );
  }
  
  Widget _buildRecipeShimmers() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: RecipeCardShimmer(isHorizontal: true),
        );
      },
    );
  }
  
  Widget _buildNoResultsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No results found for "$_searchQuery"',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different keywords or filters',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Recipes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              const Text(
                'Cuisine Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _filterChip('Italian'),
                  _filterChip('Mexican'),
                  _filterChip('Chinese'),
                  _filterChip('Indian'),
                  _filterChip('Japanese'),
                  _filterChip('Thai'),
                ],
              ),
              
              const SizedBox(height: 16),
              const Text(
                'Meal Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _filterChip('Breakfast'),
                  _filterChip('Lunch'),
                  _filterChip('Dinner'),
                  _filterChip('Dessert'),
                  _filterChip('Snack'),
                ],
              ),
              
              const SizedBox(height: 16),
              const Text(
                'Diet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _filterChip('Vegetarian'),
                  _filterChip('Vegan'),
                  _filterChip('Gluten-Free'),
                  _filterChip('Keto'),
                  _filterChip('Paleo'),
                ],
              ),
              
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Theme.of(context).primaryColor),
                      ),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _filterChip(String label) {
    return FilterChip(
      label: Text(label),
      selected: false,
      onSelected: (selected) {},
    );
  }
}