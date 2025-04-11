class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final List<String> favoriteRecipes;
  final List<String> recentSearches;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    List<String>? favoriteRecipes,
    List<String>? recentSearches,
  }) : 
    favoriteRecipes = favoriteRecipes ?? [],
    recentSearches = recentSearches ?? [];

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    List<String>? favoriteRecipes,
    List<String>? recentSearches,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      favoriteRecipes: favoriteRecipes ?? this.favoriteRecipes,
      recentSearches: recentSearches ?? this.recentSearches,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatarUrl: json['avatarUrl'],
      favoriteRecipes: List<String>.from(json['favoriteRecipes'] ?? []),
      recentSearches: List<String>.from(json['recentSearches'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'favoriteRecipes': favoriteRecipes,
      'recentSearches': recentSearches,
    };
  }
}