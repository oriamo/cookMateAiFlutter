import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';

class MeasurementUnitsScreen extends ConsumerStatefulWidget {
  final bool isOnboarding;
  final VoidCallback? onComplete;

  const MeasurementUnitsScreen({
    super.key,
    this.isOnboarding = false,
    this.onComplete,
  });

  @override
  ConsumerState<MeasurementUnitsScreen> createState() =>
      _MeasurementUnitsScreenState();
}

class _MeasurementUnitsScreenState
    extends ConsumerState<MeasurementUnitsScreen> {
  late String _selectedMeasurementSystem;

  final List<Map<String, dynamic>> _measurementSystems = [
    {
      'name': 'Metric',
      'icon': Icons.straighten,
      'color': Colors.blue,
      'description': 'Grams, kilograms, milliliters, liters, °C',
    },
    {
      'name': 'Imperial',
      'icon': Icons.scale,
      'color': Colors.red,
      'description': 'Ounces, pounds, fluid ounces, cups, °F',
    },
    {
      'name': 'Mixed',
      'icon': Icons.balance,
      'color': Colors.purple,
      'description':
          'Grams for small measures, pounds for weight, cups for volume',
    },
  ];

  @override
  void initState() {
    super.initState();
    final userProfile = ref.read(userProfileProvider);
    _selectedMeasurementSystem = userProfile.measurementUnit;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Measurement Units'),
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
      body: Column(
        children: [
          // Progress Indicator
          if (widget.isOnboarding)
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
                  ...List.generate(
                    2,
                    (index) => Expanded(
                      child: Container(
                        height: 8,
                        color: Colors.grey.shade300,
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
                    'Choose your measurement system',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This will determine how measurements are displayed in recipes.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Measurement system cards
                  ...buildMeasurementSystemCards(),

                  const SizedBox(height: 32),

                  // Example display
                  if (_selectedMeasurementSystem.isNotEmpty)
                    buildExampleMeasurements(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Continue button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _saveMeasurementSystem,
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
      ),
    );
  }

  List<Widget> buildMeasurementSystemCards() {
    return _measurementSystems.map((system) {
      final bool isSelected = _selectedMeasurementSystem == system['name'];

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedMeasurementSystem = system['name'];
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
                    backgroundColor: system['color'].withOpacity(0.2),
                    radius: 24,
                    child: Icon(
                      system['icon'],
                      color: system['color'],
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
                          system['name'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          system['description'],
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

  Widget buildExampleMeasurements() {
    Map<String, List<String>> examples = {
      'Metric': [
        '250g flour',
        '100ml milk',
        '180°C oven temperature',
        '500g chicken breast',
      ],
      'Imperial': [
        '2 cups flour',
        '1/3 cup milk',
        '350°F oven temperature',
        '1 lb chicken breast',
      ],
      'Mixed': [
        '250g flour',
        '1/3 cup milk',
        '350°F oven temperature',
        '1 lb chicken breast',
      ],
    };

    final currentExamples = examples[_selectedMeasurementSystem] ?? [];

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
          const Text(
            'Example measurements:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...currentExamples.map((example) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.arrow_right,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      example,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _saveMeasurementSystem() async {
    final userNotifier = ref.read(userProfileProvider.notifier);

    await userNotifier.updateProfile(
      measurementUnit: _selectedMeasurementSystem,
    );

    if (mounted) {
      if (widget.isOnboarding && widget.onComplete != null) {
        widget.onComplete!();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Measurement system saved')),
        );
        Navigator.of(context).pop();
      }
    }
  }
}
