import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecipeScreen extends ConsumerWidget {
  final String recipeId;
  
  const RecipeScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This would normally fetch data from a provider
    // For now we'll use placeholder data
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Details'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delicious Pasta Primavera',
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                width: double.infinity,
                child: const Center(
                  child: Icon(Icons.image, size: 80, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Ingredients',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildIngredientsList(),
              const SizedBox(height: 24),
              const Text(
                'Instructions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildInstructionsList(),
              const SizedBox(height: 24),
              const Text(
                'AI Tips',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: const Text(
                  'For a creamier texture, try adding a splash of heavy cream at the end. You can also substitute the vegetables with any seasonal ones you have on hand.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientsList() {
    final ingredients = [
      '8 oz pasta',
      '2 tablespoons olive oil',
      '1 zucchini, sliced',
      '1 yellow squash, sliced',
      '1 red bell pepper, chopped',
      '1 cup cherry tomatoes, halved',
      '3 cloves garlic, minced',
      '1/4 cup grated Parmesan cheese',
      'Fresh basil for garnish',
      'Salt and pepper to taste'
    ];
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ingredients.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Text(
                  ingredients[index],
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstructionsList() {
    final instructions = [
      'Bring a large pot of salted water to a boil. Cook pasta according to package directions until al dente.',
      'While pasta is cooking, heat olive oil in a large skillet over medium-high heat.',
      'Add zucchini, squash, and bell pepper. Sauté for 3-4 minutes until vegetables begin to soften.',
      'Add cherry tomatoes and garlic. Cook for another 2 minutes.',
      'Drain pasta and add it to the skillet with vegetables. Toss to combine.',
      'Remove from heat and stir in Parmesan cheese. Season with salt and pepper.',
      'Garnish with fresh basil before serving.'
    ];
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: instructions.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${index + 1}. ', 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: Text(
                  instructions[index],
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}