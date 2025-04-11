import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/recipe_screen.dart';
import '../screens/search_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/category_screen.dart';
import '../widgets/app_scaffold.dart';

// Router configuration
final router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return AppScaffold(child: child);
      },
      routes: [
        // Home route
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: [
            // Recipe detail from home
            GoRoute(
              path: 'recipe/:id',
              builder: (context, state) {
                final recipeId = state.pathParameters['id'] ?? '';
                return RecipeScreen(recipeId: recipeId);
              },
            ),
          ],
        ),
        
        // Explore route
        GoRoute(
          path: '/explore',
          builder: (context, state) => const ExploreScreen(),
          routes: [
            // Category detail from explore
            GoRoute(
              path: 'category/:id',
              builder: (context, state) {
                final categoryId = state.pathParameters['id'] ?? '';
                return CategoryScreen(categoryId: categoryId);
              },
            ),
          ],
        ),
        
        // Search route
        GoRoute(
          path: '/search',
          builder: (context, state) {
            final initialQuery = state.extra as String?;
            return SearchScreen(initialQuery: initialQuery);
          },
        ),
        
        // Favorites route
        GoRoute(
          path: '/favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),
        
        // Profile route
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        
        // AI Chat route
        GoRoute(
          path: '/ai-chat',
          builder: (context, state) => const AIChatScreen(),
        ),
      ],
    ),
  ],
);