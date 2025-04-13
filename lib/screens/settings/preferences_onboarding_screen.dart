import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import 'dietary_preferences_screen.dart';
import 'cooking_skill_level_screen.dart';
import 'health_goals_screen.dart';
import 'prep_time_preferences_screen.dart'; // Add this if it exists

class PreferencesOnboardingScreen extends ConsumerStatefulWidget {
  const PreferencesOnboardingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PreferencesOnboardingScreen> createState() =>
      _PreferencesOnboardingScreenState();
}

class _PreferencesOnboardingScreenState
    extends ConsumerState<PreferencesOnboardingScreen> {
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Health goals
  List<String> _selectedHealthGoals = [];

  // Dietary preferences
  List<String> _selectedDietaryPreferences = [];

  // Cooking skill level
  String _selectedSkillLevel = 'Beginner';

  // Max prep time (in minutes)
  int _selectedPrepTime = 60;

  // Reference keys to access child screens
  final GlobalKey<HealthGoalsScreenState> _healthGoalsKey =
      GlobalKey<HealthGoalsScreenState>();
  final GlobalKey<DietaryRestrictionsScreenState> _dietaryKey =
      GlobalKey<DietaryRestrictionsScreenState>();
  final GlobalKey<CookingSkillLevelScreenState> _skillLevelKey =
      GlobalKey<CookingSkillLevelScreenState>();
  final GlobalKey<PrepTimePreferencesScreenState> _prepTimeKey =
      GlobalKey<PrepTimePreferencesScreenState>();

  void _nextStep() {
    // Save the data from the current screen before moving to the next one
    _saveCurrentStepData();

    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _completeOnboarding();
    }
  }

  void _saveCurrentStepData() {
    switch (_currentStep) {
      case 0: // Health Goals
        if (_healthGoalsKey.currentState != null) {
          setState(() {
            _selectedHealthGoals =
                _healthGoalsKey.currentState!.getSelectedHealthGoals();
          });
        }
        break;
      case 1: // Dietary Preferences
        if (_dietaryKey.currentState != null) {
          setState(() {
            _selectedDietaryPreferences =
                _dietaryKey.currentState!.getSelectedRestrictions();
          });
        }
        break;
      case 2: // Cooking Skill Level
        if (_skillLevelKey.currentState != null) {
          setState(() {
            _selectedSkillLevel =
                _skillLevelKey.currentState!.getSelectedSkillLevel();
          });
        }
        break;
      case 3: // Max Prep Time
        if (_prepTimeKey.currentState != null) {
          setState(() {
            _selectedPrepTime =
                _prepTimeKey.currentState!.getSelectedPrepTime();
          });
        }
        break;
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
      cookingSkillLevel: _selectedSkillLevel.toLowerCase(),
      maxPrepTimeMinutes: _selectedPrepTime,
    );

    // Mark onboarding as complete
    await userProfileNotifier.completeOnboarding();

    // Navigate to the home page
    if (mounted) {
      if (context.mounted) {
        context.go('/');
      }
    }
  }

  // Callback functions to receive data from child screens
  void _updateHealthGoals(List<String> healthGoals) {
    setState(() {
      _selectedHealthGoals = healthGoals;
    });
  }

  void _updateDietaryPreferences(List<String> dietaryPreferences) {
    setState(() {
      _selectedDietaryPreferences = dietaryPreferences;
    });
  }

  void _updateCookingSkill(String skillLevel) {
    setState(() {
      _selectedSkillLevel = skillLevel;
    });
  }

  void _updatePrepTime(int prepTime) {
    setState(() {
      _selectedPrepTime = prepTime;
    });
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: Colors.grey[300],
            valueColor:
                AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            minHeight: 6.0,
          ),
        ),
        elevation: 0, // Remove shadow to avoid visual gap
      ),
      body: Column(
        children: [
          // Progress percentage text
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
        return HealthGoalsScreen(
          key: _healthGoalsKey,
          isInCoordinator: true,
        );
      case 1:
        return DietaryPreferenceScreen(
          key: _dietaryKey,
          isOnboarding: true,
          isInCoordinator: true,
        );
      case 2:
        return CookingSkillLevelScreen(
          key: _skillLevelKey,
          isOnboarding: true,
          isInCoordinator: true,
        );
      case 3:
        return PrepTimePreferencesScreen(
          key: _prepTimeKey,
          isOnboarding: true,
          isInCoordinator: true,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
