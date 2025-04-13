import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';

class RecipeCard extends ConsumerWidget {
  final Recipe recipe;
  final bool isHorizontal;
  final bool isExploreView;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.isHorizontal = false,
    this.isExploreView = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        context.pushNamed(
          'recipe-details',
          pathParameters: {'id': recipe.id},
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: isHorizontal
            ? _buildHorizontalCard(context)
            : _buildVerticalCard(context),
      ),
    );
  }

  Widget _buildVerticalCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recipe image
        Stack(
          children: [
            AspectRatio(
              aspectRatio: isExploreView ? 1.5 : 1.2,
              child: Hero(
                tag: 'recipe-image-${recipe.id}',
                child: CachedNetworkImage(
                  imageUrl: recipe.imageUrl ??
                      'https://images.unsplash.com/photo-1495521821757-a1efb6729352?auto=format&fit=crop&w=800&q=80',
                  fit: BoxFit.cover,
                  maxWidthDiskCache: 800,
                  memCacheWidth: 800,
                  fadeInDuration: const Duration(milliseconds: 300),
                  httpHeaders: recipe.imageUrl?.contains(
                              'stfunc602d62e0.blob.core.windows.net') ==
                          true
                      ? {
                          'Cache-Control': 'max-age=31536000'
                        } // Cache for 1 year
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
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Image not available',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Favorite button
            Positioned(
              top: 8,
              right: 8,
              child: _buildFavoriteButton(context),
            ),

            // Time indicator
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${recipe.totalTimeMinutes} min',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Recipe info
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),

              // Chef and rating
              Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      recipe.chefName.substring(0, 1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      recipe.chefName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    recipe.rating.toString(),
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalCard(BuildContext context) {
    return Row(
      children: [
        // Recipe image
        SizedBox(
          width: 120,
          height: 120,
          child: Hero(
            tag: 'recipe-image-${recipe.id}',
            child: CachedNetworkImage(
              imageUrl: recipe.imageUrl ??
                  'https://images.unsplash.com/photo-1495521821757-a1efb6729352?auto=format&fit=crop&w=800&q=80',
              fit: BoxFit.cover,
              maxWidthDiskCache: 800,
              memCacheWidth: 800,
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
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Image not available',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // Recipe info
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Text(
                  recipe.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Chef and time
                Row(
                  children: [
                    Text(
                      'By ${recipe.chefName}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.access_time,
                      color: Colors.grey.shade700,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${recipe.totalTimeMinutes} min',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Rating and difficulty
                Row(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          recipe.rating.toString(),
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        recipe.difficulty,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildFavoriteButton(context),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteButton(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        return InkWell(
          onTap: () {
            ref.read(recipeProvider.notifier).toggleFavorite(recipe.id);
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: recipe.isFavorite ? Colors.red : Colors.grey,
              size: 18,
            ),
          ),
        );
      },
    );
  }
}
