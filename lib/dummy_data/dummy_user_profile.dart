import '../models/user_profile.dart';

final UserProfile dummyUserProfile = UserProfile(
  name: 'Alex Johnson',
  email: 'alex@example.com',
  avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?ixlib=rb-1.2.1&auto=format&fit=crop&w=256&q=80',
  favoriteRecipes: ['1', '3', '5', '7', '9', '11', '12'],
  recentSearches: [
    'chicken pasta',
    'quick lunch',
    'vegetarian',
    'smoothie',
    'desserts',
    'pasta recipes',
    'healthy breakfast'
  ],
  dietaryPreferences: [
    'Reduced Carbs',
    'High Protein',
    'Pescatarian'
  ],
  allergies: [
    'Peanuts',
    'Shellfish'
  ],
  cookingSkillLevel: 'intermediate',
  measurementUnit: 'imperial',
  healthGoals: [
    'Lose Weight',
    'Build Muscle',
    'More Energy'
  ],
  maxPrepTimeMinutes: 45,
  hasCompletedOnboarding: true,
);