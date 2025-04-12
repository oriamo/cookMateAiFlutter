import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/recipe_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/category_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/settings/preferences_onboarding_screen.dart';
import '../widgets/app_scaffold.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // Check if user needs to complete onboarding
    final container = ProviderScope.containerOf(context);
    final userProfileNotifier = container.read(userProfileProvider.notifier);

    // Skip onboarding if already completed or if we're already on the onboarding screen
    if (!userProfileNotifier.shouldShowOnboarding() ||
        state.matchedLocation == '/onboarding') {
      return null;
    }

    // Redirect to onboarding
    return '/onboarding';
  },
  routes: [
    // Onboarding route (outside the shell)
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const PreferencesOnboardingScreen(),
    ),

    ShellRoute(
      builder: (context, state, child) {
        return AppScaffold(child: child);
      },
      routes: [
        // Home route
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),

        // Search route
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (context, state) => const SearchScreen(),
        ),

        // Recipe details route
        GoRoute(
          path: '/recipe/:id',
          name: 'recipe-details',
          builder: (context, state) {
            final recipeId = state.pathParameters['id'] ?? '';
            return RecipeScreen(recipeId: recipeId);
          },
        ),

        // Category route
        GoRoute(
          path: '/category/:id',
          name: 'category',
          builder: (context, state) {
            final categoryId = state.pathParameters['id'] ?? '';
            final categoryName =
                state.uri.queryParameters['name'] ?? 'Category';
            return CategoryScreen(
              categoryId: categoryId,
              categoryName: categoryName,
            );
          },
        ),

        // Favorites route
        GoRoute(
          path: '/favorites',
          name: 'favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),

        // Profile route
        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) => const ProfileScreen(),
        ),

        // Explore route
        GoRoute(
          path: '/explore',
          name: 'explore',
          builder: (context, state) => const ExploreScreen(),
        ),

        // AI Chat route
        GoRoute(
          path: '/ai-chat',
          name: 'ai-chat',
          builder: (context, state) => const AIChatScreen(),
        ),
      ],
    ),
  ],
);
