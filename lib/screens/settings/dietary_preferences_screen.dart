import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';

class DietaryPreferenceScreen extends ConsumerStatefulWidget {
  final bool isOnboarding;
  final bool isAllergiesScreen;
  final bool isInCoordinator;
  final VoidCallback? onComplete;

  const DietaryPreferenceScreen({
    super.key,
    this.isOnboarding = false,
    this.isAllergiesScreen = false,
    this.isInCoordinator = false,
    this.onComplete,
  });

  @override
  DietaryRestrictionsScreenState createState() =>
      DietaryRestrictionsScreenState();
}

class DietaryRestrictionsScreenState
    extends ConsumerState<DietaryPreferenceScreen> {
  late List<String> _selectedRestrictions;

  final List<Map<String, dynamic>> _dietaryRestrictions = [
    {
      'name': 'Vegetarian',
      'icon': Icons.spa,
      'color': Colors.green,
      'description': 'No meat, poultry, or seafood',
    },
    {
      'name': 'Vegan',
      'icon': Icons.grass,
      'color': Colors.green.shade700,
      'description': 'No animal products of any kind',
    },
    {
      'name': 'Pescatarian',
      'icon': Icons.set_meal,
      'color': Colors.blue,
      'description': 'No meat or poultry, but seafood is allowed',
    },
    {
      'name': 'Gluten-Free',
      'icon': Icons.no_food,
      'color': Colors.amber.shade700,
      'description': 'No wheat, barley, rye, or related grains',
    },
    {
      'name': 'Dairy-Free',
      'icon': Icons.no_drinks,
      'color': Colors.lightBlue,
      'description': 'No milk or milk products',
    },
    {
      'name': 'Keto',
      'icon': Icons.category,
      'color': Colors.deepPurple,
      'description': 'Low carb, high fat diet',
    },
    {
      'name': 'Paleo',
      'icon': Icons.fitness_center,
      'color': Colors.brown,
      'description': 'Based on foods available to our prehistoric ancestors',
    },
    {
      'name': 'Halal',
      'icon': Icons.check_circle,
      'color': Colors.teal,
      'description': 'Adheres to Islamic dietary laws',
    },
    {
      'name': 'Kosher',
      'icon': Icons.verified,
      'color': Colors.indigo,
      'description': 'Adheres to Jewish dietary laws',
    },
    {
      'name': 'No Restrictions',
      'icon': Icons.restaurant,
      'color': Colors.grey,
      'description': 'I eat everything',
    },
  ];

  @override
  void initState() {
    super.initState();
    final userProfile = ref.read(userProfileProvider);

    if (widget.isAllergiesScreen) {
      _selectedRestrictions = List<String>.from(userProfile.allergies ?? []);
    } else {
      _selectedRestrictions =
          List<String>.from(userProfile.dietaryPreferences ?? []);
    }

    // Default to 'No Restrictions' if nothing is selected
    if (_selectedRestrictions.isEmpty) {
      _selectedRestrictions.add('No Restrictions');
    }
  }

  // Add this method to expose the selected restrictions to the parent
  List<String> getSelectedRestrictions() {
    // Don't include "No Restrictions" in the returned list
    return _selectedRestrictions.contains('No Restrictions')
        ? <String>[]
        : _selectedRestrictions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAllergiesScreen
            ? 'Food Allergies'
            : 'Dietary Restrictions'),
        automaticallyImplyLeading: !widget.isOnboarding,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (widget.isOnboarding && !widget.isInCoordinator)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress Indicator - only show this when NOT in coordinator
          if (widget.isOnboarding && !widget.isInCoordinator)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 8,
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 8,
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 8,
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 8,
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 8,
                      color: Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isAllergiesScreen
                        ? 'Any food allergies?'
                        : 'Any dietary restrictions?',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isAllergiesScreen
                        ? 'Select any food allergies you have. We\'ll make sure to exclude these ingredients from your recipes.'
                        : 'Select any dietary restrictions you follow. We\'ll tailor your meal options accordingly.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Dietary restrictions list
                  ...buildDietaryRestrictionCards(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Continue button - only show when not in coordinator
          if (!widget.isInCoordinator)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _saveDietaryRestrictions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  widget.isOnboarding ? 'Continue' : 'Save Preferences',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> buildDietaryRestrictionCards() {
    return _dietaryRestrictions.map((restriction) {
      final bool isSelected =
          _selectedRestrictions.contains(restriction['name']);
      final bool isNoRestrictions = restriction['name'] == 'No Restrictions';

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: () {
            setState(() {
              if (isNoRestrictions) {
                // If selecting "No Restrictions", clear all other selections
                if (!isSelected) {
                  _selectedRestrictions.clear();
                  _selectedRestrictions.add('No Restrictions');
                }
              } else {
                // If selecting any other restriction, remove "No Restrictions"
                _selectedRestrictions.remove('No Restrictions');

                if (isSelected) {
                  _selectedRestrictions.remove(restriction['name']);
                  // If no restrictions selected, default back to "No Restrictions"
                  if (_selectedRestrictions.isEmpty) {
                    _selectedRestrictions.add('No Restrictions');
                  }
                } else {
                  _selectedRestrictions.add(restriction['name']);
                }
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Colors.green : Colors.grey.shade300,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon in circle
                  CircleAvatar(
                    backgroundColor: restriction['color'].withOpacity(0.2),
                    radius: 24,
                    child: Icon(
                      restriction['icon'],
                      color: restriction['color'],
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restriction['name'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          restriction['description'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Selection indicator
                  if (isSelected)
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(
                        Icons.check,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  void _saveDietaryRestrictions() async {
    final userNotifier = ref.read(userProfileProvider.notifier);

    // Don't save "No Restrictions" to the profile
    final restrictionsToSave = _selectedRestrictions.contains('No Restrictions')
        ? <String>[]
        : _selectedRestrictions;

    await userNotifier.updateProfile(
      dietaryPreferences: restrictionsToSave,
    );

    if (mounted) {
      if (widget.isOnboarding && widget.onComplete != null) {
        widget.onComplete!();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dietary restrictions saved')),
        );
        Navigator.of(context).pop();
      }
    }
  }
}
