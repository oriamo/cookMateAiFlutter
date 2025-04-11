# CookMate AI: Flutter Development Guide

This document explains the development process of CookMate AI, a Flutter application that helps users cook with AI assistance. It covers important Flutter concepts, state management with Riverpod, and navigation using GoRouter.

## 1. Project Setup and Dependencies

### Understanding the pubspec.yaml

The pubspec.yaml file is the heart of any Flutter project. It defines:
- Project metadata (name, description, version)
- Dependencies (external packages)
- Asset configurations

Key dependencies we added:
- `flutter_riverpod` - For state management
- `go_router` - For navigation
- `http` - For network requests (future AI integration)
- `shared_preferences` - For local storage

```yaml
# Core packages
cupertino_icons: ^1.0.8
flutter_riverpod: ^2.4.10
go_router: ^13.2.0
http: ^1.2.1
shared_preferences: ^2.2.2
```

## 2. Project Structure

A well-organized project structure is crucial for maintainability:

```
lib/
  ├── main.dart            # Entry point
  ├── models/              # Data models
  │   └── recipe.dart
  ├── providers/           # Riverpod state management
  │   └── recipe_provider.dart
  ├── router/              # Navigation configuration
  │   └── router.dart
  ├── screens/             # UI screens
  │   ├── home_screen.dart
  │   ├── recipe_screen.dart
  │   └── search_screen.dart
  ├── services/            # API and business logic (future use)
  └── widgets/             # Reusable UI components
```

This separation of concerns makes the codebase easier to navigate and maintain.

## 3. Data Modeling with Dart Classes

### Recipe Model (models/recipe.dart)

Data models represent the structure of your application's data. The Recipe class:
- Defines properties with appropriate types
- Uses named parameters for clarity
- Implements JSON serialization for API integration

```dart
class Recipe {
  final String id;
  final String title;
  // Other properties...

  Recipe({
    required this.id,
    required this.title,
    // Other required fields...
    this.imageUrl,  // Optional fields don't use 'required'
  });

  // JSON conversion methods
  factory Recipe.fromJson(Map<String, dynamic> json) { /* ... */ }
  Map<String, dynamic> toJson() { /* ... */ }
}
```

**Learning Point:** Use `required` for mandatory fields and make optional fields nullable with `?`.

## 4. State Management with Riverpod

### Recipe Provider (providers/recipe_provider.dart)

Riverpod is a powerful state management solution:

1. **StateNotifier** - Manages mutable state:
```dart
class RecipeNotifier extends StateNotifier<List<Recipe>> {
  RecipeNotifier() : super(sampleRecipes);  // Initial state

  // Methods to modify state
  void addRecipe(Recipe recipe) {
    state = [...state, recipe];  // Create new state, don't modify existing
  }
  
  // Methods to query state
  Recipe? getRecipeById(String id) { /* ... */ }
}
```

2. **Providers** - Make state available to the UI:
```dart
// Main provider for recipe list
final recipeProvider = StateNotifierProvider<RecipeNotifier, List<Recipe>>((ref) {
  return RecipeNotifier();
});

// Derived provider for a single recipe
final recipeDetailProvider = Provider.family<Recipe?, String>((ref, id) {
  final recipeNotifier = ref.watch(recipeProvider.notifier);
  return recipeNotifier.getRecipeById(id);
});
```

**Learning Point:** `Provider.family` allows passing parameters to providers.

## 5. Navigation with GoRouter

### Router Configuration (router/router.dart)

GoRouter provides declarative routing:

```dart
final router = GoRouter(
  initialLocation: '/',  // Starting route
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/recipe/:id',  // Dynamic path parameter
      builder: (context, state) {
        final recipeId = state.pathParameters['id'] ?? '';
        return RecipeScreen(recipeId: recipeId);
      },
    ),
    // Other routes...
  ],
);
```

**Learning Point:** Path parameters (`:id`) allow passing data through the URL.

## 6. UI Layer - Screens

### Home Screen (screens/home_screen.dart)

```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CookMate AI')),
      body: Center(
        child: Column(
          // UI elements...
          ElevatedButton(
            onPressed: () => context.go('/search'),  // Navigation
            child: const Text('Find Recipes'),
          ),
        ),
      ),
    );
  }
}
```

**Learning Point:** Use `context.go('/path')` for navigation with GoRouter.

### Consumer Widgets with Riverpod

```dart
// Consumer allows watching state
class SearchScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  @override
  Widget build(BuildContext context) {
    // Access providers with ref.watch()
    final searchResults = ref.watch(searchResultsProvider(query));
    
    return Scaffold(
      // UI elements...
    );
  }
}
```

**Learning Point:** `ConsumerWidget` and `ConsumerStatefulWidget` provide access to Riverpod state.

## 7. Integration in main.dart

```dart
void main() {
  runApp(
    const ProviderScope(  // Enables Riverpod throughout the app
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(  // Uses GoRouter for navigation
      title: 'CookMate AI',
      theme: ThemeData(/* ... */),
      routerConfig: router,
    );
  }
}
```

**Learning Points:**
- Wrap your app in `ProviderScope` to enable Riverpod
- Use `MaterialApp.router` with GoRouter

## 8. Future Enhancements

This project establishes the foundation for:
1. AI Integration - Connect to an AI service for recipe suggestions
2. User Favorites - Allow saving preferred recipes
3. Shopping Lists - Generate based on recipe ingredients
4. Advanced Filtering - Search by dietary restrictions
5. Meal Planning - Schedule meals for the week

## 9. Best Practices Demonstrated

1. **Separation of Concerns** - Logic, UI, and data are separated
2. **Immutable State** - State is never directly modified
3. **Declarative UI** - The UI reflects the application state
4. **Clean Architecture** - Organized code structure
5. **Type Safety** - Proper use of Dart's type system

## Conclusion

Flutter enables building sophisticated cross-platform applications with clean architecture and excellent performance. This project demonstrates core concepts that can be applied to any Flutter application.