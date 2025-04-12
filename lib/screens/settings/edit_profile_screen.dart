import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _avatarUrlController;

  @override
  void initState() {
    super.initState();
    final userProfile = ref.read(userProfileProvider);
    _nameController = TextEditingController(text: userProfile.name);
    _emailController = TextEditingController(text: userProfile.email);
    _avatarUrlController = TextEditingController(text: userProfile.avatarUrl);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar image preview
            GestureDetector(
              onTap: () {
                // In a real app, you would implement image picker here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Image picker would open here')),
                );
              },
              child: CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(
                  _avatarUrlController.text.isNotEmpty
                      ? _avatarUrlController.text
                      : 'https://via.placeholder.com/100',
                ),
                backgroundColor: Colors.grey.shade200,
                child: _avatarUrlController.text.isEmpty
                    ? Icon(
                        Icons.add_a_photo,
                        size: 30,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            // Name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Email field
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Avatar URL field
            TextField(
              controller: _avatarUrlController,
              decoration: const InputDecoration(
                labelText: 'Avatar URL',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
                helperText: 'Enter a URL for your profile picture',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveProfile() async {
    final userNotifier = ref.read(userProfileProvider.notifier);

    await userNotifier.updateProfile(
      name: _nameController.text,
      email: _emailController.text,
      avatarUrl: _avatarUrlController.text,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.of(context).pop();
    }
  }
}
