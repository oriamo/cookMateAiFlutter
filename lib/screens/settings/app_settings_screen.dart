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
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark Mode'),
              trailing: Switch(
                value: false, // TODO: Implement theme provider
                onChanged: (value) {
                  // TODO: Implement theme toggle
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Push Notifications'),
              trailing: Switch(
                value: false, // TODO: Implement notifications provider
                onChanged: (value) {
                  // TODO: Implement notifications toggle
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              trailing:
                  const Text('English'), // TODO: Implement language selection
              onTap: () {
                // TODO: Show language picker
              },
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
