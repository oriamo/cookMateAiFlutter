import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/recipe_provider.dart';
import '../providers/user_provider.dart';
import '../models/recipe.dart';
import 'package:flutter/rendering.dart';
import '../dummy_data/dummy_recipes.dart';

class RecipeScreen extends ConsumerStatefulWidget {
  final String recipeId;

  const RecipeScreen({super.key, required this.recipeId});

  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  int _currentTab = 0;
  final ScrollController _scrollController = ScrollController();
  bool _showFab = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showFab = _scrollController.position.userScrollDirection ==
        ScrollDirection.forward;
    if (showFab != _showFab) {
      setState(() {
        _showFab = showFab;
      });
    }
  }

  void _toggleFavorite(Recipe recipe) {
    // DEMO MODE: Don't actually update favorites
    // ref.read(recipeProvider.notifier).toggleFavorite(recipe.id);
    // ref.read(userProfileProvider.notifier).toggleFavoriteRecipe(recipe.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          recipe.isFavorite
              ? '[DEMO] ${recipe.title} would be removed from favorites'
              : '[DEMO] ${recipe.title} would be added to favorites',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'DEMO INFO',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Demo Mode'),
                content: const Text(
                    'This is a demo. In a real app, favorite recipes would be saved to your profile.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _shareRecipe(Recipe recipe) {
    Share.share(
      'Check out this amazing recipe for ${recipe.title}! '
      '${recipe.description}\n\n'
      'Cooking time: ${recipe.totalTimeMinutes} minutes, '
      'Difficulty: ${recipe.difficulty}',
    );
  }

  // DEMO MODE: Direct recipe provider to use dummy data
  final dummyRecipeProvider = Provider.family<Recipe?, String>((ref, id) {
    try {
      return dummyRecipes.firstWhere((recipe) => recipe.id == id);
    } catch (e) {
      return null;
    }
  });

  @override
  Widget build(BuildContext context) {
    // DEMO MODE: Use dummy data directly
    final recipe = ref.watch(dummyRecipeProvider(widget.recipeId));
    
    // Fallback to the normal provider if needed
    final recipeAsync = recipe ?? ref.watch(recipeDetailProvider(widget.recipeId));

    return Scaffold(
      body: recipeAsync == null
          ? const Center(child: Text('Recipe not found'))
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                // App Bar
                _buildAppBar(context, recipeAsync),

                // Recipe Content
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Recipe header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title and description
                            FadeInUp(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                recipeAsync.title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FadeInUp(
                              duration: const Duration(milliseconds: 400),
                              child: Text(
                                recipeAsync.description,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Recipe info cards
                            FadeInUp(
                              duration: const Duration(milliseconds: 500),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildInfoCard(
                                    context,
                                    Icons.timer_outlined,
                                    '${recipeAsync.totalTimeMinutes} min',
                                    'Total Time',
                                  ),
                                  _buildInfoCard(
                                    context,
                                    Icons.restaurant_outlined,
                                    recipeAsync.difficulty,
                                    'Difficulty',
                                  ),
                                  _buildInfoCard(
                                    context,
                                    Icons.person_outline,
                                    '${recipeAsync.servings}',
                                    'Servings',
                                  ),
                                  _buildInfoCard(
                                    context,
                                    Icons.local_fire_department_outlined,
                                    '${recipeAsync.calories}',
                                    'Calories',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Chef info
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                child: Text(
                                  recipeAsync.chefName.substring(0, 1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recipe by',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    recipeAsync.chefName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    recipeAsync.rating.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Tabs
                      FadeInUp(
                        duration: const Duration(milliseconds: 700),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildTabButton(
                                  'Ingredients',
                                  0,
                                  recipeAsync.ingredients.length,
                                ),
                                _buildTabButton(
                                  'Instructions',
                                  1,
                                  recipeAsync.instructions.length,
                                ),
                                _buildTabButton(
                                  'AI Tips',
                                  2,
                                  1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Tab content
                      FadeInUp(
                        duration: const Duration(milliseconds: 800),
                        child: [
                          _buildIngredientsTab(recipeAsync),
                          _buildInstructionsTab(recipeAsync),
                          _buildAITipsTab(recipeAsync),
                        ][_currentTab],
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: recipeAsync != null && _showFab
          ? FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: FloatingActionButton.extended(
                onPressed: () {},
                icon: const Icon(Icons.lunch_dining),
                label: const Text('Start Cooking'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            )
          : null,
    );
  }

  Widget _buildAppBar(BuildContext context, Recipe recipe) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Recipe image
            CachedNetworkImage(
              imageUrl: recipe.imageUrl ??
                  'https://images.unsplash.com/photo-1495521821757-a1efb6729352?auto=format&fit=crop&w=800&q=80',
              fit: BoxFit.cover,
              maxWidthDiskCache: 1200, // Larger cache for detail view
              memCacheWidth: 1200,
              fadeInDuration: const Duration(milliseconds: 300),
              httpHeaders: recipe.imageUrl
                          ?.contains('stfunc602d62e0.blob.core.windows.net') ==
                      true
                  ? {'Cache-Control': 'max-age=31536000'} // Cache for 1 year
                  : null,
              placeholder: (context, url) => Container(
                color: Colors.grey.shade100,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
              errorWidget: (context, url, error) {
                print('Image load error for $url: $error');
                return Container(
                  color: Colors.grey.shade100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant,
                        color: Colors.grey.shade400,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Image not available',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      leading: CircleAvatar(
        backgroundColor: Colors.black.withOpacity(0.4),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.4),
          child: IconButton(
            icon: Icon(
              recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: recipe.isFavorite ? Colors.red : Colors.white,
            ),
            onPressed: () => _toggleFavorite(recipe),
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.4),
          child: IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => _shareRecipe(recipe),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildInfoCard(
      BuildContext context, IconData icon, String value, String label) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int tabIndex, int count) {
    final isSelected = _currentTab == tabIndex;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTab = tabIndex;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsTab(Recipe recipe) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Serving adjustment
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.people_alt_outlined, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Text(
                  'Servings: ${recipe.servings}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '4',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ingredients list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recipe.ingredients.length,
            itemBuilder: (context, index) {
              final ingredient = recipe.ingredients[index];
              final name = ingredient['name'] as String? ?? '';
              final amount = ingredient['amount'] as String? ?? '';
              final unit = ingredient['unit'] as String? ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Text(
                          [amount, unit].where((e) => e.isNotEmpty).join(' '),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsTab(Recipe recipe) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recipe.instructions.length,
        itemBuilder: (context, index) {
          final step = recipe.instructions[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: step.imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        step.description,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAITipsTab(Recipe recipe) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tips_and_updates,
                    color: Colors.purple.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'AI Chef Tips',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              recipe.aiTips ?? 'No AI tips available for this recipe yet.',
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Ask AI Chef'),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
