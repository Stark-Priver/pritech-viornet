// ============================================================
// permissions.dart
// Role-Based Access Control — Permissions, built-in Roles,
// and an enhanced PermissionChecker that respects:
//   1. Built-in (hardcoded) role permission sets
//   2. Custom role permissions loaded from Supabase
//   3. Per-user explicit GRANT / DENY overrides
// ============================================================

// ---------------------------------------------------------------------------
// Permission descriptor
// ---------------------------------------------------------------------------
class Permission {
  final String name;
  final String description;
  final String category;

  const Permission(this.name, this.description, {this.category = 'General'});

  @override
  bool operator ==(Object other) => other is Permission && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

// ---------------------------------------------------------------------------
// All system permissions — grouped by feature
// ---------------------------------------------------------------------------
class Permissions {
  // ── Dashboard ─────────────────────────────────────────────
  static const viewDashboard =
      Permission('view_dashboard', 'View Dashboard', category: 'Dashboard');

  // ── Clients ───────────────────────────────────────────────
  static const viewClients =
      Permission('view_clients', 'View Clients', category: 'Clients');
  static const createClient =
      Permission('create_client', 'Create Client', category: 'Clients');
  static const editClient =
      Permission('edit_client', 'Edit Client', category: 'Clients');
  static const deleteClient =
      Permission('delete_client', 'Delete Client', category: 'Clients');

  // ── Vouchers ──────────────────────────────────────────────
  static const viewVouchers =
      Permission('view_vouchers', 'View Vouchers', category: 'Vouchers');
  static const createVoucher =
      Permission('create_voucher', 'Create Voucher', category: 'Vouchers');
  static const deleteVoucher =
      Permission('delete_voucher', 'Delete Voucher', category: 'Vouchers');

  // ── Sales / POS ───────────────────────────────────────────
  static const viewSales =
      Permission('view_sales', 'View Sales', category: 'Sales');
  static const makeSale =
      Permission('make_sale', 'Make Sale (POS)', category: 'Sales');

  // ── Sites ─────────────────────────────────────────────────
  static const viewSites =
      Permission('view_sites', 'View Sites', category: 'Sites');
  static const manageSites =
      Permission('manage_sites', 'Manage Sites', category: 'Sites');

  // ── Assets ────────────────────────────────────────────────
  static const viewAssets =
      Permission('view_assets', 'View Assets', category: 'Assets');
  static const manageAssets =
      Permission('manage_assets', 'Manage Assets', category: 'Assets');

  // ── Maintenance ───────────────────────────────────────────
  static const viewMaintenance = Permission(
      'view_maintenance', 'View Maintenance',
      category: 'Maintenance');
  static const manageMaintenance = Permission(
      'manage_maintenance', 'Manage Maintenance',
      category: 'Maintenance');

  // ── Finance ───────────────────────────────────────────────
  static const viewFinance =
      Permission('view_finance', 'View Finance', category: 'Finance');
  static const manageExpenses =
      Permission('manage_expenses', 'Manage Expenses', category: 'Finance');

  // ── SMS ───────────────────────────────────────────────────
  static const viewSms = Permission('view_sms', 'View SMS', category: 'SMS');
  static const sendSms = Permission('send_sms', 'Send SMS', category: 'SMS');

  // ── Packages ──────────────────────────────────────────────
  static const viewPackages =
      Permission('view_packages', 'View Packages', category: 'Packages');
  static const managePackages =
      Permission('manage_packages', 'Manage Packages', category: 'Packages');

  // ── Users / Team ──────────────────────────────────────────
  static const viewUsers =
      Permission('view_users', 'View Users', category: 'Team');
  static const manageUsers =
      Permission('manage_users', 'Manage Users', category: 'Team');
  static const manageTeam =
      Permission('manage_team', 'Manage Team & Roles', category: 'Team');

  // ── Investors ─────────────────────────────────────────────
  static const manageInvestors =
      Permission('manage_investors', 'Manage Investors', category: 'Finance');

  // ── MikroTik ──────────────────────────────────────────────
  static const manageMikrotik = Permission(
      'manage_mikrotik', 'Manage MikroTik Devices',
      category: 'Technical');

  // ── Settings ──────────────────────────────────────────────
  static const viewSettings =
      Permission('view_settings', 'View Settings', category: 'Settings');
  static const manageSettings =
      Permission('manage_settings', 'Manage Settings', category: 'Settings');

  // ── Master list (ordered for UI) ──────────────────────────
  static const List<Permission> all = [
    viewDashboard,
    viewClients,
    createClient,
    editClient,
    deleteClient,
    viewVouchers,
    createVoucher,
    deleteVoucher,
    viewSales,
    makeSale,
    viewSites,
    manageSites,
    viewAssets,
    manageAssets,
    viewMaintenance,
    manageMaintenance,
    viewFinance,
    manageExpenses,
    manageInvestors,
    viewSms,
    sendSms,
    viewPackages,
    managePackages,
    viewUsers,
    manageUsers,
    manageTeam,
    manageMikrotik,
    viewSettings,
    manageSettings,
  ];

  static Permission? fromName(String name) {
    try {
      return all.firstWhere((p) => p.name == name);
    } catch (_) {
      return null;
    }
  }

  static Map<String, List<Permission>> get grouped {
    final map = <String, List<Permission>>{};
    for (final p in all) {
      map.putIfAbsent(p.category, () => []).add(p);
    }
    return map;
  }
}

// ---------------------------------------------------------------------------
// Built-in Role descriptor (static compile-time definitions)
// ---------------------------------------------------------------------------
class RoleDefinition {
  final String id;
  final String name;
  final String description;
  final List<Permission> permissions;

  const RoleDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
  });
}

// Backward-compat alias so existing code referencing `Role` still compiles.
typedef Role = RoleDefinition;

class Roles {
  static const superAdmin = RoleDefinition(
    id: 'SUPER_ADMIN',
    name: 'Super Admin',
    description: 'Full system access',
    permissions: Permissions.all,
  );

  static const admin = RoleDefinition(
    id: 'ADMIN',
    name: 'Admin',
    description: 'Administrator — full access except super-admin controls',
    permissions: [
      Permissions.viewDashboard,
      Permissions.viewClients,
      Permissions.createClient,
      Permissions.editClient,
      Permissions.deleteClient,
      Permissions.viewVouchers,
      Permissions.createVoucher,
      Permissions.deleteVoucher,
      Permissions.viewSales,
      Permissions.makeSale,
      Permissions.viewSites,
      Permissions.manageSites,
      Permissions.viewAssets,
      Permissions.manageAssets,
      Permissions.viewMaintenance,
      Permissions.manageMaintenance,
      Permissions.viewFinance,
      Permissions.manageExpenses,
      Permissions.viewSms,
      Permissions.sendSms,
      Permissions.viewPackages,
      Permissions.managePackages,
      Permissions.viewUsers,
      Permissions.manageUsers,
      Permissions.manageTeam,
      Permissions.viewSettings,
      Permissions.manageSettings,
      Permissions.manageInvestors,
      Permissions.manageMikrotik,
    ],
  );

  static const marketing = RoleDefinition(
    id: 'MARKETING',
    name: 'Marketing',
    description: 'Client management and SMS',
    permissions: [
      Permissions.viewDashboard,
      Permissions.viewClients,
      Permissions.createClient,
      Permissions.editClient,
      Permissions.viewVouchers,
      Permissions.createVoucher,
      Permissions.viewSites,
      Permissions.viewSms,
      Permissions.sendSms,
      Permissions.viewPackages,
      Permissions.viewSettings,
    ],
  );

  static const sales = RoleDefinition(
    id: 'SALES',
    name: 'Sales',
    description: 'Sales and POS operations',
    permissions: [
      Permissions.viewDashboard,
      Permissions.viewClients,
      Permissions.createClient,
      Permissions.viewVouchers,
      Permissions.viewSales,
      Permissions.makeSale,
      Permissions.viewSites,
      Permissions.viewPackages,
      Permissions.viewSettings,
    ],
  );

  static const technical = RoleDefinition(
    id: 'TECHNICAL',
    name: 'Technical',
    description: 'Technical operations and maintenance',
    permissions: [
      Permissions.viewDashboard,
      Permissions.viewClients,
      Permissions.viewVouchers,
      Permissions.viewSites,
      Permissions.manageSites,
      Permissions.viewAssets,
      Permissions.manageAssets,
      Permissions.viewMaintenance,
      Permissions.manageMaintenance,
      Permissions.viewSettings,
      Permissions.manageMikrotik,
    ],
  );

  static const finance = RoleDefinition(
    id: 'FINANCE',
    name: 'Finance',
    description: 'Financial management',
    permissions: [
      Permissions.viewDashboard,
      Permissions.viewClients,
      Permissions.viewSales,
      Permissions.viewFinance,
      Permissions.manageExpenses,
      Permissions.manageInvestors,
      Permissions.viewPackages,
      Permissions.viewSettings,
    ],
  );

  static const agent = RoleDefinition(
    id: 'AGENT',
    name: 'Agent',
    description: 'Basic sales agent',
    permissions: [
      Permissions.viewDashboard,
      Permissions.viewClients,
      Permissions.viewVouchers,
      Permissions.createVoucher,
      Permissions.viewSales,
      Permissions.makeSale,
      Permissions.viewPackages,
    ],
  );

  static List<RoleDefinition> get allRoles =>
      [superAdmin, admin, marketing, sales, technical, finance, agent];

  static RoleDefinition? getRole(String id) {
    try {
      return allRoles.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns all permission names for a set of built-in role IDs.
  static Set<String> permissionsForRoles(List<String> roleIds) {
    final result = <String>{};
    for (final id in roleIds) {
      final role = getRole(id);
      if (role != null) {
        for (final p in role.permissions) {
          result.add(p.name);
        }
      }
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// PermissionChecker
// Resolution order:
//   1. SUPER_ADMIN → always granted.
//   2. Per-user explicit DENY override → denied.
//   3. Per-user explicit GRANT override → granted.
//   4. Built-in role includes permission → granted.
//   5. Custom DB role includes permission → granted.
//   6. Otherwise → denied.
// ---------------------------------------------------------------------------
class PermissionChecker {
  /// Role IDs from the `roles` table (built-in system roles).
  final List<String> userRoles;

  /// Permission names granted by the user's *custom* roles (from DB).
  final Set<String> customRolePermissions;

  /// Per-user overrides: permission name → is_granted flag.
  final Map<String, bool> overrides;

  PermissionChecker(
    this.userRoles, {
    this.customRolePermissions = const {},
    this.overrides = const {},
  });

  bool get isSuperAdmin => userRoles.contains('SUPER_ADMIN');

  bool hasPermission(Permission permission) =>
      hasPermissionByName(permission.name);

  bool hasPermissionByName(String permissionName) {
    if (isSuperAdmin) return true;

    // Explicit deny
    if (overrides[permissionName] == false) return false;

    // Explicit grant
    if (overrides[permissionName] == true) return true;

    // Built-in role
    if (Roles.permissionsForRoles(userRoles).contains(permissionName)) {
      return true;
    }

    // Custom role
    return customRolePermissions.contains(permissionName);
  }

  bool hasAnyRole(List<String> roleIds) =>
      userRoles.any((r) => roleIds.contains(r));

  bool hasAllRoles(List<String> roleIds) =>
      roleIds.every((r) => userRoles.contains(r));

  bool canAccessRoute(String routePath) {
    final perms = _routePermissions(routePath);
    if (perms.isEmpty) return true;
    return perms.any(hasPermission);
  }

  /// Full resolved permission set (for display in profile / team screens).
  Set<String> get effectivePermissions {
    final result = <String>{};
    for (final p in Permissions.all) {
      if (hasPermissionByName(p.name)) result.add(p.name);
    }
    return result;
  }

  static List<Permission> _routePermissions(String routePath) {
    const map = {
      '/': [Permissions.viewDashboard],
      '/clients': [Permissions.viewClients],
      '/vouchers': [Permissions.viewVouchers],
      '/sales': [Permissions.viewSales],
      '/pos': [Permissions.makeSale],
      '/sites': [Permissions.viewSites],
      '/assets': [Permissions.viewAssets],
      '/maintenance': [Permissions.viewMaintenance],
      '/finance': [Permissions.viewFinance],
      '/expenses': [Permissions.manageExpenses],
      '/investors': [Permissions.manageInvestors],
      '/commission-demands': [Permissions.manageExpenses],
      '/voucher-quota': [Permissions.manageExpenses],
      '/sms': [Permissions.viewSms],
      '/packages': [Permissions.viewPackages],
      '/users': [Permissions.viewUsers],
      '/team-management': [Permissions.manageTeam],
      '/settings': [Permissions.viewSettings],
      '/mikrotik': [Permissions.manageMikrotik],
      '/mikrotik/dashboard': [Permissions.manageMikrotik],
    };
    return map[routePath] ?? const [];
  }
}
