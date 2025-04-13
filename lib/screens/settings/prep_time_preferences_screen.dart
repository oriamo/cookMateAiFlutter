import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';

class PrepTimePreferencesScreen extends ConsumerStatefulWidget {
  final bool isOnboarding;
  final bool isInCoordinator;
  final VoidCallback? onComplete;

  const PrepTimePreferencesScreen({
    super.key,
    this.isOnboarding = false,
    this.isInCoordinator = false,
    this.onComplete,
  });

  @override
  PrepTimePreferencesScreenState createState() =>
      PrepTimePreferencesScreenState();
}

// Public state class for external access
class PrepTimePreferencesScreenState
    extends ConsumerState<PrepTimePreferencesScreen> {
  late int _maxPrepTimeMinutes;

  final List<Map<String, dynamic>> _prepTimeOptions = [
    {
      'value': 15,
      'icon': Icons.timer,
      'color': Colors.green,
      'label': '15 minutes or less',
      'description': 'Quick and easy recipes only'
    },
    {
      'value': 30,
      'icon': Icons.timer_3,
      'color': Colors.blue,
      'label': '30 minutes or less',
      'description': 'Fast recipes with a bit more complexity'
    },
    {
      'value': 45,
      'icon': Icons.hourglass_bottom,
      'color': Colors.amber,
      'label': '45 minutes or less',
      'description': 'Medium-length cooking time'
    },
    {
      'value': 60,
      'icon': Icons.hourglass_top,
      'color': Colors.orange,
      'label': '1 hour or less',
      'description': 'More involved recipes'
    },
    {
      'value': 120,
      'icon': Icons.schedule,
      'color': Colors.red,
      'label': '2 hours or less',
      'description': 'Complex recipes and slow-cooking dishes'
    },
    {
      'value': 999,
      'icon': Icons.all_inclusive,
      'color': Colors.purple,
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

  // Method to expose the selected prep time to parent
  int getSelectedPrepTime() {
    return _maxPrepTimeMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return widget.isInCoordinator
        ? _buildContent()
        : Scaffold(
            appBar: AppBar(
              title: const Text('Preparation Time'),
              automaticallyImplyLeading: !widget.isOnboarding,
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              actions: [
                if (widget.isOnboarding)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
            body: _buildContent(),
          );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Progress Indicator - only show when NOT in coordinator
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
                    color: Colors.green,
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
                  'How much time do you want to spend cooking?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This helps us recommend recipes that fit your schedule.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),

                // Prep time options
                ...buildPrepTimeCards(),
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
              onPressed: _savePrepTimePreference,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                widget.isOnboarding ? 'Continue' : 'Save Preference',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> buildPrepTimeCards() {
    return _prepTimeOptions.map((option) {
      final bool isSelected = _maxPrepTimeMinutes == option['value'];

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: () {
            setState(() {
              _maxPrepTimeMinutes = option['value'];
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
                    backgroundColor: option['color'].withOpacity(0.2),
                    radius: 24,
                    child: Icon(
                      option['icon'],
                      color: option['color'],
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
                          option['label'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
