// ============================================================
// rbac_service.dart
// Business logic for Team Management:
//   — Custom role CRUD
//   — User role assignment
//   — Per-user permission override management
// ============================================================

import 'package:flutter/foundation.dart';
import '../services/supabase_data_service.dart';
import 'rbac_models.dart';
import 'permissions.dart';

class RbacService {
  final SupabaseDataService _svc;

  RbacService(this._svc);

  // ── Custom Roles ────────────────────────────────────────────────────────

  Future<List<CustomRole>> getAllRoles() => _svc.getAllCustomRoles();

  Future<CustomRole?> getRoleById(int id) => _svc.getCustomRoleById(id);

  Future<CustomRole> createRole({
    required String name,
    required String description,
    required String color,
    required String icon,
    required List<String> permissions,
    int? createdBy,
  }) async {
    // Validate: name must not collide with a built-in role
    final trimmed = name.trim().toUpperCase();
    if (Roles.getRole(trimmed) != null) {
      throw Exception(
          '"$trimmed" is a reserved system role name. Choose a different name.');
    }
    return _svc.createCustomRole(
      name: trimmed,
      description: description.trim(),
      color: color,
      icon: icon,
      permissions: permissions,
      createdBy: createdBy,
    );
  }

  Future<void> updateRole(int roleId,
      {required String name,
      required String description,
      required String color,
      required String icon,
      required List<String> permissions}) async {
    final role = await _svc.getCustomRoleById(roleId);
    if (role == null) throw Exception('Role not found');
    if (role.isSystem) {
      // System roles: only the permissions can be changed — metadata is locked.
      await _svc.setCustomRolePermissions(roleId, permissions);
    } else {
      await _svc.updateCustomRole(roleId,
          name: name.trim().toUpperCase(),
          description: description.trim(),
          color: color,
          icon: icon,
          permissions: permissions);
    }
  }

  Future<void> deleteRole(int roleId) async {
    final role = await _svc.getCustomRoleById(roleId);
    if (role == null) throw Exception('Role not found');
    if (role.isSystem) throw Exception('System roles cannot be deleted.');
    await _svc.deleteCustomRole(roleId);
  }

  // ── User Role Assignment ─────────────────────────────────────────────────

  Future<UserWithPermissions> getUserWithPermissions(int userId) =>
      _svc.getUserWithPermissions(userId);

  Future<List<CustomRole>> getUserCustomRoles(int userId) =>
      _svc.getUserCustomRoles(userId);

  Future<void> assignRoleToUser(int userId, int customRoleId,
          {int? assignedBy}) =>
      _svc.assignUserCustomRole(userId, customRoleId, assignedBy: assignedBy);

  Future<void> removeRoleFromUser(int userId, int customRoleId) =>
      _svc.removeUserCustomRole(userId, customRoleId);

  Future<void> syncUserCustomRoles(int userId, List<int> customRoleIds,
          {int? assignedBy}) =>
      _svc.setUserCustomRoles(userId, customRoleIds, assignedBy: assignedBy);

  // ── Per-User Permission Overrides ────────────────────────────────────────

  Future<Map<String, bool>> getUserOverridesMap(int userId) =>
      _svc.getUserPermissionOverridesMap(userId);

  Future<void> setOverride({
    required int userId,
    required String permission,
    required bool isGranted,
    String? reason,
    int? setBy,
  }) =>
      _svc.setUserPermissionOverride(
        userId: userId,
        permission: permission,
        isGranted: isGranted,
        reason: reason,
        setBy: setBy,
      );

  Future<void> removeOverride(int userId, String permission) =>
      _svc.removeUserPermissionOverride(userId, permission);

  Future<void> syncAllOverrides(int userId, Map<String, bool> overrideMap,
          {int? setBy}) =>
      _svc.setAllUserPermissionOverrides(userId, overrideMap, setBy: setBy);

  Future<void> clearAllOverrides(int userId) =>
      _svc.clearUserPermissionOverrides(userId);

  // ── Effective permission resolution ─────────────────────────────────────

  /// Builds a PermissionChecker for any user given their ids.
  Future<PermissionChecker> buildCheckerForUser(
      int userId, List<String> roleNames) async {
    try {
      final customPerms = await _svc.getUserCustomRolePermissions(userId);
      final overrideMap = await _svc.getUserPermissionOverridesMap(userId);
      return PermissionChecker(
        roleNames,
        customRolePermissions: customPerms,
        overrides: overrideMap,
      );
    } catch (e) {
      debugPrint('RbacService.buildCheckerForUser error: $e');
      return PermissionChecker(roleNames);
    }
  }
}
