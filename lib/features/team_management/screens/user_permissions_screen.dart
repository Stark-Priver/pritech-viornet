// ============================================================
// user_permissions_screen.dart
// Per-user permission management screen.
// Super Admin can:
//   • Assign/remove custom roles for a specific user
//   • Explicitly GRANT or DENY individual permissions
//     overriding role defaults
// Shows resolved "effective permissions" in real time.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_models.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/rbac/rbac_models.dart';
import '../../../core/providers/providers.dart';
import '../../auth/providers/auth_provider.dart';

class UserPermissionsScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const UserPermissionsScreen({super.key, required this.user});

  @override
  ConsumerState<UserPermissionsScreen> createState() =>
      _UserPermissionsScreenState();
}

class _UserPermissionsScreenState extends ConsumerState<UserPermissionsScreen> {
  UserWithPermissions? _data;
  List<CustomRole> _allRoles = [];
  bool _loading = true;
  bool _saving = false;

  // Local state for overrides being edited
  Map<String, bool> _overrides = {};
  Set<int> _customRoleIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rbac = ref.read(rbacServiceProvider);
      final data = await rbac.getUserWithPermissions(widget.user.id);
      final allRoles = await rbac.getAllRoles();
      if (mounted) {
        setState(() {
          _data = data;
          _allRoles = allRoles;
          _overrides = {
            for (final o in data.overrides) o.permission: o.isGranted
          };
          _customRoleIds = data.customRoles.map((r) => r.id).toSet();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Compute effective permissions with current local state
  Set<String> get _effective {
    final roleNames = _data?.roleNames ?? [];
    final customPerms = _allRoles
        .where((r) => _customRoleIds.contains(r.id))
        .expand((r) => r.permissions)
        .toSet();
    final checker = PermissionChecker(
      roleNames,
      customRolePermissions: customPerms,
      overrides: _overrides,
    );
    return checker.effectivePermissions;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.user.name,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text('Permission Overrides',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── User summary card ──────────────────────────────
                _UserSummaryCard(
                  user: widget.user,
                  roleNames: _data?.roleNames ?? [],
                ),
                const SizedBox(height: 16),

                // ── Custom Role Assignment ─────────────────────────
                _SectionCard(
                  title: 'Custom Roles',
                  subtitle: 'Roles created by Super Admin',
                  icon: Icons.shield_outlined,
                  child: _allRoles.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                              'No custom roles yet. Create one in Team Management.',
                              style: TextStyle(color: Colors.grey)),
                        )
                      : Column(
                          children: _allRoles.map((role) {
                            final roleColor = _hexColor(role.color);
                            final isAssigned = _customRoleIds.contains(role.id);
                            return SwitchListTile(
                              secondary: CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    roleColor.withValues(alpha: 0.12),
                                child: Icon(_iconData(role.icon),
                                    color: roleColor, size: 18),
                              ),
                              title: Text(role.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              subtitle: role.description.isNotEmpty
                                  ? Text(role.description,
                                      style: const TextStyle(fontSize: 12))
                                  : null,
                              value: isAssigned,
                              activeThumbColor: roleColor,
                              onChanged: (v) {
                                setState(() {
                                  if (v) {
                                    _customRoleIds.add(role.id);
                                  } else {
                                    _customRoleIds.remove(role.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 16),

                // ── Effective permissions preview ──────────────────
                _SectionCard(
                  title: 'Effective Permissions Preview',
                  subtitle:
                      '${_effective.length} of ${Permissions.all.length} permissions currently active',
                  icon: Icons.visibility_outlined,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: Permissions.all.map((p) {
                        final active = _effective.contains(p.name);
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? Colors.green.withValues(alpha: 0.5)
                                  : Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            p.description,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: active ? Colors.green : Colors.grey,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Per-permission overrides ───────────────────────
                _SectionCard(
                  title: 'Permission Overrides',
                  subtitle: 'Explicitly GRANT or DENY individual permissions. '
                      'Overrides take priority over roles.',
                  icon: Icons.tune_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Legend
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            _LegendDot(
                                color: Colors.green, label: 'Explicit Grant'),
                            const SizedBox(width: 16),
                            _LegendDot(
                                color: Colors.red, label: 'Explicit Deny'),
                            const SizedBox(width: 16),
                            _LegendDot(color: Colors.grey, label: 'From Role'),
                          ],
                        ),
                      ),
                      // Clear all button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _overrides.clear()),
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Clear All Overrides'),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Permission rows grouped by category
                      ...Permissions.grouped.entries
                          .map((entry) => _PermissionCategorySection(
                                category: entry.key,
                                permissions: entry.value,
                                overrides: _overrides,
                                effectivePerms: _effective,
                                onChanged: (pName, val) {
                                  setState(() {
                                    if (val == null) {
                                      _overrides.remove(pName);
                                    } else {
                                      _overrides[pName] = val;
                                    }
                                  });
                                },
                              )),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final rbac = ref.read(rbacServiceProvider);
      final auth = ref.read(authProvider);

      // Save custom role assignments
      await rbac.syncUserCustomRoles(
        widget.user.id,
        _customRoleIds.toList(),
        assignedBy: auth.user?.id,
      );

      // Save permission overrides
      await rbac.syncAllOverrides(
        widget.user.id,
        _overrides,
        setBy: auth.user?.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Permissions saved successfully'),
            backgroundColor: Colors.green));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ────────────────────────────────────────────────────────────────────────────

class _UserSummaryCard extends StatelessWidget {
  final AppUser user;
  final List<String> roleNames;

  const _UserSummaryCard({required this.user, required this.roleNames});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.indigo.withValues(alpha: 0.12),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(user.email,
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: roleNames
                        .map((r) => _MiniChip(label: r, color: _roleColor(r)))
                        .toList(),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: user.isActive
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: user.isActive ? Colors.green : Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _roleColor(String role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return Colors.red;
      case 'ADMIN':
        return Colors.orange;
      case 'MARKETING':
        return Colors.purple;
      case 'SALES':
        return Colors.green;
      case 'TECHNICAL':
        return Colors.blue;
      case 'FINANCE':
        return Colors.amber.shade800;
      case 'AGENT':
        return Colors.teal;
      default:
        return Colors.indigo;
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.indigo),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(subtitle,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PermissionCategorySection extends StatelessWidget {
  final String category;
  final List<Permission> permissions;
  final Map<String, bool> overrides;
  final Set<String> effectivePerms;
  final void Function(String permission, bool? value) onChanged;

  const _PermissionCategorySection({
    required this.category,
    required this.permissions,
    required this.overrides,
    required this.effectivePerms,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(category.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.grey)),
        ),
        ...permissions.map((p) {
          final override = overrides[p.name];
          final effectivelyGranted = effectivePerms.contains(p.name);

          Color rowColor;
          IconData trailingIcon;

          if (override == true) {
            rowColor = Colors.green;
            trailingIcon = Icons.add_circle_outline;
          } else if (override == false) {
            rowColor = Colors.red;
            trailingIcon = Icons.remove_circle_outline;
          } else {
            rowColor = effectivelyGranted ? Colors.blue : Colors.grey;
            trailingIcon = effectivelyGranted
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked;
          }

          return ListTile(
            dense: true,
            title: Text(p.description,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: override != null
                        ? FontWeight.w700
                        : FontWeight.normal)),
            subtitle: Text(p.name,
                style: const TextStyle(
                    fontSize: 10, fontFamily: 'monospace', color: Colors.grey)),
            leading: Icon(trailingIcon, color: rowColor, size: 20),
            trailing: _OverridePopup(
              permissionName: p.name,
              currentOverride: override,
              onChanged: (v) => onChanged(p.name, v),
            ),
          );
        }),
        const Divider(height: 8),
      ],
    );
  }
}

/// 3-state dropdown: Grant / Deny / From Role (clear override)
class _OverridePopup extends StatelessWidget {
  final String permissionName;
  final bool? currentOverride; // null = no override
  final void Function(bool? value) onChanged;

  const _OverridePopup({
    required this.permissionName,
    required this.currentOverride,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Color c;
    String label;
    if (currentOverride == true) {
      c = Colors.green;
      label = 'Grant';
    } else if (currentOverride == false) {
      c = Colors.red;
      label = 'Deny';
    } else {
      c = Colors.grey;
      label = 'Default';
    }

    return PopupMenuButton<String>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: c)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 14, color: c),
          ],
        ),
      ),
      onSelected: (v) {
        if (v == 'grant') {
          onChanged(true);
        } else if (v == 'deny') {
          onChanged(false);
        } else {
          onChanged(null);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'grant',
            child: Row(children: [
              Icon(Icons.add_circle_outline, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Text('Explicit Grant',
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.w600)),
            ])),
        const PopupMenuItem(
            value: 'deny',
            child: Row(children: [
              Icon(Icons.remove_circle_outline, color: Colors.red, size: 16),
              SizedBox(width: 8),
              Text('Explicit Deny',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600)),
            ])),
        const PopupMenuItem(
            value: 'default',
            child: Row(children: [
              Icon(Icons.undo, color: Colors.grey, size: 16),
              SizedBox(width: 8),
              Text('Use Role Default', style: TextStyle(color: Colors.grey)),
            ])),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Helper functions
// ────────────────────────────────────────────────────────────────────────────

Color _hexColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return Colors.indigo;
  }
}

IconData _iconData(String name) {
  const map = {
    'admin_panel_settings': Icons.admin_panel_settings,
    'manage_accounts': Icons.manage_accounts,
    'campaign': Icons.campaign,
    'point_of_sale': Icons.point_of_sale,
    'engineering': Icons.engineering,
    'account_balance': Icons.account_balance,
    'person': Icons.person,
    'inventory': Icons.inventory,
    'business': Icons.business,
    'star': Icons.star,
    'lock': Icons.lock,
    'security': Icons.security,
    'support_agent': Icons.support_agent,
    'supervisor_account': Icons.supervisor_account,
  };
  return map[name] ?? Icons.shield_outlined;
}
