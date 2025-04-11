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

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

// Router configuration
final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppScaffold(child: child),
      routes: [
        // Home Tab
        GoRoute(
          path: '/',
          name: 'home',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const HomeScreen(),
          ),
          routes: [
            GoRoute(
              path: 'recipe/:id',
              name: 'recipe-details',
              pageBuilder: (context, state) {
                final recipeId = state.pathParameters['id'] ?? '';
                return CustomTransitionPage(
                  child: RecipeScreen(recipeId: recipeId),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                );
              },
            ),
            GoRoute(
              path: 'category/:id',
              name: 'category',
              pageBuilder: (context, state) {
                final categoryId = state.pathParameters['id'] ?? '';
                final categoryName = state.uri.queryParameters['name'] ?? 'Category';
                return CustomTransitionPage(
                  child: CategoryScreen(categoryId: categoryId, categoryName: categoryName),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                );
              },
            ),
          ],
        ),
        
        // Explore Tab
        GoRoute(
          path: '/explore',
          name: 'explore',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const ExploreScreen(),
          ),
        ),
        
        // Search Tab
        GoRoute(
          path: '/search',
          name: 'search',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SearchScreen(),
          ),
        ),
        
        // AI Chat Tab
        GoRoute(
          path: '/ai-chat',
          name: 'ai-chat',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AIChatScreen(),
          ),
        ),
        
        // Profile Tab
        GoRoute(
          path: '/profile',
          name: 'profile',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileScreen(),
          ),
        ),
        
        // Favorites Route
        GoRoute(
          path: '/favorites',
          name: 'favorites',
          pageBuilder: (context, state) => const CustomTransitionPage(
            child: FavoritesScreen(),
            transitionsBuilder: _slideUpTransition,
          ),
        ),
      ],
    ),
  ],
);

// Common transition builder for slide-up effect
Widget _slideUpTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(animation),
    child: child,
  );
}