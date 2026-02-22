import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/rbac/permissions.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final roles = {
      ...authState.userRoles,
      if (authState.user != null) authState.user!.role,
    }.toList();
    final checker = PermissionChecker(roles);

    final isAdminLevel = checker.hasAnyRole(['ADMIN', 'SUPER_ADMIN']);
    final canManageUsers = isAdminLevel;
    final canManagePackages = isAdminLevel || checker.hasAnyRole(['TECHNICAL']);
    final canManageCommissions =
        isAdminLevel || checker.hasAnyRole(['FINANCE']);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Account ────────────────────────────────────────────────────
          _sectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile Settings'),
            subtitle: Text(
              authState.user?.name ?? '',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon(context, 'Profile Settings'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon(context, 'Change Password'),
          ),

          // ── Administration ─────────────────────────────────────────────
          if (canManageUsers || canManagePackages || canManageCommissions)
            ..._adminSection(
              context,
              canManageUsers: canManageUsers,
              canManagePackages: canManagePackages,
              canManageCommissions: canManageCommissions,
            ),

          // ── System ─────────────────────────────────────────────────────
          if (isAdminLevel) ..._systemSection(context),

          // ── General ────────────────────────────────────────────────────
          _sectionHeader('General'),
          const ListTile(
            leading: Icon(Icons.notifications_outlined),
            title: Text('Notifications'),
            trailing: Icon(Icons.chevron_right),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Colors.grey,
          ),
        ),
      );

  List<Widget> _adminSection(
    BuildContext context, {
    required bool canManageUsers,
    required bool canManagePackages,
    required bool canManageCommissions,
  }) =>
      [
        _sectionHeader('Administration'),
        if (canManageUsers)
          ListTile(
            leading: const Icon(Icons.manage_accounts),
            title: const Text('User Management'),
            subtitle: const Text('Manage team members and roles'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/users'),
          ),
        if (canManagePackages)
          ListTile(
            leading: const Icon(Icons.card_giftcard_outlined),
            title: const Text('Package Management'),
            subtitle: const Text('View and manage service packages'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/packages'),
          ),
        if (canManageCommissions) ...[
          ListTile(
            leading: const Icon(Icons.percent),
            title: const Text('Commission Settings'),
            subtitle: const Text('Configure agent commissions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/commissions'),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Commission Demands'),
            subtitle: const Text('Review and pay agent commission requests'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/commission-demands'),
          ),
        ],
      ];

  List<Widget> _systemSection(BuildContext context) => [
        _sectionHeader('System'),
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('Sync Settings'),
          subtitle: const Text('Data synchronisation options'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showComingSoon(context, 'Sync Settings'),
        ),
      ];

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon')),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About ViorNet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ViorNet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text('WiFi Reseller & ISP Management System'),
            const SizedBox(height: 16),
            const Text('Version: 1.0.0'),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Developed and Maintained by',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'PRITECHVIOR',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Pritech Vior Softech',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
