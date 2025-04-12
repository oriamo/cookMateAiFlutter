import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/user_provider.dart';
import '../models/user_profile.dart';
import 'settings/edit_profile_screen.dart';
import 'settings/dietary_preferences_screen.dart';
import 'settings/cooking_skill_level_screen.dart';
import 'settings/measurement_units_screen.dart';
import 'settings/app_settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
    final userNotifier = ref.read(userProfileProvider.notifier);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with profile header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Profile image
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          image: DecorationImage(
                            image: NetworkImage(
                              userProfile.avatarUrl ??
                                  'https://via.placeholder.com/150',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // User name
                      Text(
                        userProfile.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      // User email
                      Text(
                        userProfile.email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              titlePadding: EdgeInsets.zero,
            ),
          ),

          // Stats section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn(
                    context,
                    'Favorites',
                    userProfile.favoriteRecipes.length.toString(),
                    Icons.favorite,
                  ),
                  _buildStatColumn(
                    context,
                    'Searches',
                    userProfile.recentSearches.length.toString(),
                    Icons.search,
                  ),
                  _buildStatColumn(
                    context,
                    'Saved',
                    '0',
                    Icons.bookmark,
                  ),
                ],
              ),
            ),
          ),

          // Settings options
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingTile(
                    context,
                    'Edit Profile',
                    Icons.person_outline,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingTile(
                    context,
                    'Dietary Preferences',
                    Icons.food_bank_outlined,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const DietaryPreferencesScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingTile(
                    context,
                    'Favorite Recipes',
                    Icons.favorite_outline,
                    () {
                      context.push('/favorites');
                    },
                  ),
                  _buildSettingTile(
                    context,
                    'Cooking Skill Level',
                    Icons.sports_score_outlined,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CookingSkillLevelScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingTile(
                    context,
                    'Measurement Units',
                    Icons.scale_outlined,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MeasurementUnitsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingTile(
                    context,
                    'App Settings',
                    Icons.settings_outlined,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AppSettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Recent Activity section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (userProfile.recentSearches.isEmpty)
                    Center(
                      child: Text(
                        'No recent activity',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    )
                  else
                    Column(
                      children:
                          userProfile.recentSearches.take(5).map((search) {
                        return _buildActivityTile(
                          context,
                          'Searched for "$search"',
                          Icons.search,
                          Colors.blue.shade100,
                          Colors.blue,
                          () {
                            context.go('/search', extra: search);
                          },
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),

          // Logout button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => _showLogoutConfirmation(context, userNotifier),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red.shade400,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Logout'),
              ),
            ),
          ),

          // Extra padding at the bottom
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
      BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: Border(
        bottom: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildActivityTile(
    BuildContext context,
    String title,
    IconData icon,
    Color iconBgColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconBgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14),
      ),
      trailing: Text(
        'Just now',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: Border(
        bottom: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showLogoutConfirmation(
      BuildContext context, UserProfileNotifier userNotifier) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                userNotifier.logout();
                Navigator.of(context).pop();
                context.go('/login');
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}
