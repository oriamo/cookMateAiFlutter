import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';

class HealthGoalsScreen extends ConsumerStatefulWidget {
  final bool isInCoordinator;
  final VoidCallback? onComplete;

  const HealthGoalsScreen({
    super.key,
    this.isInCoordinator = false,
    this.onComplete,
  });

  @override
  HealthGoalsScreenState createState() => HealthGoalsScreenState();
}

// Changed from _HealthGoalsScreenState to public HealthGoalsScreenState
class HealthGoalsScreenState extends ConsumerState<HealthGoalsScreen> {
  List<String> _selectedHealthGoals = [];

  final List<Map<String, dynamic>> _healthGoalOptions = [
    {
      'name': 'Weight Loss',
      'icon': Icons.fitness_center,
      'color': Colors.blue,
      'image': 'assets/images/weight_loss.png',
    },
    {
      'name': 'Muscle Gain',
      'icon': Icons.sports_gymnastics,
      'color': Colors.red,
      'image': 'assets/images/muscle_gain.png',
    },
    {
      'name': 'Heart Health',
      'icon': Icons.favorite,
      'color': Colors.pink,
      'image': 'assets/images/heart_health.png',
    },
    {
      'name': 'Energy Boost',
      'icon': Icons.bolt,
      'color': Colors.amber,
      'image': 'assets/images/energy_boost.png',
    },
    {
      'name': 'Better Sleep',
      'icon': Icons.nightlight_round,
      'color': Colors.indigo,
      'image': 'assets/images/better_sleep.png',
    },
    {
      'name': 'Diabetes Management',
      'icon': Icons.monitor_heart,
      'color': Colors.teal,
      'image': 'assets/images/diabetes_management.png',
    },
    {
      'name': 'Reduce Inflammation',
      'icon': Icons.healing,
      'color': Colors.orange,
      'image': 'assets/images/reduce_inflammation.png',
    },
    {
      'name': 'Digestion Health',
      'icon': Icons.spa,
      'color': Colors.green,
      'image': 'assets/images/digestion_health.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    final userProfile = ref.read(userProfileProvider);
    _selectedHealthGoals = List<String>.from(userProfile.healthGoals);
  }

  // Add this method to expose the selected health goals to the parent
  List<String> getSelectedHealthGoals() {
    return _selectedHealthGoals;
  }

  @override
  Widget build(BuildContext context) {
    return widget.isInCoordinator
        ? _buildContent()
        : Scaffold(
            appBar: AppBar(
              title: const Text('Health Goals'),
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
                    'What are your health goals?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'We\'ll recommend recipes that align with your health objectives.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildHealthGoalsGrid(),
                ],
              ),
            ),
          ),
        ),
        // Only show the save button when not in coordinator
        if (!widget.isInCoordinator) _buildSaveButton(),
      ],
    );
  }

  Widget _buildHealthGoalsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _healthGoalOptions.length,
      itemBuilder: (context, index) {
        final option = _healthGoalOptions[index];
        final bool isSelected = _selectedHealthGoals.contains(option['name']);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedHealthGoals.remove(option['name']);
              } else {
                _selectedHealthGoals.add(option['name']);
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
        onPressed: _saveHealthGoals,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'Save Health Goals',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _saveHealthGoals() async {
    // Save health goals to user profile
    final userNotifier = ref.read(userProfileProvider.notifier);
    final currentProfile = ref.read(userProfileProvider);

    await userNotifier.updateProfile(
      name: currentProfile.name,
      email: currentProfile.email,
      cookingSkillLevel: currentProfile.cookingSkillLevel,
      measurementUnit: currentProfile.measurementUnit,
      maxPrepTimeMinutes: currentProfile.maxPrepTimeMinutes,
      healthGoals: _selectedHealthGoals,
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
