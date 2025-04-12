import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _maxPrepTimeController;
  String _selectedSkillLevel = 'beginner';
  String _selectedMeasurementUnit = 'metric';
  File? _imageFile;
  bool _isLoading = false;

  final List<String> _skillLevels = ['beginner', 'intermediate', 'advanced'];
  final List<String> _measurementUnits = ['metric', 'imperial'];

  @override
  void initState() {
    super.initState();
    final userProfile = ref.read(userProfileProvider);
    _nameController = TextEditingController(text: userProfile.name);
    _emailController = TextEditingController(text: userProfile.email);
    _maxPrepTimeController =
        TextEditingController(text: userProfile.maxPrepTimeMinutes.toString());
    _selectedSkillLevel = userProfile.cookingSkillLevel;
    _selectedMeasurementUnit = userProfile.measurementUnit;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _maxPrepTimeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // In a real app, you would upload the image to storage
        // and get a URL back, but for now we'll keep it simple
        String? avatarUrl;
        if (_imageFile != null) {
          // Verify the file exists before using its path
          if (await _imageFile!.exists()) {
            // This would be replaced with actual image upload logic
            // avatarUrl = await uploadImage(_imageFile!);
            avatarUrl = _imageFile!.path; // Just for demo purposes
          } else {
            throw Exception('Selected image file does not exist');
          }
        }

        final maxPrepTimeMinutes =
            int.tryParse(_maxPrepTimeController.text) ?? 60;

        await ref.read(userProfileProvider.notifier).updateProfile(
              name: _nameController.text,
              email: _emailController.text,
              avatarUrl: avatarUrl,
              cookingSkillLevel: _selectedSkillLevel,
              measurementUnit: _selectedMeasurementUnit,
              maxPrepTimeMinutes: maxPrepTimeMinutes,
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = 'Error updating profile';
          if (e is Exception) {
            errorMessage = e.toString().replaceAll('Exception: ', '');
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor:
                                theme.colorScheme.primary.withOpacity(0.1),
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!) as ImageProvider
                                : (userProfile.avatarUrl.isNotEmpty
                                    ? NetworkImage(userProfile.avatarUrl)
                                    : null),
                            child: userProfile.avatarUrl.isEmpty &&
                                    _imageFile == null
                                ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                ),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Personal Information',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Cooking Preferences',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedSkillLevel,
                      decoration: const InputDecoration(
                        labelText: 'Cooking Skill Level',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.restaurant),
                      ),
                      items: _skillLevels
                          .map((level) => DropdownMenuItem(
                                value: level,
                                child: Text(level.capitalize()),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedSkillLevel = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedMeasurementUnit,
                      decoration: const InputDecoration(
                        labelText: 'Measurement Unit',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      items: _measurementUnits
                          .map((unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit.capitalize()),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedMeasurementUnit = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _maxPrepTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Maximum Preparation Time (minutes)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter maximum preparation time';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _saveProfile,
                        child: const Text('Save Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
