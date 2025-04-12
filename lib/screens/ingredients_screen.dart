import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/ingredients_provider.dart';
import '../models/ingredient.dart';
import 'package:uuid/uuid.dart';

class IngredientsScreen extends ConsumerStatefulWidget {
  const IngredientsScreen({super.key});

  @override
  ConsumerState<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends ConsumerState<IngredientsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  String? _selectedCategory;
  String _searchQuery = '';
  final _searchController = TextEditingController();

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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Produce':
        return Icons.eco;
      case 'Meat & Seafood':
        return Icons.lunch_dining;
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
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Produce':
        return Colors.green;
      case 'Meat & Seafood':
        return Colors.redAccent;
      case 'Dairy':
        return Colors.blue.shade200;
      case 'Grains & Bread':
        return Colors.amber;
      case 'Canned Goods':
        return Colors.grey;
      case 'Spices':
        return Colors.orange;
      case 'Baking':
        return Colors.brown;
      case 'Frozen':
        return Colors.lightBlue;
      case 'Snacks':
        return Colors.purple;
      case 'Beverages':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  void _openAddIngredientDialog() {
    // Reset form fields
    _nameController.clear();
    _quantityController.clear();
    _unitController.clear();
    _selectedCategory = null;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    child: Icon(
                      Icons.add_shopping_cart,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Add New Ingredient',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Ingredient Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.shopping_basket),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      style: const TextStyle(fontSize: 16),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter ingredient name';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            decoration: InputDecoration(
                              labelText: 'Quantity',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.straighten),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _unitController,
                            decoration: InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.scale),
                              hintText: 'e.g., cup, gram',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(
                          _selectedCategory != null
                              ? _getCategoryIcon(_selectedCategory!)
                              : Icons.category,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      value: _selectedCategory,
                      hint: const Text('Select category'),
                      borderRadius: BorderRadius.circular(12),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Icon(
                                _getCategoryIcon(category),
                                size: 20,
                                color: _getCategoryColor(category),
                              ),
                              const SizedBox(width: 8),
                              Text(category),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Ingredient'),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        ref.read(ingredientsProvider.notifier).addIngredient(
                              name: _nameController.text,
                              quantity: _quantityController.text.isEmpty
                                  ? null
                                  : _quantityController.text,
                              unit: _unitController.text.isEmpty
                                  ? null
                                  : _unitController.text,
                              category: _selectedCategory,
                            );
                        Navigator.pop(context);

                        // Show success snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${_nameController.text} added to grocery list'),
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                            duration: const Duration(seconds: 2),
                            action: SnackBarAction(
                              label: 'VIEW',
                              onPressed: () {
                                // Find the newly added ingredient and navigate to its detail
                                final ingredients =
                                    ref.read(ingredientsProvider);
                                final newIngredient = ingredients.firstWhere(
                                  (ingredient) =>
                                      ingredient.name == _nameController.text,
                                  orElse: () => Ingredient(id: '', name: ''),
                                );
                                if (newIngredient.id.isNotEmpty) {
                                  context
                                      .push('/ingredient/${newIngredient.id}');
                                }
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = ref.watch(ingredientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingredients'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            // Tab(text: 'Pantry'),
            Tab(text: 'Grocery List'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search ingredients...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All ingredients tab
                ListView.builder(
                  itemCount: ingredients.length,
                  itemBuilder: (context, index) {
                    final ingredient = ingredients[index];
                    return ListTile(
                      title: Text(ingredient.name),
                      subtitle: ingredient.category != null
                          ? Text(ingredient.category!)
                          : null,
                      leading: Icon(
                        ingredient.category != null
                            ? _getCategoryIcon(ingredient.category!)
                            : Icons.food_bank,
                        color: ingredient.category != null
                            ? _getCategoryColor(ingredient.category!)
                            : null,
                      ),
                      trailing: Text(
                        ingredient.quantity != null && ingredient.unit != null
                            ? '${ingredient.quantity} ${ingredient.unit}'
                            : ingredient.quantity != null
                                ? ingredient.quantity!
                                : '',
                      ),
                      onTap: () {
                        // Navigate to ingredient detail
                        context.push('/ingredient/${ingredient.id}');
                      },
                    );
                  },
                ),
                // Pantry tab
                // const Center(child: Text('Pantry items here')),
                // Grocery list tab
                const Center(child: Text('Grocery list here')),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddIngredientDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
