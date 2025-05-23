import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animations/animations.dart';
import '../providers/recipe_provider.dart';
import '../providers/user_provider.dart';
import '../models/recipe.dart';
import '../screens/recipe_screen.dart';

// Define the searchRecipesProvider that accepts a search query parameter
final searchRecipesProvider =
    Provider.family<AsyncValue<List<Recipe>>, String>((ref, query) {
  final allRecipes = ref.watch(recipeProvider);

  return allRecipes.when(
    data: (data) {
      final recipes = (data['recipes'] as List<dynamic>).cast<Recipe>();
      if (query.isEmpty) return AsyncValue.data(recipes);

      final filteredRecipes = recipes.where((recipe) {
        final lowerCaseQuery = query.toLowerCase();
        return recipe.title.toLowerCase().contains(lowerCaseQuery) ||
            recipe.description.toLowerCase().contains(lowerCaseQuery) ||
            recipe.ingredients.any((ingredient) =>
                ingredient.toString().toLowerCase().contains(lowerCaseQuery));
      }).toList();

      return AsyncValue.data(filteredRecipes);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late FocusNode _focusNode;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _query = widget.initialQuery!;
    }

    // Request focus after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_query.isEmpty) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    setState(() {
      _query = query.trim();
    });

    if (_query.isNotEmpty) {
      ref.read(userProfileProvider.notifier).addRecentSearch(_query);
    }
  }

  List<Recipe> _filterRecipes(
      AsyncValue<Map<String, dynamic>> recipesData, String query) {
    return recipesData.when(
      data: (data) {
        final recipes = (data['recipes'] as List<dynamic>).cast<Recipe>();
        if (query.isEmpty) return recipes;

        return recipes.where((recipe) {
          return recipe.title.toLowerCase().contains(query.toLowerCase()) ||
              recipe.description.toLowerCase().contains(query.toLowerCase());
        }).toList();
      },
      loading: () => [],
      error: (_, __) => [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchResultsAsync = _query.isNotEmpty
        ? ref.watch(searchRecipesProvider(_query))
        : AsyncValue.data(<Recipe>[]);

    final recentSearches = ref.watch(userProfileProvider).recentSearches;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Search for recipes, ingredients...',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          style: const TextStyle(color: Colors.white),
          onSubmitted: _performSearch,
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                });
                _focusNode.requestFocus();
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _performSearch(_searchController.text);
            },
          ),
        ],
      ),
      body: _query.isEmpty
          ? _buildRecentSearches(recentSearches)
          : searchResultsAsync.when(
              data: (searchResults) => _buildSearchResults(searchResults),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(
                  'Error loading search results: $error',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
    );
  }

  Widget _buildRecentSearches(List<String> recentSearches) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Searches',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (recentSearches.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          ref
                              .read(userProfileProvider.notifier)
                              .clearRecentSearches();
                        },
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (recentSearches.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No recent searches',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: recentSearches.map((search) {
                      return ActionChip(
                        avatar: const Icon(Icons.history, size: 16),
                        label: Text(search),
                        onPressed: () {
                          _searchController.text = search;
                          _performSearch(search);
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Popular Search Categories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSearchCategoryChip('Vegetarian', Icons.eco),
                    _buildSearchCategoryChip('Quick Meals', Icons.timer),
                    _buildSearchCategoryChip('Italian', Icons.local_pizza),
                    _buildSearchCategoryChip('Breakfast', Icons.free_breakfast),
                    _buildSearchCategoryChip('Desserts', Icons.cake),
                    _buildSearchCategoryChip('Healthy', Icons.fitness_center),
                    _buildSearchCategoryChip('Asian', Icons.ramen_dining),
                    _buildSearchCategoryChip(
                        'Budget-Friendly', Icons.attach_money),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Search tips
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Search Tips',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You can search by ingredients, cuisine type, or dish name. Try something like "chicken pasta" or "vegetarian dinner".',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchCategoryChip(String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: () {
        _searchController.text = label;
        _performSearch(label);
      },
    );
  }

  Widget _buildSearchResults(List<Recipe> searchResults) {
    if (searchResults.isEmpty) {
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
              'No results found for "$_query"',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final recipe = searchResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OpenContainer(
            transitionType: ContainerTransitionType.fadeThrough,
            openBuilder: (context, _) => RecipeScreen(recipeId: recipe.id),
            closedElevation: 0,
            closedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            closedColor: Theme.of(context).colorScheme.surface,
            closedBuilder: (context, openContainer) => ListTile(
              onTap: openContainer,
              contentPadding: const EdgeInsets.all(12),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  recipe.imageUrl ?? 'https://via.placeholder.com/100',
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(
                recipe.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    recipe.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey.shade400),
            ),
          ),
        );
      },
    );
  }
}
