class UserProfile {
  final String name;
  final String email;
  final String avatarUrl;
  final List<String> favoriteRecipes;
  final List<String> recentSearches;
  final List<String> dietaryPreferences;
  final List<String> allergies;
  final String cookingSkillLevel;
  final String measurementUnit;
  final List<String> healthGoals; // Added health goals
  final int maxPrepTimeMinutes; // Added max preparation time
  final bool hasCompletedOnboarding; // Flag to track if onboarding is complete

  const UserProfile({
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.favoriteRecipes,
    required this.recentSearches,
    required this.dietaryPreferences,
    required this.allergies,
    required this.cookingSkillLevel,
    required this.measurementUnit,
    required this.healthGoals,
    required this.maxPrepTimeMinutes,
    required this.hasCompletedOnboarding,
  });

  // Create an empty profile
  factory UserProfile.empty() {
    return const UserProfile(
      name: '',
      email: '',
      avatarUrl: '',
      favoriteRecipes: [],
      recentSearches: [],
      dietaryPreferences: [],
      allergies: [],
      cookingSkillLevel: 'beginner',
      measurementUnit: 'metric',
      healthGoals: [],
      maxPrepTimeMinutes: 60, // Default to 60 minutes
      hasCompletedOnboarding: false,
    );
  }

  // Create a user profile from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      favoriteRecipes: List<String>.from(json['favoriteRecipes'] ?? []),
      recentSearches: List<String>.from(json['recentSearches'] ?? []),
      dietaryPreferences: List<String>.from(json['dietaryPreferences'] ?? []),
      allergies: List<String>.from(json['allergies'] ?? []),
      cookingSkillLevel: json['cookingSkillLevel'] as String? ?? 'beginner',
      measurementUnit: json['measurementUnit'] as String? ?? 'metric',
      healthGoals: List<String>.from(json['healthGoals'] ?? []),
      maxPrepTimeMinutes: json['maxPrepTimeMinutes'] as int? ?? 60,
      hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool? ?? false,
    );
  }

  // Convert user profile to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'favoriteRecipes': favoriteRecipes,
      'recentSearches': recentSearches,
      'dietaryPreferences': dietaryPreferences,
      'allergies': allergies,
      'cookingSkillLevel': cookingSkillLevel,
      'measurementUnit': measurementUnit,
      'healthGoals': healthGoals,
      'maxPrepTimeMinutes': maxPrepTimeMinutes,
      'hasCompletedOnboarding': hasCompletedOnboarding,
    };
  }

  // Create a copy of this user profile with some fields replaced
  UserProfile copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    List<String>? favoriteRecipes,
    List<String>? recentSearches,
    List<String>? dietaryPreferences,
    List<String>? allergies,
    String? cookingSkillLevel,
    String? measurementUnit,
    List<String>? healthGoals,
    int? maxPrepTimeMinutes,
    bool? hasCompletedOnboarding,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      favoriteRecipes: favoriteRecipes ?? this.favoriteRecipes,
      recentSearches: recentSearches ?? this.recentSearches,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      allergies: allergies ?? this.allergies,
      cookingSkillLevel: cookingSkillLevel ?? this.cookingSkillLevel,
      measurementUnit: measurementUnit ?? this.measurementUnit,
      healthGoals: healthGoals ?? this.healthGoals,
      maxPrepTimeMinutes: maxPrepTimeMinutes ?? this.maxPrepTimeMinutes,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}
