import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _roleFilter = 'ALL';
  int _rebuildKey = 0;

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _roleFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'ALL', child: Text('All Roles')),
              const PopupMenuItem(
                  value: 'SUPER_ADMIN', child: Text('Super Admin')),
              const PopupMenuItem(value: 'MARKETING', child: Text('Marketing')),
              const PopupMenuItem(value: 'SALES', child: Text('Sales')),
              const PopupMenuItem(value: 'TECHNICAL', child: Text('Technical')),
              const PopupMenuItem(value: 'FINANCE', child: Text('Finance')),
              const PopupMenuItem(value: 'AGENT', child: Text('Agent')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<User>>(
        key: ValueKey(_rebuildKey),
        future: _getFilteredUsers(database),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return const Center(child: Text('No users found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              return _buildUserCard(context, users[index], database);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(context, database),
        icon: const Icon(Icons.add),
        label: const Text('Add User'),
      ),
    );
  }

  Future<List<User>> _getFilteredUsers(AppDatabase database) async {
    final query = database.select(database.users);

    if (_roleFilter != 'ALL') {
      query.where((tbl) => tbl.role.equals(_roleFilter));
    }

    return await query.get();
  }

  Widget _buildUserCard(BuildContext context, User user, AppDatabase database) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.2),
          child: Icon(
            _getRoleIcon(user.role),
            color: _getRoleColor(user.role),
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(user.email),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatRole(user.role),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(user.role),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (user.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(Icons.toggle_on, size: 20),
                  SizedBox(width: 8),
                  Text('Toggle Status'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'password',
              child: Row(
                children: [
                  Icon(Icons.lock, size: 20),
                  SizedBox(width: 8),
                  Text('Reset Password'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditUserDialog(context, user, database);
            } else if (value == 'toggle') {
              _toggleUserStatus(user, database);
            } else if (value == 'password') {
              _showResetPasswordDialog(context, user, database);
            }
          },
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return Colors.red;
      case 'MARKETING':
        return Colors.purple;
      case 'SALES':
        return Colors.green;
      case 'TECHNICAL':
        return Colors.blue;
      case 'FINANCE':
        return Colors.orange;
      case 'AGENT':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return Icons.admin_panel_settings;
      case 'MARKETING':
        return Icons.campaign;
      case 'SALES':
        return Icons.point_of_sale;
      case 'TECHNICAL':
        return Icons.engineering;
      case 'FINANCE':
        return Icons.account_balance;
      case 'AGENT':
        return Icons.person;
      default:
        return Icons.person;
    }
  }

  String _formatRole(String role) {
    return role.replaceAll('_', ' ');
  }

  void _showAddUserDialog(BuildContext context, AppDatabase database) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'AGENT';
    bool isActive = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Add New User',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Full Name *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Enter full name',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Email *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      hintText: 'user@example.com',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Phone',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      hintText: '+255 XXX XXX XXX',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Password *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      hintText: 'Enter password',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Role *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: [
                      'SUPER_ADMIN',
                      'MARKETING',
                      'SALES',
                      'TECHNICAL',
                      'FINANCE',
                      'AGENT'
                    ].map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Row(
                          children: [
                            Icon(
                              _getRoleIcon(r),
                              size: 20,
                              color: _getRoleColor(r),
                            ),
                            const SizedBox(width: 12),
                            Text(_formatRole(r)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => role = value!);
                    },
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        'Active Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isActive ? 'User is active' : 'User is inactive',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      value: isActive,
                      onChanged: (value) {
                        setDialogState(() {
                          isActive = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    emailController.text.isEmpty ||
                    passwordController.text.isEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(context);

                // Hash password
                final hashedPassword = sha256
                    .convert(utf8.encode(passwordController.text))
                    .toString();

                await database.into(database.users).insert(
                      UsersCompanion.insert(
                        name: nameController.text,
                        email: emailController.text,
                        phone: drift.Value(phoneController.text),
                        passwordHash: hashedPassword,
                        role: role,
                        isActive: drift.Value(isActive),
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );

                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 12),
                        const Text('User added successfully'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                setState(() {
                  _rebuildKey++;
                });
              },
              child: const Text('Add User'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(
    BuildContext context,
    User user,
    AppDatabase database,
  ) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    final phoneController = TextEditingController(text: user.phone);
    String role = user.role;
    bool isActive = user.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Edit User',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Full Name *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Email *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Phone',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Role *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: [
                      'SUPER_ADMIN',
                      'MARKETING',
                      'SALES',
                      'TECHNICAL',
                      'FINANCE',
                      'AGENT'
                    ].map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Row(
                          children: [
                            Icon(
                              _getRoleIcon(r),
                              size: 20,
                              color: _getRoleColor(r),
                            ),
                            const SizedBox(width: 12),
                            Text(_formatRole(r)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => role = value!);
                    },
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        'Active Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isActive ? 'User is active' : 'User is inactive',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      value: isActive,
                      onChanged: (value) {
                        setDialogState(() {
                          isActive = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    emailController.text.isEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(context);

                await (database.update(database.users)
                      ..where((tbl) => tbl.id.equals(user.id)))
                    .write(
                  UsersCompanion(
                    name: drift.Value(nameController.text),
                    email: drift.Value(emailController.text),
                    phone: drift.Value(phoneController.text),
                    role: drift.Value(role),
                    isActive: drift.Value(isActive),
                    updatedAt: drift.Value(DateTime.now()),
                  ),
                );

                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 12),
                        const Text('User updated successfully'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                setState(() {
                  _rebuildKey++;
                });
              },
              child: const Text('Update User'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleUserStatus(User user, AppDatabase database) async {
    final messenger = ScaffoldMessenger.of(context);

    await (database.update(database.users)
          ..where((tbl) => tbl.id.equals(user.id)))
        .write(
      UsersCompanion(
        isActive: drift.Value(!user.isActive),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          user.isActive
              ? 'User deactivated successfully'
              : 'User activated successfully',
        ),
        backgroundColor: Colors.green,
      ),
    );
    setState(() {
      _rebuildKey++;
    });
  }

  void _showResetPasswordDialog(
    BuildContext context,
    User user,
    AppDatabase database,
  ) {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Reset Password',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reset password for ${user.name}'),
            const SizedBox(height: 20),
            const Text(
              'New Password *',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                hintText: 'Enter new password',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            const Text(
              'Confirm Password *',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmPasswordController,
              decoration: InputDecoration(
                hintText: 'Confirm password',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (passwordController.text.isEmpty ||
                  confirmPasswordController.text.isEmpty) {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (passwordController.text != confirmPasswordController.text) {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Passwords do not match'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);

              // Hash password
              final hashedPassword = sha256
                  .convert(utf8.encode(passwordController.text))
                  .toString();

              await (database.update(database.users)
                    ..where((tbl) => tbl.id.equals(user.id)))
                  .write(
                UsersCompanion(
                  passwordHash: drift.Value(hashedPassword),
                  updatedAt: drift.Value(DateTime.now()),
                ),
              );

              nav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      const Text('Password reset successfully'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
  }
}
