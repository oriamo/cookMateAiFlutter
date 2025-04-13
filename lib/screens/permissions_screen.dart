import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsScreen extends StatelessWidget {
  final VoidCallback onPermissionsGranted;

  const PermissionsScreen({
    Key? key,
    required this.onPermissionsGranted,
  }) : super(key: key);

  Future<void> _requestPermissions() async {
    final micStatus = await Permission.microphone.request();
    final cameraStatus = await Permission.camera.request();

    if (micStatus.isGranted && cameraStatus.isGranted) {
      onPermissionsGranted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Required Permissions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'CookMate needs access to:',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Microphone'),
                subtitle: const Text('For voice commands and recipe dictation'),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                subtitle: const Text(
                    'For scanning ingredients and taking food photos'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _requestPermissions,
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Text(
                    'Grant Permissions',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
