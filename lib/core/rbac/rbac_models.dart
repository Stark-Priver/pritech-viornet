// ============================================================
// rbac_models.dart
// Models for custom roles, role permissions, and
// per-user permission overrides stored in Supabase.
// ============================================================

// ---------------------------------------------------------------------------
// CustomRole — a role created (or seeded) in the custom_roles table
// ---------------------------------------------------------------------------
class CustomRole {
  final int id;
  final String name;
  final String description;
  final String color; // hex colour string e.g. '#6366F1'
  final String icon; // material icon name string
  final bool isSystem; // true = built-in, cannot be deleted/edited
  final bool isActive;
  final int? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Loaded separately — permissions assigned to this role
  final List<String> permissions;

  const CustomRole({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
    required this.isSystem,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.permissions = const [],
  });

  factory CustomRole.fromJson(Map<String, dynamic> json,
          {List<String> permissions = const []}) =>
      CustomRole(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        color: json['color'] as String? ?? '#6366F1',
        icon: json['icon'] as String? ?? 'person',
        isSystem: json['is_system'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        createdBy: json['created_by'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        permissions: permissions,
      );

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'description': description,
        'color': color,
        'icon': icon,
        'is_system': false,
        'is_active': isActive,
        if (createdBy != null) 'created_by': createdBy,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

  Map<String, dynamic> toUpdateJson() => {
        'name': name,
        'description': description,
        'color': color,
        'icon': icon,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

  CustomRole copyWith({
    String? name,
    String? description,
    String? color,
    String? icon,
    bool? isSystem,
    bool? isActive,
    List<String>? permissions,
  }) =>
      CustomRole(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        color: color ?? this.color,
        icon: icon ?? this.icon,
        isSystem: isSystem ?? this.isSystem,
        isActive: isActive ?? this.isActive,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        permissions: permissions ?? this.permissions,
      );
}

// ---------------------------------------------------------------------------
// UserPermissionOverride — explicit GRANT or DENY for one user + permission
// ---------------------------------------------------------------------------
class UserPermissionOverride {
  final int id;
  final int userId;
  final String permission; // matches Permission.name
  final bool isGranted; // true = grant, false = deny
  final String? reason;
  final int? setBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserPermissionOverride({
    required this.id,
    required this.userId,
    required this.permission,
    required this.isGranted,
    this.reason,
    this.setBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserPermissionOverride.fromJson(Map<String, dynamic> json) =>
      UserPermissionOverride(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        permission: json['permission'] as String,
        isGranted: json['is_granted'] as bool,
        reason: json['reason'] as String?,
        setBy: json['set_by'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toUpsertJson() => {
        'user_id': userId,
        'permission': permission,
        'is_granted': isGranted,
        'reason': reason,
        'set_by': setBy,
        'updated_at': DateTime.now().toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// UserCustomRole  (join: users ↔ custom_roles)
// ---------------------------------------------------------------------------
class UserCustomRole {
  final int id;
  final int userId;
  final int customRoleId;
  final int? assignedBy;
  final DateTime assignedAt;

  const UserCustomRole({
    required this.id,
    required this.userId,
    required this.customRoleId,
    this.assignedBy,
    required this.assignedAt,
  });

  factory UserCustomRole.fromJson(Map<String, dynamic> json) => UserCustomRole(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        customRoleId: json['custom_role_id'] as int,
        assignedBy: json['assigned_by'] as int?,
        assignedAt: DateTime.parse(json['assigned_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// UserWithPermissions — lightweight DTO used in Team Management screens
// ---------------------------------------------------------------------------
class UserWithPermissions {
  final int userId;
  final String name;
  final String email;
  final String? phone;
  final bool isActive;
  final List<String> roleNames; // from roles table (existing)
  final List<CustomRole> customRoles; // from custom_roles table
  final List<UserPermissionOverride> overrides;
  final Set<String> effectivePermissions; // resolved set

  const UserWithPermissions({
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    required this.isActive,
    required this.roleNames,
    required this.customRoles,
    required this.overrides,
    required this.effectivePermissions,
  });
}
