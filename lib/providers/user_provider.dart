import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';

// Sample user data
final _sampleUser = UserProfile(
  id: 'user1',
  name: 'Jane Smith',
  email: 'jane.smith@example.com',
  avatarUrl: 'https://randomuser.me/api/portraits/women/17.jpg',
  favoriteRecipes: ['1', '3'],
  recentSearches: ['pasta', 'vegetarian', 'quick dinner'],
);

class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier() : super(_sampleUser);

  void updateProfile({
    String? name,
    String? email,
    String? avatarUrl,
  }) {
    state = state.copyWith(
      name: name,
      email: email,
      avatarUrl: avatarUrl,
    );
  }

  void toggleFavoriteRecipe(String recipeId) {
    final currentFavorites = [...state.favoriteRecipes];
    if (currentFavorites.contains(recipeId)) {
      currentFavorites.remove(recipeId);
    } else {
      currentFavorites.add(recipeId);
    }
    state = state.copyWith(favoriteRecipes: currentFavorites);
  }

  void addRecentSearch(String query) {
    if (query.isEmpty) return;
    
    final currentSearches = [...state.recentSearches];
    
    // Remove if already exists to move to front
    currentSearches.remove(query);
    
    // Add at beginning
    currentSearches.insert(0, query);
    
    // Keep only last 10 searches
    final limitedSearches = currentSearches.length > 10 
        ? currentSearches.sublist(0, 10) 
        : currentSearches;
    
    state = state.copyWith(recentSearches: limitedSearches);
  }

  void clearRecentSearches() {
    state = state.copyWith(recentSearches: []);
  }
}

// User profile provider
final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier();
});