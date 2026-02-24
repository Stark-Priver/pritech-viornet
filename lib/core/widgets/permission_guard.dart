// ============================================================
// permission_guard.dart
// Reusable widgets that show/hide UI based on RBAC.
//
// Usage:
//   PermissionGuard(
//     permission: Permissions.deleteClient,
//     child: DeleteButton(),
//   )
//
//   RoleGuard(
//     roles: ['SUPER_ADMIN', 'ADMIN'],
//     child: AdminOnlyPanel(),
//   )
//
//   SuperAdminGuard(child: DangerZone())
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../rbac/permissions.dart';
import '../../features/auth/providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// PermissionGuard
// Shows [child] only if the logged-in user has [permission].
// Renders [fallback] (default: empty SizedBox) when access is denied.
// ---------------------------------------------------------------------------
class PermissionGuard extends ConsumerWidget {
  final Permission permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final checker = PermissionChecker(
      auth.userRoles,
      customRolePermissions: auth.customRolePermissions,
      overrides: auth.permissionOverrides,
    );
    if (checker.hasPermission(permission)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// RoleGuard
// Shows [child] only if the user has AT LEAST ONE of [roles].
// ---------------------------------------------------------------------------
class RoleGuard extends ConsumerWidget {
  final List<String> roles;
  final Widget child;
  final Widget? fallback;

  const RoleGuard({
    super.key,
    required this.roles,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final hasRole = auth.userRoles.any((r) => roles.contains(r));
    if (hasRole) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// SuperAdminGuard
// Convenience wrapper — visible only to SUPER_ADMIN.
// ---------------------------------------------------------------------------
class SuperAdminGuard extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;

  const SuperAdminGuard({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.userRoles.contains('SUPER_ADMIN')) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// AccessDeniedScreen
// Full-screen error when a route is accessed without permission.
// ---------------------------------------------------------------------------
class AccessDeniedScreen extends StatelessWidget {
  final String? message;
  const AccessDeniedScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(Icons.lock_outline_rounded,
                    size: 40, color: Colors.red.shade400),
              ),
              const SizedBox(height: 24),
              Text(
                'Access Denied',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message ??
                    'You do not have permission to view this page.\n'
                        'Contact your administrator.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
