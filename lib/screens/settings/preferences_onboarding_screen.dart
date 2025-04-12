import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_profile.dart';
import '../../providers/user_provider.dart';

class PreferencesOnboardingScreen extends ConsumerStatefulWidget {
  const PreferencesOnboardingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PreferencesOnboardingScreen> createState() =>
      _PreferencesOnboardingScreenState();
}

class _PreferencesOnboardingScreenState
    extends ConsumerState<PreferencesOnboardingScreen> {
  int _currentStep = 0;
  final int _totalSteps = 5;

  // Health goals options
  final List<String> _availableHealthGoals = [
    'Lose Weight',
    'Gain Muscle',
    'Improve Energy',
    'Better Digestion',
    'Heart Health',
    'Balanced Diet',
  ];
  List<String> _selectedHealthGoals = [];

  // Dietary preferences options
  final List<String> _availableDietaryPreferences = [
    'Vegetarian',
    'Vegan',
    'Pescatarian',
    'Keto',
    'Paleo',
    'Low Carb',
    'Mediterranean',
    'Gluten-Free',
    'Dairy-Free',
  ];
  List<String> _selectedDietaryPreferences = [];

  // Allergies options
  final List<String> _availableAllergies = [
    'Peanuts',
    'Tree Nuts',
    'Milk',
    'Eggs',
    'Fish',
    'Shellfish',
    'Soy',
    'Wheat',
  ];
  List<String> _selectedAllergies = [];

  // Cooking skill level options
  final List<String> _cookingSkillLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];
  String _selectedSkillLevel = 'Beginner';

  // Max prep time options (in minutes)
  final List<int> _prepTimeOptions = [15, 30, 45, 60, 90, 120];
  int _selectedPrepTime = 60;

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _completeOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    // Update the user profile with all selected preferences
    final userProfileNotifier = ref.read(userProfileProvider.notifier);

    await userProfileNotifier.updateProfile(
      healthGoals: _selectedHealthGoals,
      dietaryPreferences: _selectedDietaryPreferences,
      allergies: _selectedAllergies,
      cookingSkillLevel: _selectedSkillLevel.toLowerCase(),
      maxPrepTimeMinutes: _selectedPrepTime,
    );

    // Mark onboarding as complete
    await userProfileNotifier.completeOnboarding();

    // Navigate to the home page instead of just popping
    if (mounted) {
      if (context.mounted) {
        // Using GoRouter to navigate to the home page
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Preferences'),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousStep,
              )
            : null,
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: Colors.grey[300],
            valueColor:
                AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Step ${_currentStep + 1} of $_totalSteps',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${((_currentStep + 1) / _totalSteps * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          // Current step content
          Expanded(
            child: _buildCurrentStep(),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          child: Text(
            _currentStep < _totalSteps - 1 ? 'Continue' : 'Finish',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildHealthGoalsStep();
      case 1:
        return _buildDietaryPreferencesStep();
      case 2:
        return _buildAllergiesStep();
      case 3:
        return _buildCookingSkillStep();
      case 4:
        return _buildPrepTimeStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHealthGoalsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What are your health goals?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Select all that apply. This will help us recommend recipes that match your goals.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _availableHealthGoals.map((goal) {
              final isSelected = _selectedHealthGoals.contains(goal);
              return FilterChip(
                label: Text(goal),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedHealthGoals.add(goal);
                    } else {
                      _selectedHealthGoals.remove(goal);
                    }
                  });
                },
                backgroundColor: Colors.grey[200],
                selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                checkmarkColor: Theme.of(context).primaryColor,
                showCheckmark: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.transparent,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryPreferencesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dietary Preferences',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Select any special diets you follow.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _availableDietaryPreferences.map((diet) {
              final isSelected = _selectedDietaryPreferences.contains(diet);
              return FilterChip(
                label: Text(diet),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDietaryPreferences.add(diet);
                    } else {
                      _selectedDietaryPreferences.remove(diet);
                    }
                  });
                },
                backgroundColor: Colors.grey[200],
                selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                checkmarkColor: Theme.of(context).primaryColor,
                showCheckmark: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.transparent,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergiesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Any Food Allergies?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Select any ingredients you need to avoid.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _availableAllergies.map((allergy) {
              final isSelected = _selectedAllergies.contains(allergy);
              return FilterChip(
                label: Text(allergy),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedAllergies.add(allergy);
                    } else {
                      _selectedAllergies.remove(allergy);
                    }
                  });
                },
                backgroundColor: Colors.grey[200],
                selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                checkmarkColor: Theme.of(context).primaryColor,
                showCheckmark: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.transparent,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCookingSkillStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Cooking Experience',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'How would you describe your cooking skills?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ...List.generate(_cookingSkillLevels.length, (index) {
            final skill = _cookingSkillLevels[index];
            return RadioListTile<String>(
              title: Text(skill),
              value: skill,
              groupValue: _selectedSkillLevel,
              onChanged: (value) {
                setState(() {
                  _selectedSkillLevel = value!;
                });
              },
              activeColor: Theme.of(context).primaryColor,
              contentPadding: EdgeInsets.zero,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPrepTimeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Maximum Preparation Time',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'How much time are you willing to spend preparing a meal?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ...List.generate(_prepTimeOptions.length, (index) {
            final minutes = _prepTimeOptions[index];
            String displayText = minutes >= 60
                ? '${minutes ~/ 60} hour${minutes >= 120 ? "s" : ""}'
                : '$minutes minutes';
            return RadioListTile<int>(
              title: Text(displayText),
              value: minutes,
              groupValue: _selectedPrepTime,
              onChanged: (value) {
                setState(() {
                  _selectedPrepTime = value!;
                });
              },
              activeColor: Theme.of(context).primaryColor,
              contentPadding: EdgeInsets.zero,
            );
          }),
        ],
      ),
    );
  }
}
