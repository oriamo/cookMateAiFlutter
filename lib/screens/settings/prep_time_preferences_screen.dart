import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';

class PrepTimePreferencesScreen extends ConsumerStatefulWidget {
  final bool isOnboarding;
  final VoidCallback? onComplete;

  const PrepTimePreferencesScreen({
    super.key,
    this.isOnboarding = false,
    this.onComplete,
  });

  @override
  ConsumerState<PrepTimePreferencesScreen> createState() =>
      _PrepTimePreferencesScreenState();
}

class _PrepTimePreferencesScreenState
    extends ConsumerState<PrepTimePreferencesScreen> {
  late int _maxPrepTimeMinutes;

  final List<Map<String, dynamic>> _prepTimeOptions = [
    {
      'value': 15,
      'label': '15 minutes or less',
      'description': 'Quick and easy recipes only'
    },
    {
      'value': 30,
      'label': '30 minutes or less',
      'description': 'Fast recipes with a bit more complexity'
    },
    {
      'value': 45,
      'label': '45 minutes or less',
      'description': 'Medium-length cooking time'
    },
    {
      'value': 60,
      'label': '1 hour or less',
      'description': 'More involved recipes'
    },
    {
      'value': 120,
      'label': '2 hours or less',
      'description': 'Complex recipes and slow-cooking dishes'
    },
    {
      'value': 999,
      'label': 'Any duration',
      'description': 'No time restrictions'
    },
  ];

  @override
  void initState() {
    super.initState();
    final userProfile = ref.read(userProfileProvider);
    _maxPrepTimeMinutes = userProfile.maxPrepTimeMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: widget.isOnboarding
          ? AppBar(
              title: const Text('Preparation Time'),
              automaticallyImplyLeading: false,
            )
          : AppBar(
              title: const Text('Preparation Time'),
            ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How much time do you want to spend cooking?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This helps us recommend recipes that fit your schedule.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: _prepTimeOptions.length,
                itemBuilder: (context, index) {
                  final option = _prepTimeOptions[index];
                  final isSelected = _maxPrepTimeMinutes == option['value'];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: isSelected ? 4 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _maxPrepTimeMinutes = option['value'];
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option['label'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? colorScheme.primary
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    option['description'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savePrepTimePreference,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(widget.isOnboarding ? 'Next' : 'Save Preference'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _savePrepTimePreference() async {
    final userNotifier = ref.read(userProfileProvider.notifier);

    await userNotifier.updateMaxPrepTime(_maxPrepTimeMinutes);

    if (mounted) {
      if (widget.isOnboarding && widget.onComplete != null) {
        widget.onComplete!();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preparation time preference updated')),
        );
        Navigator.of(context).pop();
      }
    }
  }
}
