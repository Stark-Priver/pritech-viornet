// ============================================================
// supabase_data_service.dart
// Direct Supabase PostgreSQL data layer.
// Replaces the Drift/SQLite AppDatabase entirely.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/app_models.dart';
import '../rbac/rbac_models.dart';

/// Central data service – all reads/writes go through Supabase.
/// Use the service-role key (set in main.dart) to bypass RLS.
class SupabaseDataService {
  static final SupabaseDataService _instance = SupabaseDataService._internal();
  factory SupabaseDataService() => _instance;
  SupabaseDataService._internal();

  final _uuid = const Uuid();

  SupabaseClient get _client => Supabase.instance.client;

  /// Initialise Supabase once. Call from main() before runApp().
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseServiceKey,
  }) async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseServiceKey, // service-role key bypasses RLS
    );
    debugPrint('✅ Supabase initialised (online-only mode)');
  }

  // =========================================================================
  // USERS
  // =========================================================================

  Future<List<AppUser>> getAllUsers() async {
    final data = await _client.from('users').select().order('name');
    return (data as List).map((e) => AppUser.fromJson(e)).toList();
  }

  Future<List<AppUser>> getUsersByRole(String role) async {
    final data =
        await _client.from('users').select().eq('role', role).order('name');
    return (data as List).map((e) => AppUser.fromJson(e)).toList();
  }

  Future<AppUser?> getUserById(int id) async {
    final data =
        await _client.from('users').select().eq('id', id).maybeSingle();
    return data != null ? AppUser.fromJson(data) : null;
  }

  Future<AppUser?> getUserByEmail(String email) async {
    final data =
        await _client.from('users').select().eq('email', email).maybeSingle();
    return data != null ? AppUser.fromJson(data) : null;
  }

  /// Login: match email OR phone + passwordHash.
  Future<AppUser?> loginUser(String emailOrPhone, String passwordHash) async {
    // Try email first
    var data = await _client
        .from('users')
        .select()
        .eq('email', emailOrPhone)
        .eq('password_hash', passwordHash)
        .eq('is_active', true)
        .maybeSingle();

    // If not found by email, try phone
    data ??= await _client
        .from('users')
        .select()
        .eq('phone', emailOrPhone)
        .eq('password_hash', passwordHash)
        .eq('is_active', true)
        .maybeSingle();
    return data != null ? AppUser.fromJson(data) : null;
  }

  /// Create a new user. Returns the created AppUser.
  Future<AppUser> createUser({
    required String name,
    required String email,
    required String passwordHash,
    required String role,
    String? phone,
  }) async {
    final data = await _client
        .from('users')
        .insert({
          'server_id': _uuid.v4(),
          'name': name,
          'email': email,
          'phone': phone,
          'role': role,
          'password_hash': passwordHash,
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return AppUser.fromJson(data);
  }

  Future<bool> updateUser(int id, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toIso8601String();
    final result = await _client.from('users').update(fields).eq('id', id);
    return result != null;
  }

  Future<void> deleteUser(int id) async {
    await _client.from('users').delete().eq('id', id);
  }

  // User roles
  Future<List<String>> getUserRoleNames(int userId) async {
    final data = await _client
        .from('user_roles')
        .select('roles(name)')
        .eq('user_id', userId);
    return (data as List).map((e) => e['roles']['name'] as String).toList();
  }

  Future<List<int>> getUserSiteIds(int userId) async {
    final data = await _client
        .from('user_sites')
        .select('site_id')
        .eq('user_id', userId);
    return (data as List).map((e) => e['site_id'] as int).toList();
  }

  /// Returns the IDs of all users assigned to a given site.
  Future<List<int>> getUserIdsBySite(int siteId) async {
    final data = await _client
        .from('user_sites')
        .select('user_id')
        .eq('site_id', siteId);
    return (data as List).map((e) => e['user_id'] as int).toList();
  }

  Future<void> assignUserRole(int userId, int roleId) async {
    await _client.from('user_roles').upsert({
      'user_id': userId,
      'role_id': roleId,
      'assigned_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeUserRole(int userId, int roleId) async {
    await _client
        .from('user_roles')
        .delete()
        .eq('user_id', userId)
        .eq('role_id', roleId);
  }

  Future<void> assignUserSite(int userId, int siteId) async {
    await _client.from('user_sites').upsert({
      'user_id': userId,
      'site_id': siteId,
      'assigned_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeUserSite(int userId, int siteId) async {
    await _client
        .from('user_sites')
        .delete()
        .eq('user_id', userId)
        .eq('site_id', siteId);
  }

  // =========================================================================
  // ROLES
  // =========================================================================

  Future<List<Role>> getAllRoles() async {
    final data = await _client.from('roles').select().order('name');
    return (data as List).map((e) => Role.fromJson(e)).toList();
  }

  Future<Role?> getRoleByName(String name) async {
    final data =
        await _client.from('roles').select().eq('name', name).maybeSingle();
    return data != null ? Role.fromJson(data) : null;
  }

  Future<Role> createRole(
      {required String name, required String description}) async {
    final data = await _client
        .from('roles')
        .insert({
          'name': name,
          'description': description,
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return Role.fromJson(data);
  }

  // =========================================================================
  // CUSTOM ROLES (team_management)
  // =========================================================================

  Future<List<CustomRole>> getAllCustomRoles() async {
    final data = await _client
        .from('custom_roles')
        .select()
        .eq('is_active', true)
        .order('is_system', ascending: false)
        .order('name');
    final rows = data as List;
    final roles = <CustomRole>[];
    for (final row in rows) {
      final perms = await getCustomRolePermissions(row['id'] as int);
      roles.add(CustomRole.fromJson(row, permissions: perms));
    }
    return roles;
  }

  Future<CustomRole?> getCustomRoleById(int id) async {
    final data =
        await _client.from('custom_roles').select().eq('id', id).maybeSingle();
    if (data == null) return null;
    final perms = await getCustomRolePermissions(id);
    return CustomRole.fromJson(data, permissions: perms);
  }

  Future<CustomRole?> getCustomRoleByName(String name) async {
    final data = await _client
        .from('custom_roles')
        .select()
        .eq('name', name)
        .maybeSingle();
    if (data == null) return null;
    final perms = await getCustomRolePermissions(data['id'] as int);
    return CustomRole.fromJson(data, permissions: perms);
  }

  Future<CustomRole> createCustomRole({
    required String name,
    required String description,
    required String color,
    required String icon,
    required List<String> permissions,
    int? createdBy,
  }) async {
    final data = await _client
        .from('custom_roles')
        .insert({
          'name': name,
          'description': description,
          'color': color,
          'icon': icon,
          'is_system': false,
          'is_active': true,
          if (createdBy != null) 'created_by': createdBy,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    final roleId = data['id'] as int;
    await setCustomRolePermissions(roleId, permissions);
    return CustomRole.fromJson(data, permissions: permissions);
  }

  Future<void> updateCustomRole(int roleId,
      {required String name,
      required String description,
      required String color,
      required String icon,
      required List<String> permissions}) async {
    await _client.from('custom_roles').update({
      'name': name,
      'description': description,
      'color': color,
      'icon': icon,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', roleId);
    await setCustomRolePermissions(roleId, permissions);
  }

  Future<void> deleteCustomRole(int roleId) async {
    await _client.from('custom_roles').delete().eq('id', roleId);
  }

  Future<void> toggleCustomRoleStatus(int roleId, bool isActive) async {
    await _client.from('custom_roles').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', roleId);
  }

  // ── Custom Role Permissions ─────────────────────────────────────────────

  Future<List<String>> getCustomRolePermissions(int roleId) async {
    final data = await _client
        .from('custom_role_permissions')
        .select('permission')
        .eq('custom_role_id', roleId);
    return (data as List).map((e) => e['permission'] as String).toList();
  }

  Future<void> setCustomRolePermissions(
      int roleId, List<String> permissions) async {
    // Remove all existing, then insert fresh set
    await _client
        .from('custom_role_permissions')
        .delete()
        .eq('custom_role_id', roleId);
    if (permissions.isEmpty) return;
    await _client.from('custom_role_permissions').insert(permissions
        .map((p) => {
              'custom_role_id': roleId,
              'permission': p,
              'granted_at': DateTime.now().toIso8601String(),
            })
        .toList());
  }

  // ── User Custom Role Assignments ────────────────────────────────────────

  Future<List<CustomRole>> getUserCustomRoles(int userId) async {
    final data = await _client
        .from('user_custom_roles')
        .select('custom_role_id')
        .eq('user_id', userId);
    final ids = (data as List).map((e) => e['custom_role_id'] as int).toList();
    if (ids.isEmpty) return [];
    final roles = <CustomRole>[];
    for (final id in ids) {
      final role = await getCustomRoleById(id);
      if (role != null) roles.add(role);
    }
    return roles;
  }

  Future<Set<String>> getUserCustomRolePermissions(int userId) async {
    final customRoles = await getUserCustomRoles(userId);
    return customRoles.expand((r) => r.permissions).toSet();
  }

  Future<void> assignUserCustomRole(int userId, int customRoleId,
      {int? assignedBy}) async {
    await _client.from('user_custom_roles').upsert({
      'user_id': userId,
      'custom_role_id': customRoleId,
      if (assignedBy != null) 'assigned_by': assignedBy,
      'assigned_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeUserCustomRole(int userId, int customRoleId) async {
    await _client
        .from('user_custom_roles')
        .delete()
        .eq('user_id', userId)
        .eq('custom_role_id', customRoleId);
  }

  Future<void> setUserCustomRoles(int userId, List<int> customRoleIds,
      {int? assignedBy}) async {
    await _client.from('user_custom_roles').delete().eq('user_id', userId);
    if (customRoleIds.isEmpty) return;
    await _client.from('user_custom_roles').insert(customRoleIds
        .map((id) => {
              'user_id': userId,
              'custom_role_id': id,
              if (assignedBy != null) 'assigned_by': assignedBy,
              'assigned_at': DateTime.now().toIso8601String(),
            })
        .toList());
  }

  // ── Per-User Permission Overrides ───────────────────────────────────────

  Future<List<UserPermissionOverride>> getUserPermissionOverrides(
      int userId) async {
    final data = await _client
        .from('user_permission_overrides')
        .select()
        .eq('user_id', userId)
        .order('permission');
    return (data as List)
        .map((e) => UserPermissionOverride.fromJson(e))
        .toList();
  }

  /// Returns a map of permission_name → is_granted for this user.
  Future<Map<String, bool>> getUserPermissionOverridesMap(int userId) async {
    final overrides = await getUserPermissionOverrides(userId);
    return {for (final o in overrides) o.permission: o.isGranted};
  }

  Future<void> setUserPermissionOverride({
    required int userId,
    required String permission,
    required bool isGranted,
    String? reason,
    int? setBy,
  }) async {
    await _client.from('user_permission_overrides').upsert({
      'user_id': userId,
      'permission': permission,
      'is_granted': isGranted,
      if (reason != null) 'reason': reason,
      if (setBy != null) 'set_by': setBy,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeUserPermissionOverride(
      int userId, String permission) async {
    await _client
        .from('user_permission_overrides')
        .delete()
        .eq('user_id', userId)
        .eq('permission', permission);
  }

  Future<void> clearUserPermissionOverrides(int userId) async {
    await _client
        .from('user_permission_overrides')
        .delete()
        .eq('user_id', userId);
  }

  /// Bulk-replace all overrides: pass a map of permission → is_granted.
  Future<void> setAllUserPermissionOverrides(
      int userId, Map<String, bool> overrideMap,
      {int? setBy}) async {
    await clearUserPermissionOverrides(userId);
    if (overrideMap.isEmpty) return;
    await _client.from('user_permission_overrides').insert(overrideMap.entries
        .map((e) => {
              'user_id': userId,
              'permission': e.key,
              'is_granted': e.value,
              if (setBy != null) 'set_by': setBy,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
        .toList());
  }

  // ── Full user-with-permissions summary ──────────────────────────────────

  Future<UserWithPermissions> getUserWithPermissions(int userId) async {
    final user = await getUserById(userId);
    if (user == null) {
      throw Exception('User $userId not found');
    }
    final roleNames = await getUserRoleNames(userId);
    final customRoles = await getUserCustomRoles(userId);
    final overrides = await getUserPermissionOverrides(userId);
    final overrideMap = {for (final o in overrides) o.permission: o.isGranted};
    final customPerms = customRoles.expand((r) => r.permissions).toSet();

    // Compute effective permissions via PermissionChecker
    // Import handled by rbac_models.dart being in same package
    return UserWithPermissions(
      userId: userId,
      name: user.name,
      email: user.email,
      phone: user.phone,
      isActive: user.isActive,
      roleNames: roleNames,
      customRoles: customRoles,
      overrides: overrides,
      effectivePermissions:
          _computeEffective(roleNames, customPerms, overrideMap),
    );
  }

  Set<String> _computeEffective(List<String> roleNames, Set<String> customPerms,
      Map<String, bool> overrideMap) {
    const all = [
      'view_dashboard',
      'view_clients',
      'create_client',
      'edit_client',
      'delete_client',
      'view_vouchers',
      'create_voucher',
      'delete_voucher',
      'view_sales',
      'make_sale',
      'view_sites',
      'manage_sites',
      'view_assets',
      'manage_assets',
      'view_maintenance',
      'manage_maintenance',
      'view_finance',
      'manage_expenses',
      'manage_investors',
      'view_sms',
      'send_sms',
      'view_packages',
      'manage_packages',
      'view_users',
      'manage_users',
      'manage_team',
      'manage_mikrotik',
      'view_settings',
      'manage_settings',
    ];

    final isSuperAdmin = roleNames.contains('SUPER_ADMIN');
    if (isSuperAdmin) return all.toSet();

    final result = <String>{};
    for (final p in all) {
      if (overrideMap[p] == false) continue;
      if (overrideMap[p] == true) {
        result.add(p);
        continue;
      }
      if (customPerms.contains(p)) {
        result.add(p);
        continue;
      }
    }
    return result;
  }

  Future<List<Site>> getAllSites() async {
    final data = await _client.from('sites').select().order('name');
    return (data as List).map((e) => Site.fromJson(e)).toList();
  }

  Future<List<Site>> getActiveSites() async {
    final data = await _client
        .from('sites')
        .select()
        .eq('is_active', true)
        .order('name');
    return (data as List).map((e) => Site.fromJson(e)).toList();
  }

  Future<Site?> getSiteById(int id) async {
    final data =
        await _client.from('sites').select().eq('id', id).maybeSingle();
    return data != null ? Site.fromJson(data) : null;
  }

  Future<List<Site>> searchSites(String query) async {
    final data = await _client
        .from('sites')
        .select()
        .or('name.ilike.%$query%,location.ilike.%$query%')
        .order('name');
    return (data as List).map((e) => Site.fromJson(e)).toList();
  }

  Future<Site> createSite(Map<String, dynamic> fields) async {
    fields['server_id'] = _uuid.v4();
    fields['created_at'] = DateTime.now().toIso8601String();
    fields['updated_at'] = DateTime.now().toIso8601String();
    final data = await _client.from('sites').insert(fields).select().single();
    return Site.fromJson(data);
  }

  Future<bool> updateSite(int id, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('sites').update(fields).eq('id', id);
    return true;
  }

  Future<void> deleteSite(int id) async {
    await _client.from('sites').delete().eq('id', id);
  }

  // =========================================================================
  // CLIENTS
  // =========================================================================

  Future<List<Client>> getAllClients() async {
    final data = await _client.from('clients').select().order('name');
    return (data as List).map((e) => Client.fromJson(e)).toList();
  }

  /// Clients registered by OR assigned/transferred to [userId].
  Future<List<Client>> getClientsByUser(int userId) async {
    final data = await _client
        .from('clients')
        .select()
        .or('registered_by.eq.$userId,assigned_to.eq.$userId')
        .order('name');
    return (data as List).map((e) => Client.fromJson(e)).toList();
  }

  Future<List<Client>> getActiveClients() async {
    final data = await _client
        .from('clients')
        .select()
        .eq('is_active', true)
        .order('name');
    return (data as List).map((e) => Client.fromJson(e)).toList();
  }

  Future<Client?> getClientById(int id) async {
    final data =
        await _client.from('clients').select().eq('id', id).maybeSingle();
    return data != null ? Client.fromJson(data) : null;
  }

  Future<List<Client>> getClientsBySite(int siteId) async {
    final data = await _client
        .from('clients')
        .select()
        .eq('site_id', siteId)
        .order('name');
    return (data as List).map((e) => Client.fromJson(e)).toList();
  }

  Future<List<Client>> searchClients(String query) async {
    final data = await _client
        .from('clients')
        .select()
        .or('name.ilike.%$query%,phone.ilike.%$query%,email.ilike.%$query%')
        .order('name');
    return (data as List).map((e) => Client.fromJson(e)).toList();
  }

  Future<List<Client>> getExpiringClients(int days) async {
    final now = DateTime.now();
    final future = now.add(Duration(days: days));
    final data = await _client
        .from('clients')
        .select()
        .gte('expiry_date', now.toIso8601String())
        .lte('expiry_date', future.toIso8601String())
        .eq('is_active', true)
        .order('expiry_date');
    return (data as List).map((e) => Client.fromJson(e)).toList();
  }

  Future<List<Client>> getExpiredClients() async {
    final now = DateTime.now();
    final data = await _client
        .from('clients')
        .select()
        .lt('expiry_date', now.toIso8601String())
        .order('expiry_date');
    return (data as List).map((e) => Client.fromJson(e)).toList();
  }

  Future<Client> createClient(Map<String, dynamic> fields) async {
    fields['server_id'] = _uuid.v4();
    fields.putIfAbsent('created_at', () => DateTime.now().toIso8601String());
    fields['updated_at'] = DateTime.now().toIso8601String();
    final data = await _client.from('clients').insert(fields).select().single();
    return Client.fromJson(data);
  }

  Future<bool> updateClient(int id, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('clients').update(fields).eq('id', id);
    return true;
  }

  Future<void> deleteClient(int id) async {
    await _client.from('clients').delete().eq('id', id);
  }

  Future<int> getClientCount() async {
    final data =
        await _client.from('clients').select('id').count(CountOption.exact);
    return data.count;
  }

  Future<int> getActiveClientCount() async {
    final data = await _client
        .from('clients')
        .select('id')
        .eq('is_active', true)
        .count(CountOption.exact);
    return data.count;
  }

  Future<List<Client>> getClientsPaginated(
      {required int page, required int pageSize}) async {
    final offset = (page - 1) * pageSize;
    final data = await _client
        .from('clients')
        .select()
        .order('created_at', ascending: false)
        .range(offset, offset + pageSize - 1);
    return (data as List).map((e) => Client.fromJson(e)).toList();
  }

  // =========================================================================
  // PACKAGES
  // =========================================================================

  Future<List<Package>> getAllPackages() async {
    final data = await _client.from('packages').select().order('name');
    return (data as List).map((e) => Package.fromJson(e)).toList();
  }

  Future<List<Package>> getActivePackages() async {
    final data = await _client
        .from('packages')
        .select()
        .eq('is_active', true)
        .order('price');
    return (data as List).map((e) => Package.fromJson(e)).toList();
  }

  Future<Package?> getPackageById(int id) async {
    final data =
        await _client.from('packages').select().eq('id', id).maybeSingle();
    return data != null ? Package.fromJson(data) : null;
  }

  Future<Package> createPackage(Map<String, dynamic> fields) async {
    fields['server_id'] = _uuid.v4();
    fields['created_at'] = DateTime.now().toIso8601String();
    fields['updated_at'] = DateTime.now().toIso8601String();
    final data =
        await _client.from('packages').insert(fields).select().single();
    return Package.fromJson(data);
  }

  Future<bool> updatePackage(int id, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('packages').update(fields).eq('id', id);
    return true;
  }

  Future<void> deletePackage(int id) async {
    await _client.from('packages').delete().eq('id', id);
  }

  // =========================================================================
  // VOUCHERS
  // =========================================================================

  Future<List<Voucher>> getAllVouchers({
    String? status,
    int? packageId,
    int? siteId,
    List<int>? siteIds, // restrict to multiple sites (used for RBAC scoping)
    String? batchId,
  }) async {
    var query = _client.from('vouchers').select();
    if (status != null) query = query.eq('status', status);
    if (packageId != null) query = query.eq('package_id', packageId);
    // siteIds (multi-site) takes priority over single siteId
    if (siteIds != null && siteIds.isNotEmpty) {
      query = query.inFilter('site_id', siteIds);
    } else if (siteId != null) {
      query = query.eq('site_id', siteId);
    }
    if (batchId != null) query = query.eq('batch_id', batchId);
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => Voucher.fromJson(e)).toList();
  }

  Future<List<Voucher>> getAvailableVouchers({int? packageId}) async {
    var query = _client.from('vouchers').select().eq('status', 'AVAILABLE');
    if (packageId != null) query = query.eq('package_id', packageId);
    final data = await query.order('code');
    return (data as List).map((e) => Voucher.fromJson(e)).toList();
  }

  Future<Voucher?> getVoucherById(int id) async {
    final data =
        await _client.from('vouchers').select().eq('id', id).maybeSingle();
    return data != null ? Voucher.fromJson(data) : null;
  }

  Future<Voucher?> getVoucherByCode(String code) async {
    final data =
        await _client.from('vouchers').select().eq('code', code).maybeSingle();
    return data != null ? Voucher.fromJson(data) : null;
  }

  Future<int> getAvailableVoucherCount() async {
    final data = await _client
        .from('vouchers')
        .select('id')
        .eq('status', 'AVAILABLE')
        .count(CountOption.exact);
    return data.count;
  }

  Future<Map<String, int>> getVoucherStats() async {
    final data = await _client.from('vouchers').select('status');
    final list = data as List;
    int available = 0, sold = 0, used = 0, expired = 0;
    for (final v in list) {
      switch (v['status']) {
        case 'AVAILABLE':
          available++;
          break;
        case 'SOLD':
          sold++;
          break;
        case 'USED':
          used++;
          break;
        case 'EXPIRED':
          expired++;
          break;
      }
    }
    return {
      'total': list.length,
      'available': available,
      'sold': sold,
      'used': used,
      'expired': expired,
    };
  }

  Future<Voucher> createVoucher(Map<String, dynamic> fields) async {
    fields['server_id'] = _uuid.v4();
    fields.putIfAbsent('status', () => 'AVAILABLE');
    fields['created_at'] = DateTime.now().toIso8601String();
    fields['updated_at'] = DateTime.now().toIso8601String();
    final data =
        await _client.from('vouchers').insert(fields).select().single();
    return Voucher.fromJson(data);
  }

  Future<bool> updateVoucher(int id, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('vouchers').update(fields).eq('id', id);
    return true;
  }

  Future<bool> markVoucherAsSold(
      {required int voucherId, required int soldByUserId}) async {
    await _client.from('vouchers').update({
      'status': 'SOLD',
      'sold_at': DateTime.now().toIso8601String(),
      'sold_by_user_id': soldByUserId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', voucherId);
    return true;
  }

  Future<bool> markVoucherAsUsed(int voucherId) async {
    await _client.from('vouchers').update({
      'status': 'USED',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', voucherId);
    return true;
  }

  Future<bool> deleteVoucher(int id) async {
    await _client.from('vouchers').delete().eq('id', id);
    return true;
  }

  Future<int> deleteBatch(String batchId) async {
    final data =
        await _client.from('vouchers').select('id').eq('batch_id', batchId);
    await _client.from('vouchers').delete().eq('batch_id', batchId);
    return (data as List).length;
  }

  Future<int> bulkInsertVouchers(
    List<Map<String, dynamic>> vouchers, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    int count = 0;
    final total = vouchers.length;
    int processed = 0;
    for (final v in vouchers) {
      if (isCancelled != null && isCancelled()) break;
      try {
        v['server_id'] = _uuid.v4();
        v.putIfAbsent('status', () => 'AVAILABLE');
        v['created_at'] = DateTime.now().toIso8601String();
        v['updated_at'] = DateTime.now().toIso8601String();
        await _client
            .from('vouchers')
            .upsert(v, onConflict: 'code', ignoreDuplicates: true);
        count++;
      } catch (e) {
        debugPrint('⚠️  Skipping duplicate voucher: $e');
      }
      processed++;
      onProgress?.call(processed, total);
    }
    return count;
  }

  // Realtime-like watch – returns fresh list each call (poll from UI)
  Future<List<Voucher>> watchVouchers({
    String? status,
    int? packageId,
    int? siteId,
    String? batchId,
  }) =>
      getAllVouchers(
          status: status,
          packageId: packageId,
          siteId: siteId,
          batchId: batchId);

  // =========================================================================
  // SALES
  // =========================================================================

  Future<List<Sale>> getAllSales() async {
    final data = await _client
        .from('sales')
        .select()
        .order('sale_date', ascending: false);
    return (data as List).map((e) => Sale.fromJson(e)).toList();
  }

  Future<Sale?> getSaleById(int id) async {
    final data =
        await _client.from('sales').select().eq('id', id).maybeSingle();
    return data != null ? Sale.fromJson(data) : null;
  }

  Future<Sale?> getSaleByReceiptNumber(String receipt) async {
    final data = await _client
        .from('sales')
        .select()
        .eq('receipt_number', receipt)
        .maybeSingle();
    return data != null ? Sale.fromJson(data) : null;
  }

  Future<List<Sale>> getSalesByAgent(int agentId) async {
    final data = await _client
        .from('sales')
        .select()
        .eq('agent_id', agentId)
        .order('sale_date', ascending: false);
    return (data as List).map((e) => Sale.fromJson(e)).toList();
  }

  Future<List<Sale>> getSalesBySite(int siteId) async {
    final data = await _client
        .from('sales')
        .select()
        .eq('site_id', siteId)
        .order('sale_date', ascending: false);
    return (data as List).map((e) => Sale.fromJson(e)).toList();
  }

  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end) async {
    final data = await _client
        .from('sales')
        .select()
        .gte('sale_date', start.toIso8601String())
        .lte('sale_date', end.toIso8601String())
        .order('sale_date', ascending: false);
    return (data as List).map((e) => Sale.fromJson(e)).toList();
  }

  Future<List<Sale>> getTodaySales() async {
    final now = DateTime.now();
    return getSalesByDateRange(
      DateTime(now.year, now.month, now.day),
      DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  Future<List<Sale>> getThisMonthSales() async {
    final now = DateTime.now();
    return getSalesByDateRange(
      DateTime(now.year, now.month, 1),
      DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }

  Future<Sale> createSale(Map<String, dynamic> fields) async {
    fields['server_id'] = _uuid.v4();
    fields.putIfAbsent('sale_date', () => DateTime.now().toIso8601String());
    fields['created_at'] = DateTime.now().toIso8601String();
    fields['updated_at'] = DateTime.now().toIso8601String();
    final data = await _client.from('sales').insert(fields).select().single();
    return Sale.fromJson(data);
  }

  String generateReceiptNumber() {
    final now = DateTime.now();
    return 'VN-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 100000}';
  }

  Future<Sale> makeSale({
    required int? voucherId,
    required int agentId,
    required double amount,
    int? clientId,
    int? siteId,
    double commission = 0.0,
    String paymentMethod = 'CASH',
    String? notes,
  }) async {
    return createSale({
      'receipt_number': generateReceiptNumber(),
      'voucher_id': voucherId,
      'client_id': clientId,
      'agent_id': agentId,
      'site_id': siteId,
      'amount': amount,
      'commission': commission,
      'payment_method': paymentMethod,
      'notes': notes,
      'sale_date': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> updateSale(int id, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('sales').update(fields).eq('id', id);
    return true;
  }

  Future<void> deleteSale(int id) async {
    await _client.from('sales').delete().eq('id', id);
  }

  Future<double> getTotalRevenue() async {
    final data = await _client.from('sales').select('amount');
    return (data as List)
        .fold<double>(0, (s, e) => s + (e['amount'] as num).toDouble());
  }

  Future<double> getRevenueByDateRange(DateTime start, DateTime end) async {
    final sales = await getSalesByDateRange(start, end);
    return sales.fold<double>(0, (s, sale) => s + sale.amount);
  }

  Future<double> getTodayRevenue() async {
    final sales = await getTodaySales();
    return sales.fold<double>(0, (s, sale) => s + sale.amount);
  }

  Future<double> getThisMonthRevenue() async {
    final sales = await getThisMonthSales();
    return sales.fold<double>(0, (s, sale) => s + sale.amount);
  }

  Future<int> getSalesCount() async {
    final data =
        await _client.from('sales').select('id').count(CountOption.exact);
    return data.count;
  }

  Future<List<Sale>> getSalesPaginated(
      {required int page, required int pageSize}) async {
    final offset = (page - 1) * pageSize;
    final data = await _client
        .from('sales')
        .select()
        .order('sale_date', ascending: false)
        .range(offset, offset + pageSize - 1);
    return (data as List).map((e) => Sale.fromJson(e)).toList();
  }

  Future<double> getAgentCommissions(int agentId,
      {DateTime? startDate, DateTime? endDate}) async {
    List<Sale> sales;
    if (startDate != null && endDate != null) {
      final all = await getSalesByAgent(agentId);
      sales = all
          .where((s) =>
              s.saleDate.isAfter(startDate) && s.saleDate.isBefore(endDate))
          .toList();
    } else {
      sales = await getSalesByAgent(agentId);
    }
    return sales.fold<double>(0, (s, sale) => s + sale.commission);
  }

  // =========================================================================
  // EXPENSES
  // =========================================================================

  Future<List<Expense>> getAllExpenses() async {
    final data = await _client
        .from('expenses')
        .select()
        .order('expense_date', ascending: false);
    return (data as List).map((e) => Expense.fromJson(e)).toList();
  }

  Future<Expense?> getExpenseById(int id) async {
    final data =
        await _client.from('expenses').select().eq('id', id).maybeSingle();
    return data != null ? Expense.fromJson(data) : null;
  }

  Future<List<Expense>> getExpensesByCategory(String category) async {
    final data = await _client
        .from('expenses')
        .select()
        .eq('category', category)
        .order('expense_date', ascending: false);
    return (data as List).map((e) => Expense.fromJson(e)).toList();
  }

  Future<List<Expense>> getExpensesBySite(int siteId) async {
    final data = await _client
        .from('expenses')
        .select()
        .eq('site_id', siteId)
        .order('expense_date', ascending: false);
    return (data as List).map((e) => Expense.fromJson(e)).toList();
  }

  Future<List<Expense>> getExpensesByDateRange(
      DateTime start, DateTime end) async {
    final data = await _client
        .from('expenses')
        .select()
        .gte('expense_date', start.toIso8601String())
        .lte('expense_date', end.toIso8601String())
        .order('expense_date', ascending: false);
    return (data as List).map((e) => Expense.fromJson(e)).toList();
  }

  Future<List<Expense>> getThisMonthExpenses() async {
    final now = DateTime.now();
    return getExpensesByDateRange(
      DateTime(now.year, now.month, 1),
      DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }

  Future<Expense> createExpense(Map<String, dynamic> fields) async {
    fields['server_id'] = _uuid.v4();
    fields.putIfAbsent('expense_date', () => DateTime.now().toIso8601String());
    fields['created_at'] = DateTime.now().toIso8601String();
    fields['updated_at'] = DateTime.now().toIso8601String();
    final data =
        await _client.from('expenses').insert(fields).select().single();
    return Expense.fromJson(data);
  }

  Future<bool> updateExpense(int id, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('expenses').update(fields).eq('id', id);
    return true;
  }

  Future<void> deleteExpense(int id) async {
    await _client.from('expenses').delete().eq('id', id);
  }

  Future<double> getTotalExpenses() async {
    final data = await _client.from('expenses').select('amount');
    return (data as List)
        .fold<double>(0, (s, e) => s + (e['amount'] as num).toDouble());
  }

  Future<double> getExpensesTotalByDateRange(
      DateTime start, DateTime end) async {
    final expenses = await getExpensesByDateRange(start, end);
    return expenses.fold<double>(0, (s, e) => s + e.amount);
  }

  Future<double> getThisMonthTotalExpenses() async {
    final expenses = await getThisMonthExpenses();
    return expenses.fold<double>(0, (s, e) => s + e.amount);
  }

  Future<Map<String, double>> getExpensesByCategoryTotal() async {
    final expenses = await getAllExpenses();
    final Map<String, double> totals = {};
    for (final e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    return totals;
  }

  // =========================================================================
  // INVESTORS
  // =========================================================================

  Future<List<Investor>> getAllInvestors() async {
    final data = await _client
        .from('investors')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => Investor.fromJson(e)).toList();
  }

  Future<List<Investor>> getActiveInvestors() async {
    final data = await _client
        .from('investors')
        .select()
        .eq('is_active', true)
        .order('name');
    return (data as List).map((e) => Investor.fromJson(e)).toList();
  }

  Future<Investor> createInvestor(Map<String, dynamic> fields) async {
    fields['created_at'] = DateTime.now().toIso8601String();
    fields['updated_at'] = DateTime.now().toIso8601String();
    final data =
        await _client.from('investors').insert(fields).select().single();
    return Investor.fromJson(data);
  }

  Future<bool> updateInvestor(int id, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('investors').update(fields).eq('id', id);
    return true;
  }

  Future<void> deleteInvestor(int id) async {
    await _client.from('investors').delete().eq('id', id);
  }

  Future<double> getTotalInvestedAmount() async {
    final data = await _client
        .from('investors')
        .select('invested_amount')
        .eq('is_active', true);
    return (data as List).fold<double>(
        0, (s, e) => s + (e['invested_amount'] as num).toDouble());
  }

  // =========================================================================
  // ASSETS
  // =========================================================================

  Future<List<Asset>> getAllAssets() async {
    final data = await _client.from('assets').select().order('name');
    return (data as List).map((e) => Asset.fromJson(e)).toList();
  }

  Future<List<Asset>> getActiveAssets() async {
    final data = await _client
        .from('assets')
        .select()
        .eq('is_active', true)
        .order('name');
    return (data as List).map((e) => Asset.fromJson(e)).toList();
  }

  Future<Asset?> getAssetById(int id) async {
    final data =
        await _client.from('assets').select().eq('id', id).maybeSingle();
    return data != null ? Asset.fromJson(data) : null;
  }

  Future<List<Asset>> getAssetsBySite(int siteId) async {
    final data = await _client
        .from('assets')
        .select()
        .eq('site_id', siteId)
        .order('name');
    return (data as List).map((e) => Asset.fromJson(e)).toList();
  }

  Future<List<Asset>> getAssetsByType(String type) async {
    final data =
        await _client.from('assets').select().eq('type', type).order('name');
    return (data as List).map((e) => Asset.fromJson(e)).toList();
  }

  Future<List<Asset>> getAssetsByCondition(String condition) async {
    final data = await _client
        .from('assets')
        .select()
        .eq('condition', condition)
        .order('name');
    return (data as List).map((e) => Asset.fromJson(e)).toList();
  }

  Future<List<Asset>> searchAssets(String query) async {
    final data = await _client
        .from('assets')
        .select()
        .or('name.ilike.%$query%,serial_number.ilike.%$query%,model.ilike.%$query%')
        .order('name');
    return (data as List).map((e) => Asset.fromJson(e)).toList();
  }

  Future<Asset> createAsset(Map<String, dynamic> fields) async {
    fields['server_id'] = _uuid.v4();
    fields['created_at'] = DateTime.now().toIso8601String();
    fields['updated_at'] = DateTime.now().toIso8601String();
    final data = await _client.from('assets').insert(fields).select().single();
    return Asset.fromJson(data);
  }

  Future<bool> updateAsset(int id, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('assets').update(fields).eq('id', id);
    return true;
  }

  Future<void> deleteAsset(int id) async {
    await _client.from('assets').delete().eq('id', id);
  }

  Future<int> getAssetCount() async {
    final data =
        await _client.from('assets').select('id').count(CountOption.exact);
    return data.count;
  }

  // =========================================================================
  // MAINTENANCE
  // =========================================================================

  Future<List<MaintenanceRecord>> getAllMaintenance() async {
    final data = await _client
        .from('maintenance')
        .select()
        .order('reported_date', ascending: false);
    return (data as List).map((e) => MaintenanceRecord.fromJson(e)).toList();
  }

  Future<MaintenanceRecord?> getMaintenanceById(int id) async {
    final data =
        await _client.from('maintenance').select().eq('id', id).maybeSingle();
    return data != null ? MaintenanceRecord.fromJson(data) : null;
  }

  Future<List<MaintenanceRecord>> getMaintenanceByStatus(String status) async {
    final data = await _client
        .from('maintenance')
        .select()
        .eq('status', status)
        .order('reported_date', ascending: false);
    return (data as List).map((e) => MaintenanceRecord.fromJson(e)).toList();
  }

  Future<List<MaintenanceRecord>> getMaintenanceBySite(int siteId) async {
    final data = await _client
        .from('maintenance')
        .select()
        .eq('site_id', siteId)
        .order('reported_date', ascending: false);
    return (data as List).map((e) => MaintenanceRecord.fromJson(e)).toList();
  }

  Future<List<MaintenanceRecord>> getMaintenanceByAsset(int assetId) async {
    final data = await _client
        .from('maintenance')
        .select()
        .eq('asset_id', assetId)
        .order('reported_date', ascending: false);
    return (data as List).map((e) => MaintenanceRecord.fromJson(e)).toList();
  }

  Future<List<MaintenanceRecord>> getMaintenanceByTechnician(int userId) async {
    final data = await _client
        .from('maintenance')
        .select()
        .eq('assigned_to', userId)
        .order('reported_date', ascending: false);
    return (data as List).map((e) => MaintenanceRecord.fromJson(e)).toList();
  }

  Future<MaintenanceRecord> createMaintenance(
      Map<String, dynamic> fields) async {
    fields['server_id'] = _uuid.v4();
    fields.putIfAbsent('status', () => 'PENDING');
    fields.putIfAbsent('reported_date', () => DateTime.now().toIso8601String());
    fields['created_at'] = DateTime.now().toIso8601String();
    fields['updated_at'] = DateTime.now().toIso8601String();
    final data =
        await _client.from('maintenance').insert(fields).select().single();
    return MaintenanceRecord.fromJson(data);
  }

  Future<bool> updateMaintenance(int id, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('maintenance').update(fields).eq('id', id);
    return true;
  }

  Future<bool> completeMaintenance(
      int id, String resolution, double? cost) async {
    return updateMaintenance(id, {
      'status': 'COMPLETED',
      'completed_date': DateTime.now().toIso8601String(),
      'resolution': resolution,
      if (cost != null) 'cost': cost,
    });
  }

  Future<void> deleteMaintenance(int id) async {
    await _client.from('maintenance').delete().eq('id', id);
  }

  Future<Map<String, int>> getMaintenanceCounts() async {
    final all = await getAllMaintenance();
    return {
      'total': all.length,
      'pending': all.where((m) => m.status == 'PENDING').length,
      'in_progress': all.where((m) => m.status == 'IN_PROGRESS').length,
      'completed': all.where((m) => m.status == 'COMPLETED').length,
    };
  }

  // =========================================================================
  // SMS LOGS
  // =========================================================================

  Future<List<SmsLog>> getAllSmsLogs() async {
    final data = await _client
        .from('sms_logs')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => SmsLog.fromJson(e)).toList();
  }

  Future<SmsLog> createSmsLog(Map<String, dynamic> fields) async {
    fields['server_id'] = _uuid.v4();
    fields['created_at'] = DateTime.now().toIso8601String();
    fields['updated_at'] = DateTime.now().toIso8601String();
    final data =
        await _client.from('sms_logs').insert(fields).select().single();
    return SmsLog.fromJson(data);
  }

  Future<bool> updateSmsLog(int id, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('sms_logs').update(fields).eq('id', id);
    return true;
  }

  // =========================================================================
  // SMS TEMPLATES
  // =========================================================================

  Future<List<SmsTemplate>> getAllSmsTemplates() async {
    final data = await _client.from('sms_templates').select().order('name');
    return (data as List).map((e) => SmsTemplate.fromJson(e)).toList();
  }

  Future<SmsTemplate?> getSmsTemplateById(int id) async {
    final data =
        await _client.from('sms_templates').select().eq('id', id).maybeSingle();
    return data != null ? SmsTemplate.fromJson(data) : null;
  }

  Future<SmsTemplate> createSmsTemplate(Map<String, dynamic> fields) async {
    fields['server_id'] = _uuid.v4();
    fields['created_at'] = DateTime.now().toIso8601String();
    fields['updated_at'] = DateTime.now().toIso8601String();
    final data =
        await _client.from('sms_templates').insert(fields).select().single();
    return SmsTemplate.fromJson(data);
  }

  Future<bool> updateSmsTemplate(int id, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('sms_templates').update(fields).eq('id', id);
    return true;
  }

  Future<void> deleteSmsTemplate(int id) async {
    await _client.from('sms_templates').delete().eq('id', id);
  }

  // =========================================================================
  // COMMISSION SETTINGS
  // =========================================================================

  Future<List<CommissionSetting>> getAllCommissionSettings() async {
    final data = await _client
        .from('commission_settings')
        .select()
        .order('priority', ascending: false);
    return (data as List).map((e) => CommissionSetting.fromJson(e)).toList();
  }

  Future<List<CommissionSetting>> getActiveCommissionSettings() async {
    final data = await _client
        .from('commission_settings')
        .select()
        .eq('is_active', true)
        .order('priority', ascending: false);
    return (data as List).map((e) => CommissionSetting.fromJson(e)).toList();
  }

  Future<CommissionSetting?> getCommissionSettingById(int id) async {
    final data = await _client
        .from('commission_settings')
        .select()
        .eq('id', id)
        .maybeSingle();
    return data != null ? CommissionSetting.fromJson(data) : null;
  }

  Future<CommissionSetting> createCommissionSetting(
      Map<String, dynamic> fields) async {
    fields['created_at'] = DateTime.now().toIso8601String();
    fields['updated_at'] = DateTime.now().toIso8601String();
    final data = await _client
        .from('commission_settings')
        .insert(fields)
        .select()
        .single();
    return CommissionSetting.fromJson(data);
  }

  Future<bool> updateCommissionSetting(
      int id, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('commission_settings').update(fields).eq('id', id);
    return true;
  }

  Future<void> deleteCommissionSetting(int id) async {
    await _client.from('commission_settings').delete().eq('id', id);
  }

  // =========================================================================
  // COMMISSION HISTORY
  // =========================================================================

  Future<List<CommissionHistory>> getCommissionHistoryByAgent(
      int agentId) async {
    final data = await _client
        .from('commission_history')
        .select()
        .eq('agent_id', agentId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => CommissionHistory.fromJson(e)).toList();
  }

  Future<List<CommissionHistory>> getAllCommissionHistory() async {
    final data = await _client
        .from('commission_history')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => CommissionHistory.fromJson(e)).toList();
  }

  Future<CommissionHistory> createCommissionHistory(
      Map<String, dynamic> fields) async {
    fields['server_id'] = _uuid.v4();
    fields['created_at'] = DateTime.now().toIso8601String();
    fields['updated_at'] = DateTime.now().toIso8601String();
    final data = await _client
        .from('commission_history')
        .insert(fields)
        .select()
        .single();
    return CommissionHistory.fromJson(data);
  }

  Future<bool> updateCommissionHistory(
      int id, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('commission_history').update(fields).eq('id', id);
    return true;
  }

  // =========================================================================
  // ISP SUBSCRIPTIONS
  // =========================================================================

  Future<List<IspSubscription>> getIspSubscriptionsForSite(int siteId) async {
    final data = await _client
        .from('isp_subscriptions')
        .select()
        .eq('site_id', siteId)
        .order('paid_at', ascending: false);
    return (data as List).map((e) => IspSubscription.fromJson(e)).toList();
  }

  Future<IspSubscription?> getLatestIspSubscriptionForSite(int siteId) async {
    final data = await _client
        .from('isp_subscriptions')
        .select()
        .eq('site_id', siteId)
        .order('paid_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return data != null ? IspSubscription.fromJson(data) : null;
  }

  Future<List<IspSubscription>> getAllIspSubscriptions() async {
    final data = await _client
        .from('isp_subscriptions')
        .select()
        .order('paid_at', ascending: false);
    return (data as List).map((e) => IspSubscription.fromJson(e)).toList();
  }

  Future<IspSubscription> createIspSubscription(
      Map<String, dynamic> fields) async {
    fields['created_at'] = DateTime.now().toIso8601String();
    fields['updated_at'] = DateTime.now().toIso8601String();
    final data = await _client
        .from('isp_subscriptions')
        .insert(fields)
        .select()
        .single();
    return IspSubscription.fromJson(data);
  }

  Future<bool> updateIspSubscription(
      int id, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('isp_subscriptions').update(fields).eq('id', id);
    return true;
  }

  Future<bool> deleteIspSubscription(int id) async {
    await _client.from('isp_subscriptions').delete().eq('id', id);
    return true;
  }

  // =========================================================================
  // DASHBOARD HELPERS
  // =========================================================================

  Future<DashboardData> getDashboardData({
    bool canAccessAllSites = true,
    List<int> userSites = const [],
  }) async {
    // Parallel fetches for performance
    final results = await Future.wait([
      getActiveClientCount(), // 0
      getAvailableVoucherCount(), // 1
      getTodayRevenue(), // 2
      getTotalRevenue(), // 3
      getVoucherStats(), // 4
    ]);

    // Last 7 days sales
    final today = DateTime.now();
    final dailySales = <double>[];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day - i);
      final nextDay = day.add(const Duration(days: 1));
      final sales = await getSalesByDateRange(day, nextDay);
      dailySales.add(sales.fold<double>(0, (s, sale) => s + sale.amount));
    }

    // Recent 5 sales
    final recentData = await _client
        .from('sales')
        .select()
        .order('sale_date', ascending: false)
        .limit(5);
    final recentSales =
        (recentData as List).map((e) => Sale.fromJson(e)).toList();

    final voucherStats = results[4] as Map<String, int>;

    return DashboardData(
      totalClients: results[0] as int,
      activeVouchers: results[1] as int,
      todaySales: results[2] as double,
      totalRevenue: results[3] as double,
      last7DaysSales: dailySales,
      voucherStats: VoucherStats(
        active: voucherStats['available'] ?? 0,
        sold: voucherStats['sold'] ?? 0,
        expired: voucherStats['expired'] ?? 0,
        unused: voucherStats['used'] ?? 0,
      ),
      recentSales: recentSales,
    );
  }

  // =========================================================================
  // VOUCHER QUOTA SETTINGS
  // =========================================================================

  /// Returns the quota setting for [siteId], falling back to the global row
  /// (site_id IS NULL). Returns null if no row exists at all.
  /// Looks up the most specific quota setting for [siteId] + [packageId].
  /// Hierarchy: (site+package) → (site only) → (package only) → global.
  Future<VoucherQuotaSetting?> getVoucherQuotaSetting(
    int? siteId, {
    int? packageId,
  }) async {
    // 1. Try (site, package) exact match
    if (siteId != null && packageId != null) {
      final row = await _client
          .from('voucher_quota_settings')
          .select()
          .eq('site_id', siteId)
          .eq('package_id', packageId)
          .maybeSingle();
      if (row != null) return VoucherQuotaSetting.fromJson(row);
    }
    // 2. Try site-specific with no package restriction
    if (siteId != null) {
      final row = await _client
          .from('voucher_quota_settings')
          .select()
          .eq('site_id', siteId)
          .isFilter('package_id', null)
          .maybeSingle();
      if (row != null) return VoucherQuotaSetting.fromJson(row);
    }
    // 3. Try package-specific with no site restriction
    if (packageId != null) {
      final row = await _client
          .from('voucher_quota_settings')
          .select()
          .isFilter('site_id', null)
          .eq('package_id', packageId)
          .maybeSingle();
      if (row != null) return VoucherQuotaSetting.fromJson(row);
    }
    // 4. Fall back to global (no site, no package)
    final global = await _client
        .from('voucher_quota_settings')
        .select()
        .isFilter('site_id', null)
        .isFilter('package_id', null)
        .maybeSingle();
    return global != null ? VoucherQuotaSetting.fromJson(global) : null;
  }

  /// Returns ALL quota settings for admin display (global + per-site + per-package combos).
  Future<List<VoucherQuotaSetting>> getAllVoucherQuotaSettings() async {
    final data = await _client
        .from('voucher_quota_settings')
        .select()
        .order('site_id', nullsFirst: true)
        .order('package_id', nullsFirst: true);
    return (data as List).map((e) => VoucherQuotaSetting.fromJson(e)).toList();
  }

  /// Upsert a quota setting. Matches on (siteId, packageId) — both may be null (global).
  Future<void> saveVoucherQuotaSetting({
    int? siteId,
    int? packageId,
    required int quotaLimit,
    required bool isEnabled,
  }) async {
    // Because PostgreSQL ON CONFLICT with nullable columns requires
    // NULLS NOT DISTINCT (migration 012), we can use upsert directly.
    await _client.from('voucher_quota_settings').upsert(
      {
        'site_id': siteId,
        'package_id': packageId,
        'quota_limit': quotaLimit,
        'is_enabled': isEnabled,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'site_id,package_id',
      ignoreDuplicates: false,
    );
  }

  // =========================================================================
  // SALES REMITTANCES
  // =========================================================================

  /// Counts SOLD vouchers by [agentId] that were sold AFTER the agent's last
  /// CONFIRMED remittance (i.e., money still outstanding).
  Future<int> countOutstandingSoldVouchers(int agentId) async {
    // Get last confirmed remittance date
    final lastConfirmedRow = await _client
        .from('sales_remittances')
        .select('reviewed_at')
        .eq('agent_id', agentId)
        .eq('status', 'CONFIRMED')
        .order('reviewed_at', ascending: false)
        .limit(1)
        .maybeSingle();

    dynamic query = _client
        .from('vouchers')
        .select('id')
        .eq('sold_by_user_id', agentId)
        .eq('status', 'SOLD');

    if (lastConfirmedRow != null && lastConfirmedRow['reviewed_at'] != null) {
      query = query.gt('sold_at', lastConfirmedRow['reviewed_at'] as String);
    }

    final data = await query;
    return (data as List).length;
  }

  /// Returns the pending (PENDING status) remittance for [agentId], if any.
  Future<SalesRemittance?> getPendingRemittance(int agentId) async {
    final row = await _client
        .from('sales_remittances')
        .select()
        .eq('agent_id', agentId)
        .eq('status', 'PENDING')
        .order('submitted_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row != null ? SalesRemittance.fromJson(row) : null;
  }

  /// Agent submits their collection.
  Future<SalesRemittance> createRemittance({
    required int agentId,
    int? siteId,
    required double amount,
    String? notes,
  }) async {
    final data = await _client
        .from('sales_remittances')
        .insert({
          'agent_id': agentId,
          'site_id': siteId,
          'amount': amount,
          'notes': notes,
          'status': 'PENDING',
          'submitted_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return SalesRemittance.fromJson(data);
  }

  /// Returns ALL remittances, newest first (for admin/finance view).
  Future<List<SalesRemittance>> getAllRemittances({String? status}) async {
    // Filters (.eq) must come BEFORE transform methods (.order/.limit)
    dynamic q = _client.from('sales_remittances').select();
    if (status != null) q = q.eq('status', status);
    q = q.order('submitted_at', ascending: false);
    final data = await q;
    return (data as List).map((e) => SalesRemittance.fromJson(e)).toList();
  }

  /// Admin/Finance confirms or rejects a remittance.
  Future<void> reviewRemittance({
    required int id,
    required String status, // 'CONFIRMED' or 'REJECTED'
    required int reviewedBy,
  }) async {
    await _client.from('sales_remittances').update({
      'status': status,
      'reviewed_by': reviewedBy,
      'reviewed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}

// ---------------------------------------------------------------------------
// Dashboard data models (previously defined inline in DashboardScreen)
// ---------------------------------------------------------------------------
class DashboardData {
  final int totalClients;
  final int activeVouchers;
  final double todaySales;
  final double totalRevenue;
  final List<double> last7DaysSales;
  final VoucherStats voucherStats;
  final List<Sale> recentSales;

  const DashboardData({
    required this.totalClients,
    required this.activeVouchers,
    required this.todaySales,
    required this.totalRevenue,
    required this.last7DaysSales,
    required this.voucherStats,
    required this.recentSales,
  });

  factory DashboardData.empty() => DashboardData(
        totalClients: 0,
        activeVouchers: 0,
        todaySales: 0,
        totalRevenue: 0,
        last7DaysSales: List.filled(7, 0.0),
        voucherStats:
            const VoucherStats(active: 0, sold: 0, expired: 0, unused: 0),
        recentSales: [],
      );
}

class VoucherStats {
  final int active;
  final int sold;
  final int expired;
  final int unused;

  const VoucherStats({
    required this.active,
    required this.sold,
    required this.expired,
    required this.unused,
  });
}
