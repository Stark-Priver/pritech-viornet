// ============================================================
// team_management_screen.dart
// Super Admin — manage users, custom roles, and per-user permissions.
// Tabs:
//   1. Team Members  — user list with role badges + quick actions
//   2. Roles         — built-in + custom roles; create/edit custom
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_models.dart';
import '../../../core/rbac/rbac_models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/widgets/permission_guard.dart';
import '../../auth/providers/auth_provider.dart';
import 'role_editor_screen.dart';
import 'user_permissions_screen.dart';

class TeamManagementScreen extends ConsumerStatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  ConsumerState<TeamManagementScreen> createState() =>
      _TeamManagementScreenState();
}

class _TeamManagementScreenState extends ConsumerState<TeamManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _rebuildKey = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _rebuildKey++);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SuperAdminGuard(
      fallback: const AccessDeniedScreen(
        message: 'Only Super Admins can access Team Management.',
      ),
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          title: const Text('Team Management'),
          centerTitle: false,
          bottom: TabBar(
            controller: _tab,
            tabs: const [
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Members'),
              Tab(icon: Icon(Icons.shield_outlined), text: 'Roles'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tab,
          children: [
            _MembersTab(rebuildKey: _rebuildKey, onRefresh: _refresh),
            _RolesTab(rebuildKey: _rebuildKey, onRefresh: _refresh),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// MEMBERS TAB
// ────────────────────────────────────────────────────────────────────────────
class _MembersTab extends ConsumerWidget {
  final int rebuildKey;
  final VoidCallback onRefresh;

  const _MembersTab({required this.rebuildKey, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(supabaseDataServiceProvider);

    return FutureBuilder<List<AppUser>>(
      key: ValueKey(rebuildKey),
      future: svc.getAllUsers(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final users = snap.data ?? [];
        if (users.isEmpty) {
          return const Center(child: Text('No users found.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (ctx, i) =>
              _UserTile(user: users[i], onChanged: onRefresh),
        );
      },
    );
  }
}

// ── Single user tile ─────────────────────────────────────────────────────
class _UserTile extends ConsumerStatefulWidget {
  final AppUser user;
  final VoidCallback onChanged;

  const _UserTile({required this.user, required this.onChanged});

  @override
  ConsumerState<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends ConsumerState<_UserTile> {
  List<String> _roleNames = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = ref.read(supabaseDataServiceProvider);
    final names = await svc.getUserRoleNames(widget.user.id);
    if (mounted) {
      setState(() {
        _roleNames = names;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final color = _roleColor(u.role);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(
                u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(u.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      _StatusBadge(isActive: u.isActive),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(u.email,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (_loaded) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: _roleNames
                          .map((r) => _RoleBadge(roleName: r))
                          .toList(),
                    ),
                  ] else
                    const SizedBox(
                        height: 20, child: LinearProgressIndicator()),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) => _onAction(v, context),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'permissions',
                    child: Row(children: [
                      Icon(Icons.tune, size: 18),
                      SizedBox(width: 8),
                      Text('Manage Permissions'),
                    ])),
                const PopupMenuItem(
                    value: 'roles',
                    child: Row(children: [
                      Icon(Icons.shield_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Assign Roles'),
                    ])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(String action, BuildContext context) async {
    if (action == 'permissions') {
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => UserPermissionsScreen(user: widget.user)),
      );
      _load();
      widget.onChanged();
    } else if (action == 'roles') {
      await _showRoleAssignmentSheet(context);
      _load();
      widget.onChanged();
    }
  }

  Future<void> _showRoleAssignmentSheet(BuildContext context) async {
    final svc = ref.read(supabaseDataServiceProvider);
    final rbac = ref.read(rbacServiceProvider);

    final allCustomRoles = await rbac.getAllRoles();
    final currentCustomRoles = await svc.getUserCustomRoles(widget.user.id);
    final currentIds = currentCustomRoles.map((r) => r.id).toSet();
    final selected = Set<int>.from(currentIds);

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RoleAssignmentSheet(
        user: widget.user,
        allRoles: allCustomRoles,
        selectedIds: selected,
        onSave: (ids) async {
          final auth = ref.read(authProvider);
          await rbac.syncUserCustomRoles(widget.user.id, ids.toList(),
              assignedBy: auth.user?.id);
        },
      ),
    );
  }

  Color _roleColor(String role) {
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
        return Colors.amber;
      case 'AGENT':
        return Colors.teal;
      default:
        return Colors.indigo;
    }
  }
}

// ── Role assignment bottom sheet ─────────────────────────────────────────
class _RoleAssignmentSheet extends StatefulWidget {
  final AppUser user;
  final List<CustomRole> allRoles;
  final Set<int> selectedIds;
  final Future<void> Function(Set<int>) onSave;

  const _RoleAssignmentSheet({
    required this.user,
    required this.allRoles,
    required this.selectedIds,
    required this.onSave,
  });

  @override
  State<_RoleAssignmentSheet> createState() => _RoleAssignmentSheetState();
}

class _RoleAssignmentSheetState extends State<_RoleAssignmentSheet> {
  late Set<int> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Assign Roles to ${widget.user.name}',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 4),
            const Text('Select which roles this user should have.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: ctrl,
                children: widget.allRoles.map((role) {
                  final roleColor = _hexColor(role.color);
                  return CheckboxListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    secondary: CircleAvatar(
                      backgroundColor: roleColor.withValues(alpha: 0.12),
                      child: Icon(_iconData(role.icon),
                          color: roleColor, size: 20),
                    ),
                    title: Text(role.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: role.description.isNotEmpty
                        ? Text(role.description,
                            style: const TextStyle(fontSize: 12))
                        : null,
                    value: _selected.contains(role.id),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(role.id);
                        } else {
                          _selected.remove(role.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Assignments'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_selected);
      if (mounted) Navigator.pop(context);
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
// ROLES TAB
// ────────────────────────────────────────────────────────────────────────────
class _RolesTab extends ConsumerWidget {
  final int rebuildKey;
  final VoidCallback onRefresh;

  const _RolesTab({required this.rebuildKey, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rbac = ref.watch(rbacServiceProvider);

    return FutureBuilder<List<CustomRole>>(
      key: ValueKey(rebuildKey),
      future: rbac.getAllRoles(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final roles = snap.data ?? [];

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: roles.length,
            itemBuilder: (ctx, i) =>
                _RoleTile(role: roles[i], onChanged: onRefresh),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoleEditorScreen()),
              );
              onRefresh();
            },
            icon: const Icon(Icons.add),
            label: const Text('New Role'),
          ),
        );
      },
    );
  }
}

// ── Single role tile ─────────────────────────────────────────────────────
class _RoleTile extends ConsumerWidget {
  final CustomRole role;
  final VoidCallback onChanged;

  const _RoleTile({required this.role, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _hexColor(role.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.13),
          child: Icon(_iconData(role.icon), color: color),
        ),
        title: Row(
          children: [
            Text(role.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (role.isSystem)
              _Badge(label: 'System', color: Colors.grey.shade700),
            if (!role.isActive) _Badge(label: 'Inactive', color: Colors.red),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (role.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(role.description, style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 4),
            Text('${role.permissions.length} permission(s)',
                style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
        isThreeLine: true,
        trailing: role.isSystem
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Role actions',
                onSelected: (v) => _onAction(v, context, ref),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.tune, size: 18),
                        SizedBox(width: 8),
                        Text('Edit Permissions'),
                      ])),
                ],
              )
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) => _onAction(v, context, ref),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ])),
                  PopupMenuItem(
                      value: 'toggle',
                      child: Row(children: [
                        Icon(
                          role.isActive
                              ? Icons.toggle_off_outlined
                              : Icons.toggle_on_outlined,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(role.isActive ? 'Deactivate' : 'Activate'),
                      ])),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ])),
                ],
              ),
      ),
    );
  }

  Future<void> _onAction(
      String action, BuildContext context, WidgetRef ref) async {
    final rbac = ref.read(rbacServiceProvider);
    switch (action) {
      case 'edit':
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => RoleEditorScreen(existingRole: role)),
        );
        onChanged();
        break;
      case 'toggle':
        await rbac.getAllRoles(); // ensure loaded
        await ref
            .read(supabaseDataServiceProvider)
            .toggleCustomRoleStatus(role.id, !role.isActive);
        onChanged();
        break;
      case 'delete':
        final ok = await _confirmDelete(context);
        if (ok != true) return;
        try {
          await rbac.deleteRole(role.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Role deleted'), backgroundColor: Colors.green));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$e'), backgroundColor: Colors.red));
          }
        }
        onChanged();
        break;
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Role'),
          content: Text(
              'Delete "${role.name}"? Users assigned this role will lose its permissions.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete')),
          ],
        ),
      );
}

// ────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: (isActive ? Colors.green : Colors.red).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String roleName;
  const _RoleBadge({required this.roleName});

  @override
  Widget build(BuildContext context) {
    final color = _roleColorFor(roleName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(roleName,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  static Color _roleColorFor(String role) {
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

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

Color _hexColor(String hex) {
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
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
