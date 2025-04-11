class Recipe {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final int totalTimeMinutes;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final String difficulty;
  final int servings;
  final int calories;
  final String chefName;
  final double rating;
  final int reviewCount;
  final List<String> ingredients;
  final List<String> instructions;
  final List<String> tags;
  final String? aiTips;
  final DateTime createdAt;
  final String categoryId;
  final String cuisineType;
  final bool isFavorite;

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.totalTimeMinutes,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.difficulty,
    required this.servings,
    required this.calories,
    required this.chefName,
    required this.rating,
    required this.reviewCount,
    required this.ingredients,
    required this.instructions,
    required this.tags,
    this.aiTips,
    required this.createdAt,
    required this.categoryId,
    required this.cuisineType,
    this.isFavorite = false,
  });

  Recipe copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    int? totalTimeMinutes,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    String? difficulty,
    int? servings,
    int? calories,
    String? chefName,
    double? rating,
    int? reviewCount,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? tags,
    String? aiTips,
    DateTime? createdAt,
    String? categoryId,
    String? cuisineType,
    bool? isFavorite,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      totalTimeMinutes: totalTimeMinutes ?? this.totalTimeMinutes,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      difficulty: difficulty ?? this.difficulty,
      servings: servings ?? this.servings,
      calories: calories ?? this.calories,
      chefName: chefName ?? this.chefName,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      tags: tags ?? this.tags,
      aiTips: aiTips ?? this.aiTips,
      createdAt: createdAt ?? this.createdAt,
      categoryId: categoryId ?? this.categoryId,
      cuisineType: cuisineType ?? this.cuisineType,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      totalTimeMinutes: json['totalTimeMinutes'],
      prepTimeMinutes: json['prepTimeMinutes'],
      cookTimeMinutes: json['cookTimeMinutes'],
      difficulty: json['difficulty'],
      servings: json['servings'],
      calories: json['calories'],
      chefName: json['chefName'],
      rating: json['rating'].toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      ingredients: List<String>.from(json['ingredients']),
      instructions: List<String>.from(json['instructions']),
      tags: List<String>.from(json['tags']),
      aiTips: json['aiTips'],
      createdAt: DateTime.parse(json['createdAt']),
      categoryId: json['categoryId'],
      cuisineType: json['cuisineType'] ?? '',
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'totalTimeMinutes': totalTimeMinutes,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'difficulty': difficulty,
      'servings': servings,
      'calories': calories,
      'chefName': chefName,
      'rating': rating,
      'reviewCount': reviewCount,
      'ingredients': ingredients,
      'instructions': instructions,
      'tags': tags,
      'aiTips': aiTips,
      'createdAt': createdAt.toIso8601String(),
      'categoryId': categoryId,
      'cuisineType': cuisineType,
      'isFavorite': isFavorite,
    };
  }
}