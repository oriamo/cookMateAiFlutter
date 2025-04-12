import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';

class CookingSkillLevelScreen extends ConsumerStatefulWidget {
  final bool isOnboarding;
  final bool isInCoordinator;
  final VoidCallback? onComplete;

  const CookingSkillLevelScreen({
    super.key,
    this.isOnboarding = false,
    this.isInCoordinator = false,
    this.onComplete,
  });

  @override
  CookingSkillLevelScreenState createState() => CookingSkillLevelScreenState();
}

// Changed from _CookingSkillLevelScreenState to public CookingSkillLevelScreenState
class CookingSkillLevelScreenState
    extends ConsumerState<CookingSkillLevelScreen> {
  late String _selectedSkillLevel;

  final List<Map<String, dynamic>> _skillLevels = [
    {
      'name': 'Beginner',
      'icon': Icons.egg_alt,
      'color': Colors.green,
      'description': 'I can follow basic recipes and make simple dishes',
    },
    {
      'name': 'Intermediate',
      'icon': Icons.soup_kitchen,
      'color': Colors.blue,
      'description':
          'I cook regularly and can handle moderately complex recipes',
    },
    {
      'name': 'Advanced',
      'icon': Icons.restaurant,
      'color': Colors.orange,
      'description':
          'I\'m comfortable with complex techniques and can improvise recipes',
    },
    {
      'name': 'Professional',
      'icon': Icons.food_bank,
      'color': Colors.red,
      'description':
          'I have professional cooking experience or formal training',
    },
  ];

  @override
  void initState() {
    super.initState();
    final userProfile = ref.read(userProfileProvider);
    _selectedSkillLevel = userProfile.cookingSkillLevel;
  }

  // Method to expose the selected skill level to parent
  String getSelectedSkillLevel() {
    return _selectedSkillLevel;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooking Skill Level'),
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
          // Progress Indicator
          if (widget.isOnboarding)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  ...List.generate(
                    5,
                    (index) => Expanded(
                      child: Container(
                        height: 8,
                        color: index < 5 ? Colors.green : Colors.grey.shade300,
                      ),
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
                  const Text(
                    'What\'s your cooking experience?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'We\'ll adjust recipe recommendations based on your skill level.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Skill level cards
                  ...buildSkillLevelCards(),

                  const SizedBox(height: 24),

                  // Tips based on selected skill level
                  if (_selectedSkillLevel.isNotEmpty) buildSkillTips(),
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
                onPressed: _saveSkillLevel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  widget.isOnboarding ? 'Finish' : 'Save Preference',
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

  List<Widget> buildSkillLevelCards() {
    return _skillLevels.map((level) {
      final bool isSelected = _selectedSkillLevel == level['name'];

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedSkillLevel = level['name'];
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
                    backgroundColor: level['color'].withOpacity(0.2),
                    radius: 24,
                    child: Icon(
                      level['icon'],
                      color: level['color'],
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
                          level['name'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          level['description'],
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

  Widget buildSkillTips() {
    // Tips for each skill level
    Map<String, List<String>> tips = {
      'Beginner': [
        'We\'ll focus on simple recipes with clear instructions',
        'Recipes will include detailed step-by-step guidance',
        'You\'ll see more quick meals with fewer ingredients'
      ],
      'Intermediate': [
        'You\'ll see recipes with more varied techniques',
        'We\'ll include more ethnic cuisines and flavor combinations',
        'Recipes will assume basic cooking knowledge'
      ],
      'Advanced': [
        'You\'ll see more complex recipes with room for creativity',
        'We\'ll include recipes with advanced techniques',
        'Instructions will be more concise with fewer basics explained'
      ],
      'Professional': [
        'You\'ll see chef-inspired recipes and techniques',
        'We\'ll include more challenging ingredients and methods',
        'Recipes will focus on precision and presentation'
      ]
    };

    final currentTips = tips[_selectedSkillLevel] ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates,
                color: Colors.amber.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'What this means for you:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...currentTips.map((tip) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _saveSkillLevel() async {
    final userNotifier = ref.read(userProfileProvider.notifier);

    await userNotifier.updateProfile(
      cookingSkillLevel: _selectedSkillLevel,
    );

    if (mounted) {
      if (widget.isOnboarding && widget.onComplete != null) {
        widget.onComplete!();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cooking skill level saved')),
        );
        Navigator.of(context).pop();
      }
    }
  }
}
