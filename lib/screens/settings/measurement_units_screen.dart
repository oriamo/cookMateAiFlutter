import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';

class MeasurementUnitsScreen extends ConsumerStatefulWidget {
  const MeasurementUnitsScreen({super.key});

  @override
  ConsumerState<MeasurementUnitsScreen> createState() =>
      _MeasurementUnitsScreenState();
}

class _MeasurementUnitsScreenState
    extends ConsumerState<MeasurementUnitsScreen> {
  late String _selectedUnit;

  final Map<String, Map<String, String>> _unitOptions = {
    'metric': {
      'title': 'Metric',
      'description': 'Grams, milliliters, centimeters (used globally)',
    },
    'imperial': {
      'title': 'Imperial',
      'description': 'Pounds, ounces, cups (common in the US)',
    },
  };

  @override
  void initState() {
    super.initState();
    final userProfile = ref.read(userProfileProvider);
    _selectedUnit = userProfile.measurementUnit;

    // Default to metric if invalid value
    if (!_unitOptions.containsKey(_selectedUnit)) {
      _selectedUnit = 'metric';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Measurement Units'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose your preferred measurement units',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Recipe ingredients will be displayed using your selected system',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Unit selection radio buttons
            ..._unitOptions.entries.map((entry) {
              return RadioListTile<String>(
                title: Text(
                  entry.value['title']!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(entry.value['description']!),
                value: entry.key,
                groupValue: _selectedUnit,
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedUnit = value;
                    });
                  }
                },
              );
            }).toList(),

            const Spacer(),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveMeasurementUnit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Preference'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveMeasurementUnit() async {
    final userNotifier = ref.read(userProfileProvider.notifier);

    await userNotifier.updateMeasurementUnit(_selectedUnit);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Measurement units updated')),
      );
      Navigator.of(context).pop();
    }
  }
}
