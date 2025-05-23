import 'package:uuid/uuid.dart';
import 'dart:math';
import 'instruction.dart';

class Recipe {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final List<Map<String, dynamic>> ingredients;
  final List<InstructionStep> instructions;
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
    List<InstructionStep>? instructions,
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

      // Get and clean up description
      String description = json['description']?.toString() ?? '';

      // Remove unwanted HTML tags but preserve bold text
      description = description.replaceAllMapped(
          RegExp(r'<b>(.*?)</b>', caseSensitive: false),
          (match) => '**${match.group(1)}**');

      // Remove all other HTML tags
      description = description.replaceAll(RegExp(r'<[^>]*>'), '');

      // Convert markdown-style bold back to actual bold text
      description = description.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'),
          (match) => match.group(1)?.toUpperCase() ?? '');

      // Clean up any extra whitespace
      description = description.replaceAll(RegExp(r'\s+'), ' ').trim();

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

      if (imageUrl == null || imageUrl.isEmpty) {
        // Only use fallback image if no image URL is provided
        imageUrl =
            'https://images.unsplash.com/photo-1495521821757-a1efb6729352?auto=format&fit=crop&w=800&q=80';
        print('Using fallback imageUrl: $imageUrl');
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
                ?.map((i) => InstructionStep.fromJson(Map<String, dynamic>.from(i)))
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
      'instructions': instructions
          .map((step) => step.toJson())
          .toList(),
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
