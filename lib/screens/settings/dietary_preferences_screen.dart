import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';

class DietaryPreferencesScreen extends ConsumerStatefulWidget {
  const DietaryPreferencesScreen({super.key});

  @override
  ConsumerState<DietaryPreferencesScreen> createState() =>
      _DietaryPreferencesScreenState();
}

class _DietaryPreferencesScreenState
    extends ConsumerState<DietaryPreferencesScreen> {
  late List<String> _selectedPreferences;
  late List<String> _allergies;

  final List<String> _dietaryOptions = [
    'Vegetarian',
    'Vegan',
    'Pescatarian',
    'Paleo',
    'Keto',
    'Gluten-Free',
    'Dairy-Free',
    'Low Carb',
    'Mediterranean',
    'Halal',
    'Kosher',
  ];

  final List<String> _commonAllergies = [
    'Peanuts',
    'Tree Nuts',
    'Milk',
    'Eggs',
    'Wheat',
    'Soy',
    'Fish',
    'Shellfish',
    'Sesame',
  ];

  @override
  void initState() {
    super.initState();
    final userProfile = ref.read(userProfileProvider);
    _selectedPreferences = List<String>.from(userProfile.dietaryPreferences);
    _allergies = List<String>.from(userProfile.allergies);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dietary Preferences'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Dietary Preferences',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'These settings help us recommend recipes that match your diet.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Dietary preferences checkboxes
            ...buildDietaryCheckboxes(),

            const Divider(height: 40),

            const Text(
              'Food Allergies',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select any allergies to exclude from recommendations.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Allergies checkboxes
            ...buildAllergiesCheckboxes(),

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveDietaryPreferences,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Preferences'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> buildDietaryCheckboxes() {
    return _dietaryOptions.map((preference) {
      return CheckboxListTile(
        title: Text(preference),
        value: _selectedPreferences.contains(preference),
        onChanged: (bool? selected) {
          setState(() {
            if (selected == true) {
              if (!_selectedPreferences.contains(preference)) {
                _selectedPreferences.add(preference);
              }
            } else {
              _selectedPreferences.remove(preference);
            }
          });
        },
      );
    }).toList();
  }

  List<Widget> buildAllergiesCheckboxes() {
    return _commonAllergies.map((allergy) {
      return CheckboxListTile(
        title: Text(allergy),
        value: _allergies.contains(allergy),
        onChanged: (bool? selected) {
          setState(() {
            if (selected == true) {
              if (!_allergies.contains(allergy)) {
                _allergies.add(allergy);
              }
            } else {
              _allergies.remove(allergy);
            }
          });
        },
      );
    }).toList();
  }

  void _saveDietaryPreferences() async {
    final userNotifier = ref.read(userProfileProvider.notifier);

    await userNotifier.updateProfile(
      dietaryPreferences: _selectedPreferences,
      allergies: _allergies,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dietary preferences saved')),
      );
      Navigator.of(context).pop();
    }
  }
}
