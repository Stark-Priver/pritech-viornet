// ============================================================
// role_editor_screen.dart
// Create or edit a custom role.
// Shows all system permissions grouped by category with
// checkboxes so the Super Admin can pick any combination.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/rbac/rbac_models.dart';
import '../../../core/providers/providers.dart';
import '../../auth/providers/auth_provider.dart';

// Available icon options for the role
const _kIcons = <String, IconData>{
  'person': Icons.person,
  'support_agent': Icons.support_agent,
  'supervisor_account': Icons.supervisor_account,
  'manage_accounts': Icons.manage_accounts,
  'campaign': Icons.campaign,
  'point_of_sale': Icons.point_of_sale,
  'engineering': Icons.engineering,
  'account_balance': Icons.account_balance,
  'inventory': Icons.inventory,
  'business': Icons.business,
  'security': Icons.security,
  'star': Icons.star,
  'lock': Icons.lock,
};

const _kColors = <String>[
  '#6366F1', // Indigo
  '#8B5CF6', // Violet
  '#EC4899', // Pink
  '#EF4444', // Red
  '#F97316', // Orange
  '#F59E0B', // Amber
  '#22C55E', // Green
  '#14B8A6', // Teal
  '#3B82F6', // Blue
  '#06B6D4', // Cyan
  '#A855F7', // Purple
  '#64748B', // Slate
];

class RoleEditorScreen extends ConsumerStatefulWidget {
  final CustomRole? existingRole;
  const RoleEditorScreen({super.key, this.existingRole});

  @override
  ConsumerState<RoleEditorScreen> createState() => _RoleEditorScreenState();
}

class _RoleEditorScreenState extends ConsumerState<RoleEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _selectedColor = _kColors.first;
  String _selectedIcon = 'person';
  final Map<String, bool> _permMap = {};
  bool _saving = false;

  bool get _isEdit => widget.existingRole != null;
  bool get _isSystemRole => _isEdit && widget.existingRole!.isSystem;

  @override
  void initState() {
    super.initState();
    // Pre-populate from existing role
    if (_isEdit) {
      final r = widget.existingRole!;
      _nameCtrl.text = r.name;
      _descCtrl.text = r.description;
      _selectedColor = _kColors.contains(r.color) ? r.color : _kColors.first;
      _selectedIcon = _kIcons.containsKey(r.icon) ? r.icon : 'person';
      for (final p in Permissions.all) {
        _permMap[p.name] = r.permissions.contains(p.name);
      }
    } else {
      for (final p in Permissions.all) {
        _permMap[p.name] = false;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  int get _grantedCount => _permMap.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selColor = _hexColor(_selectedColor);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Role' : 'Create Role'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── System-role banner ───────────────────────────────
            if (_isSystemRole) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline,
                        color: Colors.amber.shade800, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This is a built-in system role. '
                        'Name, description, colour and icon are locked. '
                        'You can only change which permissions it grants.',
                        style: TextStyle(
                            color: Colors.amber.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // ── Name & color header ──────────────────────────────
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Role Details',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameCtrl,
                      readOnly: _isSystemRole,
                      decoration: InputDecoration(
                        labelText: 'Role Name *',
                        hintText: 'e.g. SUPPORT_AGENT',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        prefixIcon:
                            Icon(_kIcons[_selectedIcon], color: selColor),
                        suffixIcon: _isSystemRole
                            ? const Icon(Icons.lock_outline,
                                size: 18, color: Colors.grey)
                            : null,
                        filled: _isSystemRole,
                        fillColor: _isSystemRole ? Colors.grey.shade100 : null,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      style: _isSystemRole
                          ? const TextStyle(color: Colors.grey)
                          : null,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descCtrl,
                      readOnly: _isSystemRole,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'What does this role do?',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: _isSystemRole,
                        fillColor: _isSystemRole ? Colors.grey.shade100 : null,
                      ),
                      maxLines: 2,
                      style: _isSystemRole
                          ? const TextStyle(color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(height: 20),
                    // ── Color picker ───────────────────────────────
                    const Text('Role Color',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 10),
                    IgnorePointer(
                      ignoring: _isSystemRole,
                      child: Opacity(
                        opacity: _isSystemRole ? 0.35 : 1.0,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _kColors
                              .map((hex) => GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedColor = hex),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: _hexColor(hex),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _selectedColor == hex
                                              ? Colors.white
                                              : Colors.transparent,
                                          width: 3,
                                        ),
                                        boxShadow: _selectedColor == hex
                                            ? [
                                                BoxShadow(
                                                  color: _hexColor(hex)
                                                      .withValues(alpha: 0.5),
                                                  blurRadius: 8,
                                                )
                                              ]
                                            : [],
                                      ),
                                      child: _selectedColor == hex
                                          ? const Icon(Icons.check,
                                              color: Colors.white, size: 16)
                                          : null,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ── Icon picker ───────────────────────────────
                    const Text('Role Icon',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 10),
                    IgnorePointer(
                      ignoring: _isSystemRole,
                      child: Opacity(
                        opacity: _isSystemRole ? 0.35 : 1.0,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _kIcons.entries
                              .map((e) => GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedIcon = e.key),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: _selectedIcon == e.key
                                            ? selColor.withValues(alpha: 0.15)
                                            : theme.colorScheme
                                                .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _selectedIcon == e.key
                                              ? selColor
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(e.value,
                                          size: 22,
                                          color: _selectedIcon == e.key
                                              ? selColor
                                              : Colors.grey),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Permissions header ────────────────────────────────
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Permissions',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const Spacer(),
                        Text(
                          '$_grantedCount / ${Permissions.all.length}',
                          style: TextStyle(
                              color: selColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select what this role is allowed to do.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    // Quick select all / none
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            for (final k in _permMap.keys) {
                              _permMap[k] = true;
                            }
                          }),
                          icon: const Icon(Icons.check_box_outlined, size: 16),
                          label: const Text('All'),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            for (final k in _permMap.keys) {
                              _permMap[k] = false;
                            }
                          }),
                          icon: const Icon(
                              Icons.check_box_outline_blank_outlined,
                              size: 16),
                          label: const Text('None'),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Permissions grouped by category ───────────────────
            ...Permissions.grouped.entries.map((entry) {
              final category = entry.key;
              final perms = entry.value;
              final allOn = perms.every((p) => _permMap[p.name] == true);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category header row
                    InkWell(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(14)),
                      onTap: () => setState(() {
                        for (final p in perms) {
                          _permMap[p.name] = !allOn;
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: selColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              category,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const Spacer(),
                            Text(
                              allOn ? 'Deselect all' : 'Select all',
                              style: TextStyle(fontSize: 12, color: selColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ...perms.map((p) => CheckboxListTile(
                          dense: true,
                          activeColor: selColor,
                          title: Text(p.description,
                              style: const TextStyle(fontSize: 14)),
                          subtitle: Text(p.name,
                              style: const TextStyle(
                                  fontSize: 11, fontFamily: 'monospace')),
                          value: _permMap[p.name] ?? false,
                          onChanged: (v) =>
                              setState(() => _permMap[p.name] = v ?? false),
                        )),
                  ],
                ),
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final rbac = ref.read(rbacServiceProvider);
      final auth = ref.read(authProvider);
      final granted =
          _permMap.entries.where((e) => e.value).map((e) => e.key).toList();

      if (_isEdit) {
        await rbac.updateRole(
          widget.existingRole!.id,
          name: _nameCtrl.text.trim().toUpperCase(),
          description: _descCtrl.text.trim(),
          color: _selectedColor,
          icon: _selectedIcon,
          permissions: granted,
        );
      } else {
        await rbac.createRole(
          name: _nameCtrl.text.trim().toUpperCase(),
          description: _descCtrl.text.trim(),
          color: _selectedColor,
          icon: _selectedIcon,
          permissions: granted,
          createdBy: auth.user?.id,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEdit ? 'Role updated' : 'Role created'),
            backgroundColor: Colors.green));
        Navigator.pop(context);
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

Color _hexColor(String hex) {
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return Colors.indigo;
  }
}
