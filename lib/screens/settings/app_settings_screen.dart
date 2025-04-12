import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoPlayVideos = true;
  double _textSize = 1.0; // 1.0 is normal

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance section
          _buildSectionHeader('Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme throughout the app'),
            value: _darkModeEnabled,
            onChanged: (value) {
              setState(() {
                _darkModeEnabled = value;
              });
              // In a real app, you would update a theme provider here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Theme switching would be implemented here')),
              );
            },
          ),

          // Text size slider
          ListTile(
            title: const Text('Text Size'),
            subtitle: const Text('Adjust the size of text in the app'),
            trailing: const Icon(Icons.text_fields),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('A', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Slider(
                    value: _textSize,
                    min: 0.8,
                    max: 1.4,
                    divisions: 6,
                    onChanged: (value) {
                      setState(() {
                        _textSize = value;
                      });
                      // In a real app, you would update a text scaling provider
                    },
                  ),
                ),
                Text('A', style: TextStyle(fontSize: 24)),
              ],
            ),
          ),

          const Divider(),

          // Notifications section
          _buildSectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle:
                const Text('Receive updates about new recipes and features'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
              // In a real app, you would handle notification permissions here
            },
          ),

          const Divider(),

          // Content & Media section
          _buildSectionHeader('Content & Media'),
          SwitchListTile(
            title: const Text('Auto-play Videos'),
            subtitle: const Text('Automatically play videos in recipes'),
            value: _autoPlayVideos,
            onChanged: (value) {
              setState(() {
                _autoPlayVideos = value;
              });
            },
          ),

          const Divider(),

          // About section
          _buildSectionHeader('About'),
          ListTile(
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to privacy policy page
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Would navigate to Privacy Policy')),
              );
            },
          ),
          ListTile(
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to terms of service page
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Would navigate to Terms of Service')),
              );
            },
          ),
          ListTile(
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'),
            trailing: const Icon(Icons.info_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}
