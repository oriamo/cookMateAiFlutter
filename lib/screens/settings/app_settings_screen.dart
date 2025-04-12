import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            ListTile(
              title: const Text('Dark Mode'),
              trailing: Switch(
                value: false,
                onChanged: (value) {
                  // Theme switching to be implemented
                },
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Notifications'),
              trailing: Switch(
                value: true,
                onChanged: (value) {
                  // Notification settings to be implemented
                },
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('About'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Show about dialog
                showAboutDialog(
                  context: context,
                  applicationName: 'CookMate AI',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2025 CookMate AI',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
