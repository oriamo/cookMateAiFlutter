import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/azure_function_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

class UploadMealScreen extends ConsumerStatefulWidget {
  const UploadMealScreen({super.key});

  @override
  ConsumerState<UploadMealScreen> createState() => _UploadMealScreenState();
}

class _UploadMealScreenState extends ConsumerState<UploadMealScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _ingredientControllers = <Map<String, TextEditingController>>[];
  final _instructionControllers = <TextEditingController>[];
  XFile? _imageFile;
  bool _isLoading = false;

  // List of available ingredient categories
  final List<String> _categories = [
    'Produce',
    'Meat & Seafood',
    'Dairy',
    'Grains & Bread',
    'Canned Goods',
    'Spices',
    'Baking',
    'Frozen',
    'Snacks',
    'Beverages',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    // Add initial ingredient and instruction fields
    _addIngredient();
    _addInstruction();
  }

  @override
  void dispose() {
    // Clean up controllers
    for (var controllers in _ingredientControllers) {
      controllers['name']?.dispose();
      controllers['amount']?.dispose();
      controllers['unit']?.dispose();
      controllers['category']?.dispose();
    }
    for (var controller in _instructionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addIngredient() {
    setState(() {
      _ingredientControllers.add({
        'name': TextEditingController(),
        'amount': TextEditingController(),
        'unit': TextEditingController(),
        'category': TextEditingController(text: 'Other'), // Default category
      });
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      var controllers = _ingredientControllers.removeAt(index);
      controllers['name']?.dispose();
      controllers['amount']?.dispose();
      controllers['unit']?.dispose();
      controllers['category']?.dispose();
    });
  }

  void _addInstruction() {
    setState(() {
      _instructionControllers.add(TextEditingController());
    });
  }

  void _removeInstruction(int index) {
    setState(() {
      _instructionControllers.removeAt(index).dispose();
    });
  }

  // Helper function to get category icon
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Produce':
        return Icons.eco;
      case 'Meat & Seafood':
        return Icons.food_bank;
      case 'Dairy':
        return Icons.egg;
      case 'Grains & Bread':
        return Icons.bakery_dining;
      case 'Canned Goods':
        return Icons.inventory_2;
      case 'Spices':
        return Icons.spa;
      case 'Baking':
        return Icons.cake;
      case 'Frozen':
        return Icons.ac_unit;
      case 'Snacks':
        return Icons.cookie;
      case 'Beverages':
        return Icons.local_drink;
      case 'Other':
      default:
        return Icons.shopping_basket;
    }
  }

  // Helper function to get category color
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Produce':
        return Colors.green;
      case 'Meat & Seafood':
        return Colors.red;
      case 'Dairy':
        return Colors.blue;
      case 'Grains & Bread':
        return Colors.amber;
      case 'Canned Goods':
        return Colors.indigo;
      case 'Spices':
        return Colors.deepOrange;
      case 'Baking':
        return Colors.brown;
      case 'Frozen':
        return Colors.lightBlue;
      case 'Snacks':
        return Colors.purple;
      case 'Beverages':
        return Colors.teal;
      case 'Other':
      default:
        return Colors.grey;
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        final formData = _formKey.currentState!.value;

        // Prepare ingredients list
        final ingredients = _ingredientControllers.map((controllers) {
          return {
            'name': controllers['name']!.text,
            'amount': controllers['amount']!.text,
            'unit': controllers['unit']!.text,
          };
        }).toList();

        // Prepare instructions list
        final instructions = _instructionControllers
            .map((controller) => controller.text)
            .where((text) => text.isNotEmpty)
            .toList();

        // Create meal using the service
        final azureService = AzureFunctionService();
        await azureService.createMeal(
          name: formData['name'] as String,
          ingredients: ingredients,
          instructions: instructions,
          cookingTime: int.parse(formData['cookingTime'] as String),
          servings: int.parse(formData['servings'] as String),
          category: formData['category'] as String,
          difficulty: formData['difficulty'] as String,
          calories: int.tryParse(formData['calories'] as String? ?? ''),
        );

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal uploaded successfully!')),
        );

        // Navigate to home screen
        context.goNamed('home');
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading meal: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload New Meal'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _submitForm,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: FormBuilder(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image picker
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _imageFile!.path,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add Meal Photo',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Basic Information
              Text(
                'Basic Information',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Wrap basic information in a styled card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Meal name field with icon
                      FormBuilderTextField(
                        name: 'name',
                        decoration: InputDecoration(
                          labelText: 'Meal Name',
                          prefixIcon: const Icon(Icons.restaurant_menu),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          fillColor: Colors.grey.shade50,
                          filled: true,
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                        ]),
                      ),

                      const SizedBox(height: 16),

                      // Cooking time and servings in a row with icons
                      Row(
                        children: [
                          Expanded(
                            child: FormBuilderTextField(
                              name: 'cookingTime',
                              decoration: InputDecoration(
                                labelText: 'Cooking Time (min)',
                                prefixIcon: const Icon(Icons.timer),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                fillColor: Colors.grey.shade50,
                                filled: true,
                              ),
                              keyboardType: TextInputType.number,
                              validator: FormBuilderValidators.compose([
                                FormBuilderValidators.required(),
                                FormBuilderValidators.numeric(),
                              ]),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FormBuilderTextField(
                              name: 'servings',
                              decoration: InputDecoration(
                                labelText: 'Servings',
                                prefixIcon: const Icon(Icons.people),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                fillColor: Colors.grey.shade50,
                                filled: true,
                              ),
                              keyboardType: TextInputType.number,
                              validator: FormBuilderValidators.compose([
                                FormBuilderValidators.required(),
                                FormBuilderValidators.numeric(),
                              ]),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Category dropdown with icon
                      FormBuilderDropdown<String>(
                        name: 'category',
                        decoration: InputDecoration(
                          labelText: 'Meal Category',
                          prefixIcon: const Icon(Icons.category),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          fillColor: Colors.grey.shade50,
                          filled: true,
                        ),
                        items: [
                          'Main Course',
                          'Appetizer',
                          'Dessert',
                          'Breakfast',
                          'Soup',
                          'Salad',
                          'Snack',
                        ]
                            .map((category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ))
                            .toList(),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                        ]),
                      ),

                      const SizedBox(height: 16),

                      // Difficulty dropdown with icon and colored difficulty levels
                      FormBuilderDropdown<String>(
                        name: 'difficulty',
                        decoration: InputDecoration(
                          labelText: 'Difficulty Level',
                          prefixIcon: const Icon(Icons.fitness_center),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          fillColor: Colors.grey.shade50,
                          filled: true,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'Easy',
                            child: Row(
                              children: [
                                Icon(Icons.sentiment_satisfied,
                                    color: Colors.green),
                                const SizedBox(width: 8),
                                const Text('Easy'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Medium',
                            child: Row(
                              children: [
                                Icon(Icons.sentiment_neutral,
                                    color: Colors.orange),
                                const SizedBox(width: 8),
                                const Text('Medium'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Hard',
                            child: Row(
                              children: [
                                Icon(Icons.sentiment_dissatisfied,
                                    color: Colors.red),
                                const SizedBox(width: 8),
                                const Text('Hard'),
                              ],
                            ),
                          ),
                        ],
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                        ]),
                      ),

                      const SizedBox(height: 16),

                      // Calories field with icon
                      FormBuilderTextField(
                        name: 'calories',
                        decoration: InputDecoration(
                          labelText: 'Calories (optional)',
                          prefixIcon: const Icon(Icons.local_fire_department),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          fillColor: Colors.grey.shade50,
                          filled: true,
                        ),
                        keyboardType: TextInputType.number,
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.numeric(),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Ingredients Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ingredients',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _addIngredient,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Ingredient'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ingredientControllers.length,
                itemBuilder: (context, index) {
                  final categoryValue =
                      _ingredientControllers[index]['category']?.text ??
                          'Other';
                  final categoryColor = _getCategoryColor(categoryValue);
                  final categoryIcon = _getCategoryIcon(categoryValue);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: categoryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ingredient header with category icon
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: categoryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  categoryIcon,
                                  color: categoryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Ingredient ${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                tooltip: 'Remove ingredient',
                                onPressed: () => _removeIngredient(index),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Ingredient name field
                          TextFormField(
                            controller: _ingredientControllers[index]['name'],
                            decoration: InputDecoration(
                              labelText: 'Ingredient Name',
                              prefixIcon: const Icon(Icons.food_bank),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              fillColor: Colors.grey.shade50,
                              filled: true,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Amount and Unit in a row
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _ingredientControllers[index]
                                      ['amount'],
                                  decoration: InputDecoration(
                                    labelText: 'Amount',
                                    prefixIcon: const Icon(Icons.numbers),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    fillColor: Colors.grey.shade50,
                                    filled: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'Unit',
                                    prefixIcon: const Icon(Icons.straighten),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    fillColor: Colors.grey.shade50,
                                    filled: true,
                                  ),
                                  value: _ingredientControllers[index]['unit']!
                                          .text
                                          .isEmpty
                                      ? null
                                      : _ingredientControllers[index]['unit']!
                                          .text,
                                  items: [
                                    'g',
                                    'kg',
                                    'oz',
                                    'lb',
                                    'ml',
                                    'l',
                                    'tsp',
                                    'tbsp',
                                    'cup',
                                    'pinch',
                                    'piece',
                                    'slice',
                                    'clove',
                                    'to taste'
                                  ]
                                      .map((unit) => DropdownMenuItem(
                                            value: unit,
                                            child: Text(unit),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      _ingredientControllers[index]['unit']!
                                          .text = value;
                                    }
                                  },
                                  hint: const Text('Select unit'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Category dropdown
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Category',
                              prefixIcon: Icon(
                                categoryIcon,
                                color: categoryColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              fillColor: Colors.grey.shade50,
                              filled: true,
                            ),
                            value: categoryValue,
                            items: _categories.map((category) {
                              final catIcon = _getCategoryIcon(category);
                              final catColor = _getCategoryColor(category);
                              return DropdownMenuItem(
                                value: category,
                                child: Row(
                                  children: [
                                    Icon(
                                      catIcon,
                                      size: 20,
                                      color: catColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(category),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _ingredientControllers[index]['category']!
                                      .text = value;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Instructions Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Instructions',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _addInstruction,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Step'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _instructionControllers.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Step header with number
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Step ${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                tooltip: 'Remove step',
                                onPressed: () => _removeInstruction(index),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _instructionControllers[index],
                            decoration: InputDecoration(
                              hintText: 'Enter instruction details...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              fillColor: Colors.grey.shade50,
                              filled: true,
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
