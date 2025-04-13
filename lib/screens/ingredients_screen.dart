import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/ingredients_provider.dart';
import '../models/ingredient.dart';
import '../dummy_data/dummy_ingredients.dart'; // Import dummy data directly
// import 'package:uuid/uuid.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';

// DEMO MODE: Direct access to dummy ingredients
final dummyIngredientsProvider = Provider<List<Ingredient>>((ref) {
  return dummyIngredients;
});

// DEMO MODE: Filtered ingredients providers
final unpurchasedDummyIngredientsProvider = Provider<List<Ingredient>>((ref) {
  final ingredients = ref.watch(dummyIngredientsProvider);
  return ingredients.where((ingredient) => !ingredient.isPurchased).toList();
});

final purchasedDummyIngredientsProvider = Provider<List<Ingredient>>((ref) {
  final ingredients = ref.watch(dummyIngredientsProvider);
  return ingredients.where((ingredient) => ingredient.isPurchased).toList();
});

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
    _tabController = TabController(length: 2, vsync: this);
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
                        // DEMO MODE: Don't actually add ingredient
                        // ref.read(ingredientsProvider.notifier).addIngredient(
                        //       name: _nameController.text,
                        //       quantity: _quantityController.text.isEmpty
                        //           ? null
                        //           : _quantityController.text,
                        //       unit: _unitController.text.isEmpty
                        //           ? null
                        //           : _unitController.text,
                        //       category: _selectedCategory,
                        //     );
                        Navigator.pop(context);

                        // Show demo mode snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '[DEMO] ${_nameController.text} would be added to grocery list'),
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                            duration: const Duration(seconds: 2),
                            action: SnackBarAction(
                              label: 'DEMO INFO',
                              onPressed: () {
                                // Show demo mode dialog
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Demo Mode'),
                                    content: const Text(
                                        'This is a demo. In a real app, your new ingredient would be added permanently.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
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

  Widget _buildIngredientItem(Ingredient ingredient) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = _getCategoryColor(ingredient.category ?? 'Other');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (context) => _deleteIngredient(ingredient),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            SlidableAction(
              onPressed: (context) =>
                  context.push('/ingredient/${ingredient.id}'),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.info,
              label: 'Details',
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _togglePurchased(ingredient),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 5,
                ),
              ],
              border: Border.all(
                color: ingredient.isPurchased
                    ? Colors.green.withOpacity(0.5)
                    : Colors.grey.withOpacity(0.2),
                width: ingredient.isPurchased ? 2 : 1,
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              child: Row(
                children: [
                  // Checkbox with custom styling
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _togglePurchased(ingredient),
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ingredient.isPurchased
                                ? Colors.green
                                : isDarkMode
                                    ? Colors.grey[700]
                                    : Colors.grey[200],
                            border: Border.all(
                              color: ingredient.isPurchased
                                  ? Colors.green
                                  : Colors.grey.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: ingredient.isPurchased
                              ? const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Category icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getCategoryIcon(ingredient.category ?? 'Other'),
                      color: categoryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Ingredient name and details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                ingredient.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  decoration: ingredient.isPurchased
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: ingredient.isPurchased
                                      ? isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600]
                                      : isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (ingredient.quantity != null ||
                            ingredient.unit != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              [
                                if (ingredient.quantity != null)
                                  ingredient.quantity,
                                if (ingredient.unit != null) ingredient.unit,
                              ].join(' '),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                decoration: ingredient.isPurchased
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Category badge
                  if (ingredient.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: categoryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        ingredient.category!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: categoryColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _togglePurchased(Ingredient ingredient) {
    // DEMO MODE: Don't actually toggle the purchase status
    // ref.read(ingredientsProvider.notifier).togglePurchased(ingredient.id);

    // Show demo mode snackbar feedback
    final message = ingredient.isPurchased
        ? '[DEMO] ${ingredient.name} would be unmarked'
        : '[DEMO] ${ingredient.name} would be checked off';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'DEMO INFO',
          onPressed: () {
            // Show demo mode dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Demo Mode'),
                content: const Text(
                    'This is a demo. In a real app, your changes would be saved.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _deleteIngredient(Ingredient ingredient) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${ingredient.name}?'),
        content: const Text('Are you sure you want to remove this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // DEMO MODE: Don't actually delete the ingredient
              // ref
              //     .read(ingredientsProvider.notifier)
              //     .removeIngredient(ingredient.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('[DEMO] ${ingredient.name} would be removed'),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(
                    label: 'DEMO INFO',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Demo Mode'),
                          content: const Text(
                              'This is a demo. In a real app, this ingredient would be permanently removed.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // DEMO MODE: Use dummy data providers directly
    final dummyIngredients = ref.watch(dummyIngredientsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Filter ingredients based on search and tab
    final filteredIngredients = dummyIngredients.where((ingredient) {
      final matchesSearch = _searchQuery.isEmpty ||
          ingredient.name.toLowerCase().contains(_searchQuery.toLowerCase());

      if (_selectedTabIndex == 0) {
        // All tab
        return matchesSearch;
      } else {
        // Done tab
        return matchesSearch && ingredient.isPurchased;
      }
    }).toList();

    // Count of purchased items
    final purchasedCount = dummyIngredients.where((i) => i.isPurchased).length;
    final totalCount = dummyIngredients.length;

    return Scaffold(
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                floating: true,
                forceElevated: innerBoxIsScrolled,
                elevation: 0,
                backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
                title: Text(
                  'Shopping List',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(110),
                  child: Column(
                    children: [
                      // Progress indicator
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Progress',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: totalCount > 0
                                          ? purchasedCount / totalCount
                                          : 0,
                                      backgroundColor: isDarkMode
                                          ? Colors.grey[800]
                                          : Colors.grey[200],
                                      color: Colors.green,
                                      minHeight: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                '$purchasedCount/$totalCount',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Search bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search ingredients...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: isDarkMode
                                ? Colors.grey[800]
                                : Colors.grey[100],
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),

                      // Tab bar
                      TabBar(
                        controller: _tabController,
                        tabs: [
                          Tab(
                            icon: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shopping_cart),
                                const SizedBox(width: 8),
                                const Text('All'),
                                const SizedBox(width: 4),
                                Text(
                                  '($totalCount)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tab(
                            icon: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle),
                                const SizedBox(width: 8),
                                const Text('Purchased'),
                                const SizedBox(width: 4),
                                Text(
                                  '($purchasedCount)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorWeight: 3,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor:
                            isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: filteredIngredients.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: filteredIngredients.length,
                  padding: const EdgeInsets.only(top: 8, bottom: 100),
                  itemBuilder: (context, index) {
                    final ingredient = filteredIngredients[index];
                    return _buildIngredientItem(ingredient);
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddIngredientDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedTabIndex == 0 ? Icons.shopping_cart : Icons.check_circle,
            size: 80,
            color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedTabIndex == 0
                ? _searchQuery.isEmpty
                    ? 'Your shopping list is empty'
                    : 'No matching ingredients found'
                : _searchQuery.isEmpty
                    ? 'No purchased items yet'
                    : 'No matching purchased items',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _selectedTabIndex == 0
                  ? _searchQuery.isEmpty
                      ? 'Add ingredients to your shopping list'
                      : 'Try a different search term'
                  : _searchQuery.isEmpty
                      ? 'Items you check off will appear here'
                      : 'Try a different search term',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty && _selectedTabIndex == 0)
            ElevatedButton.icon(
              onPressed: _openAddIngredientDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add First Item'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}
