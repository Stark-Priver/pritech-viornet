import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../database/database.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  final String currentRoute;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  final List<NavigationItem> _navigationItems = [
    NavigationItem(icon: Icons.dashboard, label: 'Dashboard', route: '/'),
    NavigationItem(icon: Icons.people, label: 'Clients', route: '/clients'),
    NavigationItem(
      icon: Icons.confirmation_number,
      label: 'Vouchers',
      route: '/vouchers',
    ),
    NavigationItem(
      icon: Icons.card_giftcard,
      label: 'Packages',
      route: '/packages',
    ),
    NavigationItem(icon: Icons.point_of_sale, label: 'POS', route: '/pos'),
    NavigationItem(icon: Icons.receipt_long, label: 'Sales', route: '/sales'),
    NavigationItem(icon: Icons.location_on, label: 'Sites', route: '/sites'),
    NavigationItem(icon: Icons.devices, label: 'Assets', route: '/assets'),
    NavigationItem(
      icon: Icons.build,
      label: 'Maintenance',
      route: '/maintenance',
    ),
    NavigationItem(
      icon: Icons.attach_money,
      label: 'Finance',
      route: '/finance',
    ),
    NavigationItem(icon: Icons.sms, label: 'SMS', route: '/sms'),
    NavigationItem(icon: Icons.settings, label: 'Settings', route: '/settings'),
  ];

  int get _selectedIndex {
    final index = _navigationItems.indexWhere(
      (item) => item.route == widget.currentRoute,
    );
    return index >= 0 ? index : 0;
  }

  void _onNavigationTap(int index) {
    if (index < _navigationItems.length) {
      context.go(_navigationItems[index].route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getPageTitle()),
        leading: isDesktop
            ? null
            : (context.canPop()
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  )
                : null),
        actions: [
          // Sync Button
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync feature coming soon')),
              );
            },
            tooltip: 'Sync Data',
          ),
          // Notifications
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon')),
              );
            },
          ),
          // User Profile
          PopupMenuButton(
            icon: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                user.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            itemBuilder: (context) => <PopupMenuEntry>[
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(user.role, style: const TextStyle(fontSize: 12)),
                    Text(user.email, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              } else if (value == 'settings') {
                context.go('/settings');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isDesktop ? null : _buildDrawer(context, user, isTablet),
      body: Row(
        children: [
          // Desktop Sidebar
          if (isDesktop)
            Container(
              width: 250,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: _buildNavigationRail(user),
            ),
          // Main Content
          Expanded(
            child: widget.child,
          ),
        ],
      ),
      // Bottom Navigation for Mobile & Tablet
      bottomNavigationBar:
          isDesktop ? null : _buildBottomNavigation(context, isTablet),
    );
  }

  String _getPageTitle() {
    final item = _navigationItems.firstWhere(
      (item) => item.route == widget.currentRoute,
      orElse: () => _navigationItems[0],
    );
    return item.label;
  }

  Widget _buildNavigationRail(User user) {
    return Column(
      children: [
        // User Info
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  user.name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                user.role,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        const Divider(),
        // Navigation Items
        Expanded(
          child: ListView.builder(
            itemCount: _navigationItems.length,
            itemBuilder: (context, index) {
              final item = _navigationItems[index];
              final isSelected = _selectedIndex == index;
              return ListTile(
                leading: Icon(
                  item.icon,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey[700],
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[700],
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                onTap: () => _onNavigationTap(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, User user, bool isTablet) {
    return Drawer(
      width: isTablet ? 300 : null,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.wifi, size: 48, color: Colors.white),
                const SizedBox(height: 8),
                const Text(
                  'ViorNet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  user.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  user.role,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _navigationItems.length,
              itemBuilder: (context, index) {
                final item = _navigationItems[index];
                final isSelected = _selectedIndex == index;
                return ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  selected: isSelected,
                  onTap: () {
                    _onNavigationTap(index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context, bool isTablet) {
    // For mobile, show only primary items
    final primaryItems = [
      _navigationItems[0], // Dashboard
      _navigationItems[1], // Clients
      _navigationItems[3], // POS
      _navigationItems[4], // Sales
      _navigationItems[10], // Settings
    ];

    final currentIndex = primaryItems.indexWhere(
      (item) => item.route == widget.currentRoute,
    );

    return BottomNavigationBar(
      currentIndex: currentIndex >= 0 ? currentIndex : 0,
      type: BottomNavigationBarType.fixed,
      selectedFontSize: isTablet ? 14 : 12,
      unselectedFontSize: isTablet ? 12 : 10,
      iconSize: isTablet ? 28 : 24,
      onTap: (index) {
        context.go(primaryItems[index].route);
      },
      items: primaryItems
          .map(
            (item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.label,
            ),
          )
          .toList(),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final String route;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
