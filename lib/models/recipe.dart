import 'package:uuid/uuid.dart';
import 'dart:math';

class Recipe {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final List<Map<String, dynamic>> ingredients;
  final List<String> instructions;
  final int totalTimeMinutes;
  final String category;
  final double rating;
  final bool isFavorite;
  final String difficulty;
  final int servings;
  final int? calories;
  final String chefName;
  final String? aiTips;
  final int prepTimeMinutes;

  Recipe({
    String? id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.ingredients,
    required this.instructions,
    required this.totalTimeMinutes,
    required this.category,
    this.rating = 0.0,
    this.isFavorite = false,
    this.difficulty = 'Medium',
    this.servings = 4,
    this.calories,
    this.chefName = 'Anonymous Chef',
    this.aiTips,
    required this.prepTimeMinutes,
  }) : id = id ?? const Uuid().v4();

  Recipe copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    List<Map<String, dynamic>>? ingredients,
    List<String>? instructions,
    int? totalTimeMinutes,
    String? category,
    double? rating,
    bool? isFavorite,
    String? difficulty,
    int? servings,
    int? calories,
    String? chefName,
    String? aiTips,
    int? prepTimeMinutes,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      totalTimeMinutes: totalTimeMinutes ?? this.totalTimeMinutes,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      isFavorite: isFavorite ?? this.isFavorite,
      difficulty: difficulty ?? this.difficulty,
      servings: servings ?? this.servings,
      calories: calories ?? this.calories,
      chefName: chefName ?? this.chefName,
      aiTips: aiTips ?? this.aiTips,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
    );
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    try {
      print('---- Starting Recipe.fromJson ----');
      print('Raw JSON data: $json');

      final rating = (json['rating'] as num?)?.toDouble() ?? 0.0;

      // Extract cooking time from description
      final description = json['description']?.toString() ?? '';
      print('\nParsing cooking time...');

      // First try to get time directly from totalTimeMinutes
      int? cookingTime = json['totalTimeMinutes'] as int?;
      print('Time from totalTimeMinutes: $cookingTime');

      // If not found, try to extract from description
      if (cookingTime == null) {
        print('Trying to extract time from description...');
        final timePatterns = [
          RegExp(r'takes\s+(?:about |around |roughly )?(\d+)\s+minutes'),
          RegExp(r'takes\s+approximately\s+(\d+)\s+minutes'),
          RegExp(r'preparation\s+to\s+the\s+plate.*?(\d+)\s+minutes'),
          RegExp(r'have\s+about\s+(\d+)\s+minutes'),
          RegExp(r'(\d+)\s+minutes')
        ];

        for (final pattern in timePatterns) {
          print('Trying pattern: ${pattern.pattern}');
          final match = pattern.firstMatch(description);
          if (match != null) {
            print('Match found: ${match.group(0)}');
            cookingTime = int.tryParse(match.group(1) ?? '');
            if (cookingTime != null) {
              print('Successfully extracted time: $cookingTime minutes');
              break;
            }
          }
        }
      }

      // Handle image URL
      print('\nProcessing image URL...');
      String? imageUrl = json['imageUrl']?.toString();
      print('Original imageUrl: $imageUrl');

      if (imageUrl == null ||
          imageUrl.isEmpty ||
          imageUrl.contains('stfunc602d62e0.blob.core.windows.net')) {
        // Pixabay direct image URLs that are guaranteed to work
        final foodImages = [
          'https://pixabay.com/get/g85c90ebbae0f5e54124dbcffefbe119bf77d4c57e6211caa6f78e624e8257d181ee02b976077b5348f01c861bd5f395b_1280.jpg', // colorful dish
          'https://pixabay.com/get/gfb3c3d14d6c252e00d1ad21823370aa67d16bcfa434c435246dd13c8518d2a3d7fd9208d59aa4e0fada66942e743b6c7_1280.jpg', // pasta
          'https://pixabay.com/get/g89f82e52aa5bca071982c57dd42c3c137a18f4613f0471064183c162cb36d8e4cf4c18e8ec746fd103e8757525d11f21_1280.jpg', // salad
          'https://pixabay.com/get/g13fc011c08c44fc254fefc95cb84469e7bed741ddcfa9547293cdf46508c0eefcc80e6b43b03457534ecbb32b61efb8d_1280.jpg', // dessert
          'https://pixabay.com/get/g491258c6a40de488f2e00c6a4ffbef586e00de565ba961a265a0a542209b6639b48f4e699422bc40d51d19456f50bb2d_1280.jpg', // breakfast
        ];

        // Use recipe name hash to consistently pick same image for same recipe
        final recipeNameHash =
            json['name'].toString().codeUnits.reduce((a, b) => a + b);
        imageUrl = foodImages[recipeNameHash % foodImages.length];
        print('Selected fallback imageUrl: $imageUrl');
      }

      final recipe = Recipe(
        id: json['id']?.toString() ?? '',
        title: json['name']?.toString() ?? 'Untitled Recipe',
        description: description,
        imageUrl: imageUrl,
        ingredients: (json['ingredients'] as List<dynamic>?)
                ?.map((i) => Map<String, dynamic>.from(i))
                .toList() ??
            [],
        instructions: (json['instructions'] as List<dynamic>?)
                ?.map((i) => i.toString())
                .toList() ??
            [],
        totalTimeMinutes:
            cookingTime ?? 30, // Use 30 as default only if no time found
        category: json['category']?.toString() ?? 'Uncategorized',
        rating: (rating * 10).round() / 10,
        isFavorite: json['isFavorite'] as bool? ?? false,
        difficulty: json['difficulty']?.toString() ?? 'Medium',
        servings: json['servings'] as int? ?? 4,
        calories: json['calories'] as int?,
        chefName: json['chefName']?.toString() ?? 'Anonymous Chef',
        aiTips: json['aiTips']?.toString(),
        prepTimeMinutes: json['prepTimeMinutes'] as int? ?? 15,
      );

      print('\nCreated Recipe object:');
      print('Title: ${recipe.title}');
      print('Time: ${recipe.totalTimeMinutes} minutes');
      print('Image URL: ${recipe.imageUrl}');
      print('---- End Recipe.fromJson ----\n');

      return recipe;
    } catch (e, stackTrace) {
      print('!!!! Error in Recipe.fromJson !!!!');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Stack trace: $stackTrace');
      print(
          'Problem with JSON data: ${json.toString().substring(0, min(200, json.toString().length))}...');
      print('!!!! End Error !!!!');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'ingredients': ingredients,
      'instructions': instructions,
      'totalTimeMinutes': totalTimeMinutes,
      'category': category,
      'rating': rating,
      'isFavorite': isFavorite,
      'difficulty': difficulty,
      'servings': servings,
      'calories': calories,
      'chefName': chefName,
      'aiTips': aiTips,
      'prepTimeMinutes': prepTimeMinutes,
    };
  }
}
