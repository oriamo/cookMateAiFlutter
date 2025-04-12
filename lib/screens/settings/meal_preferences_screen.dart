import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';

class MealPreferencesScreen extends ConsumerStatefulWidget {
  final bool isInCoordinator;
  final VoidCallback? onComplete;

  const MealPreferencesScreen({
    super.key,
    this.isInCoordinator = false,
    this.onComplete,
  });

  @override
  ConsumerState<MealPreferencesScreen> createState() =>
      _MealPreferencesScreenState();
}

class _MealPreferencesScreenState extends ConsumerState<MealPreferencesScreen> {
  List<String> _selectedMealTypes = [];

  final List<Map<String, dynamic>> _mealOptions = [
    {
      'name': 'Calorie Smart',
      'icon': Icons.scale,
      'color': Colors.cyan,
      'image': 'assets/images/calorie_smart.png',
    },
    {
      'name': 'Chef\'s Choice',
      'icon': Icons.fastfood,
      'color': Colors.red,
      'image': 'assets/images/chefs_choice.png',
    },
    {
      'name': 'Keto',
      'icon': Icons.loop,
      'color': Colors.amber,
      'image': 'assets/images/keto.png',
    },
    {
      'name': 'Protein Plus',
      'icon': Icons.fitness_center,
      'color': Colors.blue,
      'image': 'assets/images/protein.png',
    },
    {
      'name': 'Carb Conscious',
      'icon': Icons.grain,
      'color': Colors.orange,
      'image': 'assets/images/carb.png',
    },
    {
      'name': 'GLP-1 Balance',
      'icon': Icons.hub,
      'color': Colors.purple,
      'image': 'assets/images/glp.png',
    },
    {
      'name': 'Plant Based',
      'icon': Icons.eco,
      'color': Colors.green,
      'image': 'assets/images/plant.png',
    },
    {
      'name': 'Family Style',
      'icon': Icons.people,
      'color': Colors.teal,
      'image': 'assets/images/family.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    final userProfile = ref.read(userProfileProvider);
    _selectedMealTypes = List<String>.from(userProfile.dietaryPreferences);
  }

  @override
  Widget build(BuildContext context) {
    return widget.isInCoordinator
        ? _buildContent()
        : Scaffold(
            appBar: AppBar(
              title: const Text('Meal Preferences'),
              backgroundColor: Colors.green,
            ),
            body: _buildContent(),
          );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What kind of meals do you prefer?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You\'ll have access to the full menu, but we\'ll show these meals first.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildMealGrid(),
                ],
              ),
            ),
          ),
        ),
        if (!widget.isInCoordinator) _buildSaveButton(),
      ],
    );
  }

  Widget _buildMealGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _mealOptions.length,
      itemBuilder: (context, index) {
        final option = _mealOptions[index];
        final bool isSelected = _selectedMealTypes.contains(option['name']);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedMealTypes.remove(option['name']);
              } else {
                _selectedMealTypes.add(option['name']);
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Colors.green : Colors.grey.shade300,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10)),
                        child: Container(
                          color: option['color'].withOpacity(0.1),
                          child: Center(
                            child: Icon(
                              option['icon'],
                              color: option['color'],
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        option['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        onPressed: _saveMealPreferences,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'Save Preferences',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _saveMealPreferences() async {
    // Save meal preferences to user profile
    final userNotifier = ref.read(userProfileProvider.notifier);
    await userNotifier.updateProfile(
      dietaryPreferences: _selectedMealTypes,
    );

    // If there's a onComplete callback, call it (for when in the coordinator)
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      // Otherwise just pop back to previous screen
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
