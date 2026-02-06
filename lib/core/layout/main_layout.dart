import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../database/database.dart';
import '../rbac/permissions.dart';
import '../providers/providers.dart';

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
  bool _isSyncing = false;

  List<NavigationItem> _getFilteredNavigationItems() {
    final authState = ref.watch(authProvider);
    final userRoles = authState.userRoles;

    // If no roles, provide minimum access (Dashboard and Settings)
    if (userRoles.isEmpty) {
      return [
        NavigationItem(icon: Icons.dashboard, label: 'Dashboard', route: '/'),
        NavigationItem(
            icon: Icons.settings, label: 'Settings', route: '/settings'),
      ];
    }

    final checker = PermissionChecker(userRoles);

    final filteredItems = _allNavigationItems
        .where((item) => checker.canAccessRoute(item.route))
        .toList();

    // Ensure minimum items even with roles
    if (filteredItems.length < 2) {
      return [
        NavigationItem(icon: Icons.dashboard, label: 'Dashboard', route: '/'),
        NavigationItem(
            icon: Icons.settings, label: 'Settings', route: '/settings'),
      ];
    }

    return filteredItems;
  }

  final List<NavigationItem> _allNavigationItems = [
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

  int _getSelectedIndex(List<NavigationItem> items) {
    final index = items.indexWhere(
      (item) => item.route == widget.currentRoute,
    );
    return index >= 0 ? index : 0;
  }

  void _onNavigationTap(List<NavigationItem> items, int index) {
    if (index < items.length) {
      context.go(items[index].route);
    }
  }

  Future<void> _handleSyncToCloud() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final supabaseService = ref.read(supabaseSyncServiceProvider);

      // Show syncing dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Syncing with cloud...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Perform bidirectional sync
      final result = await supabaseService.syncAll();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result.errors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync complete: Pushed ${result.pushed}, Pulled ${result.pulled}${result.conflicts > 0 ? ', ${result.conflicts} conflicts resolved' : ''}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Sync completed with errors: ${result.errors.join(', ')}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
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

    final navigationItems = _getFilteredNavigationItems();
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getPageTitle(navigationItems)),
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
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload),
            onPressed: _isSyncing ? null : _handleSyncToCloud,
            tooltip: 'Sync to Cloud',
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
                    Text(
                      authState.userRoles.join(', '),
                      style: const TextStyle(fontSize: 12),
                    ),
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
      drawer: isDesktop
          ? null
          : _buildDrawer(context, user, navigationItems, isTablet),
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
              child: _buildNavigationRail(user, navigationItems),
            ),
          // Main Content
          Expanded(
            child: widget.child,
          ),
        ],
      ),
      // Bottom Navigation for Mobile & Tablet
      bottomNavigationBar: isDesktop
          ? null
          : _buildBottomNavigation(context, navigationItems, isTablet),
    );
  }

  String _getPageTitle(List<NavigationItem> items) {
    final item = items.firstWhere(
      (item) => item.route == widget.currentRoute,
      orElse: () => items.isNotEmpty
          ? items[0]
          : NavigationItem(
              icon: Icons.dashboard, label: 'Dashboard', route: '/'),
    );
    return item.label;
  }

  Widget _buildNavigationRail(User user, List<NavigationItem> items) {
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
              Consumer(
                builder: (context, ref, child) {
                  final roles = ref.watch(authProvider).userRoles;
                  return Text(
                    roles.join(', '),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(),
        // Navigation Items
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = _getSelectedIndex(items) == index;
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
                onTap: () => _onNavigationTap(items, index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, User user,
      List<NavigationItem> items, bool isTablet) {
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
                Consumer(
                  builder: (context, ref, child) {
                    final roles = ref.watch(authProvider).userRoles;
                    return Text(
                      roles.join(', '),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = _getSelectedIndex(items) == index;
                return ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  selected: isSelected,
                  onTap: () {
                    _onNavigationTap(items, index);
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

  Widget _buildBottomNavigation(
      BuildContext context, List<NavigationItem> items, bool isTablet) {
    // For mobile, show only primary items that user has access to
    final primaryRoutes = ['/', '/clients', '/pos', '/sales', '/settings'];
    List<NavigationItem> primaryItems =
        items.where((item) => primaryRoutes.contains(item.route)).toList();

    if (primaryItems.isEmpty && items.isNotEmpty) {
      // If no primary items available, show first 5 items user can access
      final availableItems = items.length > 5 ? items.sublist(0, 5) : items;
      primaryItems = availableItems;
    }

    // BottomNavigationBar requires at least 2 items
    if (primaryItems.length < 2) {
      // Fallback: ensure minimum 2 items from all navigation or use defaults
      if (items.length >= 2) {
        primaryItems = items.take(2).toList();
      } else {
        // Use default minimum navigation items as fallback
        primaryItems = [
          NavigationItem(icon: Icons.dashboard, label: 'Dashboard', route: '/'),
          NavigationItem(
              icon: Icons.settings, label: 'Settings', route: '/settings'),
        ];
      }
    }

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
        if (index < primaryItems.length) {
          context.go(primaryItems[index].route);
        }
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
