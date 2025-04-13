import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../dummy_data/dummy_user_profile.dart';

class UserProfileNotifier extends StateNotifier<UserProfile> {
  static const String _storageKey = 'user_profile_data';
  bool _isInitialDataLoaded = false;
  
  UserProfileNotifier() : super(UserProfile.empty()) {
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      // Demo mode: load dummy user if no saved data
      if (!_isInitialDataLoaded) {
        state = dummyUserProfile;
        _isInitialDataLoaded = true;
        
        // Save to SharedPreferences for persistence
        await _saveUserProfile();
      }
      
      // Try to load from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString(_storageKey);

      if (profileJson != null && profileJson.isNotEmpty) {
        final profileData = jsonDecode(profileJson);
        state = UserProfile.fromJson(profileData);
      }
    } catch (e) {
      _logDebug('Error loading user profile: $e');
    }
  }

  Future<void> _saveUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(state.toJson()));
    } catch (e) {
      _logDebug('Error saving user profile: $e');
    }
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? avatarUrl,
    List<String>? dietaryPreferences,
    List<String>? allergies,
    String? cookingSkillLevel,
    List<String>? healthGoals,
    String? measurementUnit,
    int? maxPrepTimeMinutes,
    bool? hasCompletedOnboarding,
  }) async {
    state = state.copyWith(
      name: name,
      email: email,
      avatarUrl: avatarUrl,
      dietaryPreferences: dietaryPreferences,
      allergies: allergies,
      cookingSkillLevel: cookingSkillLevel,
      healthGoals: healthGoals,
      maxPrepTimeMinutes: maxPrepTimeMinutes,
      hasCompletedOnboarding: hasCompletedOnboarding,
    );
    await _saveUserProfile();
  }

  Future<void> addFavoriteRecipe(String recipeId) async {
    if (!state.favoriteRecipes.contains(recipeId)) {
      final newFavorites = List<String>.from(state.favoriteRecipes)
        ..add(recipeId);
      state = state.copyWith(favoriteRecipes: newFavorites);
      await _saveUserProfile();
      _logDebug('Added recipe to favorites: $recipeId');
    }
  }

  Future<void> removeFavoriteRecipe(String recipeId) async {
    if (state.favoriteRecipes.contains(recipeId)) {
      final newFavorites = List<String>.from(state.favoriteRecipes)
        ..remove(recipeId);
      state = state.copyWith(favoriteRecipes: newFavorites);
      await _saveUserProfile();
      _logDebug('Removed recipe from favorites: $recipeId');
    }
  }

  Future<void> toggleFavoriteRecipe(String recipeId) async {
    if (state.favoriteRecipes.contains(recipeId)) {
      await removeFavoriteRecipe(recipeId);
    } else {
      await addFavoriteRecipe(recipeId);
    }
  }

  Future<void> addRecentSearch(String query) async {
    // Prevent duplicates, move to top if exists
    final recentSearches = List<String>.from(state.recentSearches);
    if (recentSearches.contains(query)) {
      recentSearches.remove(query);
    }

    // Add to beginning of list
    recentSearches.insert(0, query);

    // Keep only the latest 10 searches
    final limitedSearches = recentSearches.take(10).toList();

    state = state.copyWith(recentSearches: limitedSearches);
    await _saveUserProfile();
  }

  Future<void> clearRecentSearches() async {
    state = state.copyWith(recentSearches: []);
    await _saveUserProfile();
  }

  bool isFavoriteRecipe(String recipeId) {
    return state.favoriteRecipes.contains(recipeId);
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Clear user profile data
      await prefs.remove(_storageKey);
      // Reset state to empty user
      state = UserProfile.empty();
      _logDebug('User logged out successfully');
    } catch (e) {
      _logDebug('Error during logout: $e');
    }
  }

  Future<void> updateMeasurementUnit(String unit) async {
    state = state.copyWith(
      measurementUnit: unit,
    );
    await _saveUserProfile();
    _logDebug('Measurement unit updated to: $unit');
  }

  Future<void> updateHealthGoals(List<String> healthGoals) async {
    state = state.copyWith(
      healthGoals: healthGoals,
    );
    await _saveUserProfile();
    _logDebug('Health goals updated: $healthGoals');
  }

  Future<void> updateMaxPrepTime(int minutes) async {
    state = state.copyWith(
      maxPrepTimeMinutes: minutes,
    );
    await _saveUserProfile();
    _logDebug('Max preparation time updated to: $minutes minutes');
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(
      hasCompletedOnboarding: true,
    );
    await _saveUserProfile();
    _logDebug('User onboarding completed');
  }

  bool shouldShowOnboarding() {
    // Show onboarding if user hasn't completed it yet
    return !state.hasCompletedOnboarding;
  }

  void _logDebug(String message) {
    // Only log in debug mode
    assert(() {
      print('[UserProfile] $message');
      return true;
    }());
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier();
});