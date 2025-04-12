import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';

class CookingSkillLevelScreen extends ConsumerStatefulWidget {
  const CookingSkillLevelScreen({super.key});

  @override
  ConsumerState<CookingSkillLevelScreen> createState() =>
      _CookingSkillLevelScreenState();
}

class _CookingSkillLevelScreenState
    extends ConsumerState<CookingSkillLevelScreen> {
  late String _selectedSkillLevel;

  final Map<String, Map<String, dynamic>> _skillLevels = {
    'beginner': {
      'title': 'Beginner',
      'description': 'New to cooking, can follow simple recipes',
      'icon': Icons.egg_alt_outlined,
    },
    'intermediate': {
      'title': 'Intermediate',
      'description': 'Comfortable with basic techniques, can adapt recipes',
      'icon': Icons.restaurant_outlined,
    },
    'advanced': {
      'title': 'Advanced',
      'description': 'Skilled cook, can handle complex recipes and techniques',
      'icon': Icons.restaurant_menu,
    },
    'professional': {
      'title': 'Professional',
      'description': 'Professional training, expert in culinary techniques',
      'icon': Icons.stars,
    },
  };

  @override
  void initState() {
    super.initState();
    final userProfile = ref.read(userProfileProvider);
    _selectedSkillLevel = userProfile.cookingSkillLevel;

    // Default to beginner if invalid value
    if (!_skillLevels.containsKey(_selectedSkillLevel)) {
      _selectedSkillLevel = 'beginner';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooking Skill Level'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What\'s your cooking experience?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This helps us recommend recipes appropriate for your skill level.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Skill level selection cards
            ..._skillLevels.entries
                .map((entry) => _buildSkillLevelCard(
                      key: entry.key,
                      title: entry.value['title'],
                      description: entry.value['description'],
                      icon: entry.value['icon'],
                    ))
                .toList(),

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSkillLevel,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Skill Level'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillLevelCard({
    required String key,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedSkillLevel == key;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSkillLevel = key;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color:
                      isSelected ? colorScheme.primary : Colors.grey.shade600,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? colorScheme.primary : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveSkillLevel() async {
    final userNotifier = ref.read(userProfileProvider.notifier);

    await userNotifier.updateProfile(
      cookingSkillLevel: _selectedSkillLevel,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cooking skill level updated')),
      );
      Navigator.of(context).pop();
    }
  }
}
