class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final List<String> favoriteRecipeIds;
  final List<String> recentSearches;
  final List<String> dietaryPreferences;
  final List<String> cookingSkills;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.favoriteRecipeIds = const [],
    this.recentSearches = const [],
    this.dietaryPreferences = const [],
    this.cookingSkills = const [],
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
    List<String>? favoriteRecipeIds,
    List<String>? recentSearches,
    List<String>? dietaryPreferences,
    List<String>? cookingSkills,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      favoriteRecipeIds: favoriteRecipeIds ?? this.favoriteRecipeIds,
      recentSearches: recentSearches ?? this.recentSearches,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      cookingSkills: cookingSkills ?? this.cookingSkills,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      photoUrl: json['photoUrl'],
      favoriteRecipeIds: json['favoriteRecipeIds'] != null 
          ? List<String>.from(json['favoriteRecipeIds']) 
          : [],
      recentSearches: json['recentSearches'] != null 
          ? List<String>.from(json['recentSearches']) 
          : [],
      dietaryPreferences: json['dietaryPreferences'] != null 
          ? List<String>.from(json['dietaryPreferences']) 
          : [],
      cookingSkills: json['cookingSkills'] != null 
          ? List<String>.from(json['cookingSkills']) 
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'favoriteRecipeIds': favoriteRecipeIds,
      'recentSearches': recentSearches,
      'dietaryPreferences': dietaryPreferences,
      'cookingSkills': cookingSkills,
    };
  }

  // Check if a recipe is in favorites
  bool isFavorite(String recipeId) {
    return favoriteRecipeIds.contains(recipeId);
  }
}