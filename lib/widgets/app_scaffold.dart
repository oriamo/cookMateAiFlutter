import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(BuildContext context, int index) {
    if (index == _calculateSelectedIndex(context)) return;
    
    _animationController.reset();
    _animationController.forward();
    
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/explore');
        break;
      case 2:
        context.go('/search');
        break;
      case 3:
        context.go('/ai-chat');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/')) {
      if (location == '/') return 0;
      if (location.startsWith('/explore')) return 1;
      if (location.startsWith('/search')) return 2;
      if (location.startsWith('/ai-chat')) return 3;
      if (location.startsWith('/profile')) return 4;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);
    
    return Scaffold(
      body: SafeArea(
        child: widget.child,
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 20 * (1 - _animationController.value)),
            child: Opacity(
              opacity: _animationController.value,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: BottomNavigationBar(
                    type: BottomNavigationBarType.fixed,
                    selectedItemColor: Theme.of(context).colorScheme.primary,
                    unselectedItemColor: Colors.grey.shade600,
                    showUnselectedLabels: true,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home_outlined),
                        activeIcon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.explore_outlined),
                        activeIcon: Icon(Icons.explore),
                        label: 'Explore',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.search_outlined),
                        activeIcon: Icon(Icons.search),
                        label: 'Search',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.chat_bubble_outline),
                        activeIcon: Icon(Icons.chat_bubble),
                        label: 'AI Chat',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.person_outline),
                        activeIcon: Icon(Icons.person),
                        label: 'Profile',
                      ),
                    ],
                    currentIndex: currentIndex,
                    onTap: (index) => _onItemTapped(context, index),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}