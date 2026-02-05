// Role-Based Access Control (RBAC) Configuration

class Permission {
  final String name;
  final String description;

  const Permission(this.name, this.description);
}

class Permissions {
  // Dashboard
  static const viewDashboard = Permission('view_dashboard', 'View Dashboard');

  // Clients
  static const viewClients = Permission('view_clients', 'View Clients');
  static const createClient = Permission('create_client', 'Create Client');
  static const editClient = Permission('edit_client', 'Edit Client');
  static const deleteClient = Permission('delete_client', 'Delete Client');

  // Vouchers
  static const viewVouchers = Permission('view_vouchers', 'View Vouchers');
  static const createVoucher = Permission('create_voucher', 'Create Voucher');
  static const deleteVoucher = Permission('delete_voucher', 'Delete Voucher');

  // Sales/POS
  static const viewSales = Permission('view_sales', 'View Sales');
  static const makeSale = Permission('make_sale', 'Make Sale (POS)');

  // Sites
  static const viewSites = Permission('view_sites', 'View Sites');
  static const manageSites = Permission('manage_sites', 'Manage Sites');

  // Assets
  static const viewAssets = Permission('view_assets', 'View Assets');
  static const manageAssets = Permission('manage_assets', 'Manage Assets');

  // Maintenance
  static const viewMaintenance =
      Permission('view_maintenance', 'View Maintenance');
  static const manageMaintenance =
      Permission('manage_maintenance', 'Manage Maintenance');

  // Finance
  static const viewFinance = Permission('view_finance', 'View Finance');
  static const manageExpenses =
      Permission('manage_expenses', 'Manage Expenses');

  // SMS
  static const viewSms = Permission('view_sms', 'View SMS');
  static const sendSms = Permission('send_sms', 'Send SMS');

  // Packages
  static const viewPackages = Permission('view_packages', 'View Packages');
  static const managePackages =
      Permission('manage_packages', 'Manage Packages');

  // Users
  static const viewUsers = Permission('view_users', 'View Users');
  static const manageUsers = Permission('manage_users', 'Manage Users');

  // Settings
  static const viewSettings = Permission('view_settings', 'View Settings');
  static const manageSettings =
      Permission('manage_settings', 'Manage Settings');
}

// Role definitions with their permissions
class Role {
  final String id;
  final String name;
  final String description;
  final List<Permission> permissions;

  const Role({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
  });
}

class Roles {
  static const superAdmin = Role(
    id: 'SUPER_ADMIN',
    name: 'Super Admin',
    description: 'Full system access',
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
      Permissions.viewSettings,
      Permissions.manageSettings,
    ],
  );

  static const marketing = Role(
    id: 'MARKETING',
    name: 'Marketing',
    description: 'Client management and SMS',
    permissions: [
      Permissions.viewDashboard,
      Permissions.viewClients,
      Permissions.createClient,
      Permissions.editClient,
      Permissions.viewSites,
      Permissions.viewSms,
      Permissions.sendSms,
      Permissions.viewPackages,
      Permissions.viewSettings,
    ],
  );

  static const sales = Role(
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

  static const technical = Role(
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
    ],
  );

  static const finance = Role(
    id: 'FINANCE',
    name: 'Finance',
    description: 'Financial management',
    permissions: [
      Permissions.viewDashboard,
      Permissions.viewClients,
      Permissions.viewSales,
      Permissions.viewFinance,
      Permissions.manageExpenses,
      Permissions.viewPackages,
      Permissions.viewSettings,
    ],
  );

  static const agent = Role(
    id: 'AGENT',
    name: 'Agent',
    description: 'Basic sales agent',
    permissions: [
      Permissions.viewDashboard,
      Permissions.viewClients,
      Permissions.viewVouchers,
      Permissions.viewSales,
      Permissions.makeSale,
      Permissions.viewPackages,
    ],
  );

  static List<Role> get allRoles => [
        superAdmin,
        marketing,
        sales,
        technical,
        finance,
        agent,
      ];

  static Role? getRole(String id) {
    try {
      return allRoles.firstWhere((role) => role.id == id);
    } catch (e) {
      return null;
    }
  }
}

// Permission checker
class PermissionChecker {
  final List<String> userRoles;

  PermissionChecker(this.userRoles);

  bool hasPermission(Permission permission) {
    for (final roleId in userRoles) {
      final role = Roles.getRole(roleId);
      if (role != null && role.permissions.contains(permission)) {
        return true;
      }
    }
    return false;
  }

  bool hasAnyRole(List<String> roleIds) {
    return userRoles.any((userRole) => roleIds.contains(userRole));
  }

  bool hasAllRoles(List<String> roleIds) {
    return roleIds.every((roleId) => userRoles.contains(roleId));
  }

  bool canAccessRoute(String routePath) {
    final routePermissions = _getRoutePermissions(routePath);
    if (routePermissions.isEmpty) return true; // Public route

    return routePermissions.any((permission) => hasPermission(permission));
  }

  List<Permission> _getRoutePermissions(String routePath) {
    final permissionMap = {
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
      '/sms': [Permissions.viewSms],
      '/packages': [Permissions.viewPackages],
      '/users': [Permissions.viewUsers],
      '/settings': [Permissions.viewSettings],
    };

    return permissionMap[routePath] ?? [];
  }
}
