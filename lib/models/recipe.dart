class Recipe {
  final String id;
  final String title;
  final String description;
  final List<String> ingredients;
  final List<String> instructions;
  final String? imageUrl;
  final String? aiTips;
  final double rating;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final String difficulty;
  final List<String> categories;
  final String chefName;
  final bool isFavorite;
  final double calories;
  final int servings;

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.instructions,
    this.imageUrl,
    this.aiTips,
    this.rating = 0.0,
    this.prepTimeMinutes = 0,
    this.cookTimeMinutes = 0,
    this.difficulty = 'Medium',
    this.categories = const [],
    this.chefName = '',
    this.isFavorite = false,
    this.calories = 0,
    this.servings = 1,
  });

  Recipe copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    String? imageUrl,
    String? aiTips,
    double? rating,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    String? difficulty,
    List<String>? categories,
    String? chefName,
    bool? isFavorite,
    double? calories,
    int? servings,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      imageUrl: imageUrl ?? this.imageUrl,
      aiTips: aiTips ?? this.aiTips,
      rating: rating ?? this.rating,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      difficulty: difficulty ?? this.difficulty,
      categories: categories ?? this.categories,
      chefName: chefName ?? this.chefName,
      isFavorite: isFavorite ?? this.isFavorite,
      calories: calories ?? this.calories,
      servings: servings ?? this.servings,
    );
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      ingredients: List<String>.from(json['ingredients']),
      instructions: List<String>.from(json['instructions']),
      imageUrl: json['imageUrl'],
      aiTips: json['aiTips'],
      rating: json['rating'] ?? 0.0,
      prepTimeMinutes: json['prepTimeMinutes'] ?? 0,
      cookTimeMinutes: json['cookTimeMinutes'] ?? 0,
      difficulty: json['difficulty'] ?? 'Medium',
      categories: json['categories'] != null 
          ? List<String>.from(json['categories']) 
          : [],
      chefName: json['chefName'] ?? '',
      isFavorite: json['isFavorite'] ?? false,
      calories: json['calories'] ?? 0,
      servings: json['servings'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'instructions': instructions,
      'imageUrl': imageUrl,
      'aiTips': aiTips,
      'rating': rating,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'difficulty': difficulty,
      'categories': categories,
      'chefName': chefName,
      'isFavorite': isFavorite,
      'calories': calories,
      'servings': servings,
    };
  }
  
  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;
}