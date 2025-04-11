import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';

// Sample user profile for initial state
final sampleUserProfile = UserProfile(
  id: 'user-1',
  name: 'Alex Johnson',
  email: 'alex.johnson@example.com',
  photoUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?ixlib=rb-1.2.1&auto=format&fit=crop&w=500&q=60',
  favoriteRecipeIds: ['recipe-2', 'recipe-5'],
  recentSearches: ['pasta', 'vegetarian', 'quick dinner'],
  dietaryPreferences: ['Vegetarian-friendly', 'Low carb'],
  cookingSkills: ['Intermediate'],
);

// State notifier to manage the user profile
class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier() : super(sampleUserProfile);

  void updateProfile({
    String? name,
    String? email,
    String? photoUrl,
  }) {
    state = state.copyWith(
      name: name,
      email: email,
      photoUrl: photoUrl,
    );
  }

  void toggleFavoriteRecipe(String recipeId) {
    final isFavorite = state.favoriteRecipeIds.contains(recipeId);
    List<String> updatedFavorites;
    
    if (isFavorite) {
      updatedFavorites = state.favoriteRecipeIds.where((id) => id != recipeId).toList();
    } else {
      updatedFavorites = [...state.favoriteRecipeIds, recipeId];
    }
    
    state = state.copyWith(favoriteRecipeIds: updatedFavorites);
  }

  void addRecentSearch(String query) {
    if (query.isEmpty) return;
    
    // Remove it if it exists already to avoid duplicates
    final filtered = state.recentSearches.where((search) => search != query).toList();
    
    // Add to the beginning and limit to 10 recent searches
    final updated = [query, ...filtered].take(10).toList();
    
    state = state.copyWith(recentSearches: updated);
  }

  void clearRecentSearches() {
    state = state.copyWith(recentSearches: []);
  }
  
  void updateDietaryPreferences(List<String> preferences) {
    state = state.copyWith(dietaryPreferences: preferences);
  }
  
  void updateCookingSkills(List<String> skills) {
    state = state.copyWith(cookingSkills: skills);
  }
}

// User profile provider
final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier();
});

// Favorite recipe IDs provider
final favoriteRecipeIdsProvider = Provider<List<String>>((ref) {
  final userProfile = ref.watch(userProfileProvider);
  return userProfile.favoriteRecipeIds;
});

// Recent searches provider
final recentSearchesProvider = Provider<List<String>>((ref) {
  final userProfile = ref.watch(userProfileProvider);
  return userProfile.recentSearches;
});

// Dietary preferences provider
final dietaryPreferencesProvider = Provider<List<String>>((ref) {
  final userProfile = ref.watch(userProfileProvider);
  return userProfile.dietaryPreferences;
});

// Cooking skills provider
final cookingSkillsProvider = Provider<List<String>>((ref) {
  final userProfile = ref.watch(userProfileProvider);
  return userProfile.cookingSkills;
});