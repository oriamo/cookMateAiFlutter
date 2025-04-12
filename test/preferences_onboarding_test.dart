import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cook_mate_ai/models/user_profile.dart';
import 'package:cook_mate_ai/providers/user_provider.dart';
import 'package:cook_mate_ai/screens/settings/preferences_onboarding_screen.dart';

class MockUserProfileNotifier extends StateNotifier<UserProfile>
    implements UserProfileNotifier {
  MockUserProfileNotifier() : super(UserProfile.empty());

  bool _hasCompletedOnboarding = false;

  @override
  Future<void> completeOnboarding() async {
    _hasCompletedOnboarding = true;
  }

  @override
  bool shouldShowOnboarding() {
    return !_hasCompletedOnboarding;
  }

  @override
  Future<void> updateHealthGoals(List<String> healthGoals) async {}

  @override
  Future<void> updateMaxPrepTime(int minutes) async {}

  @override
  Future<void> updateMeasurementUnit(String unit) async {}

  // Add the missing methods that were flagged in the error
  @override
  Future<void> addFavoriteRecipe(String recipeId) async {}

  @override
  Future<void> addRecentSearch(String query) async {}

  @override
  Future<void> clearRecentSearches() async {}

  @override
  bool isFavoriteRecipe(String recipeId) => false;

  @override
  Future<void> logout() async {}

  @override
  Future<void> removeFavoriteRecipe(String recipeId) async {}

  @override
  Future<void> toggleFavoriteRecipe(String recipeId) async {}

  @override
  Future<void> updateProfile({
    String? name,
    String? email,
    String? avatarUrl,
    List<String>? dietaryPreferences,
    List<String>? allergies,
    String? cookingSkillLevel,
    List<String>? healthGoals,
    int? maxPrepTimeMinutes,
    bool? hasCompletedOnboarding,
  }) async {}
}

final mockUserProfileProvider =
    StateNotifierProvider<MockUserProfileNotifier, UserProfile>((ref) {
  return MockUserProfileNotifier();
});

void main() {
  testWidgets('Onboarding shows progress indicator',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWithProvider(mockUserProfileProvider),
        ],
        child: const MaterialApp(
          home: PreferencesOnboardingScreen(),
        ),
      ),
    );

    // Progress indicator should be visible
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // Should show "Step 1 of 5"
    expect(find.text('Step 1 of 5'), findsOneWidget);
  });
}
