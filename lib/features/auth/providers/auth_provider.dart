import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/providers/providers.dart';
import '../../../core/rbac/permissions.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final AppDatabase _database;
  final SecureStorageService _storage;

  AuthNotifier(this._database, this._storage) : super(AuthState.initial()) {
    _checkAuthStatus();
  }

  // Check if user is already logged in
  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await _storage.isLoggedIn();
    if (isLoggedIn) {
      final userId = await _storage.getUserId();

      if (userId != null) {
        final user = await (_database.select(
          _database.users,
        )..where((tbl) => tbl.id.equals(int.parse(userId))))
            .getSingleOrNull();

        if (user != null) {
          // Load user roles and sites
          final userRoles = await _loadUserRoles(user.id);
          final userSites = await _loadUserSites(user.id);
          state = AuthState.authenticated(user, userRoles, userSites);
        } else {
          await logout();
        }
      }
    }
  }

  // Load user roles from database
  Future<List<String>> _loadUserRoles(int userId) async {
    final query = _database.select(_database.userRoles).join([
      innerJoin(
        _database.roles,
        _database.roles.id.equalsExp(_database.userRoles.roleId),
      ),
    ])
      ..where(_database.userRoles.userId.equals(userId));

    final results = await query.get();
    return results.map((row) => row.readTable(_database.roles).name).toList();
  }

  // Load user's assigned sites from database
  Future<List<int>> _loadUserSites(int userId) async {
    final query = _database.select(_database.userSites)
      ..where((tbl) => tbl.userId.equals(userId));

    final results = await query.get();
    return results.map((row) => row.siteId).toList();
  }

  // Login with email or phone
  Future<bool> login(String emailOrPhone, String password) async {
    try {
      state = AuthState.loading();

      // Hash password
      final hashedPassword = _hashPassword(password);

      debugPrint('🔐 Login attempt:');
      debugPrint('   Email/Phone: $emailOrPhone');
      debugPrint('   Hashed Password: $hashedPassword');

      // Check local database first (offline-first) - support email OR phone
      final user = await (_database.select(_database.users)
            ..where(
              (tbl) =>
                  (tbl.email.equals(emailOrPhone) |
                      tbl.phone.equals(emailOrPhone)) &
                  tbl.passwordHash.equals(hashedPassword),
            ))
          .getSingleOrNull();

      debugPrint('   User found: ${user != null}');
      if (user != null) {
        debugPrint('   User active: ${user.isActive}');
        debugPrint('   User role: ${user.role}');
      }

      if (user != null && user.isActive) {
        // Load user roles and sites
        final userRoles = await _loadUserRoles(user.id);
        final userSites = await _loadUserSites(user.id);

        // Save auth data
        await _storage.saveUserId(user.id.toString());
        await _storage
            .saveUserRole(user.role); // Keep for backward compatibility
        await _storage.setLoggedIn(true);

        // Local authentication only - no external API calls needed
        // Token management removed as we're using local SQLite auth

        state = AuthState.authenticated(user, userRoles, userSites);
        return true;
      } else {
        state =
            AuthState.unauthenticated(error: 'Invalid email/phone or password');
        return false;
      }
    } catch (e) {
      state = AuthState.unauthenticated(error: 'Login failed: $e');
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _storage.clearAuthData();
    state = AuthState.unauthenticated();
  }

  // Register new user (admin only)
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required List<String> roleNames,
    String? phone,
  }) async {
    try {
      final hashedPassword = _hashPassword(password);

      // Check if email already exists
      final existing = await (_database.select(
        _database.users,
      )..where((tbl) => tbl.email.equals(email)))
          .getSingleOrNull();

      if (existing != null) {
        return false;
      }

      // Create user - use first role as primary for backward compatibility
      final userId = await _database.into(_database.users).insert(
            UsersCompanion.insert(
              serverId: Value(
                  const Uuid().v4()), // Generate UUID for cross-device sync
              name: name,
              email: email,
              phone: phone != null ? Value(phone) : const Value.absent(),
              role: roleNames.isNotEmpty ? roleNames.first : 'AGENT',
              passwordHash: hashedPassword,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // Assign roles to user
      for (final roleName in roleNames) {
        final role = await (_database.select(_database.roles)
              ..where((tbl) => tbl.name.equals(roleName)))
            .getSingleOrNull();

        if (role != null) {
          await _database.into(_database.userRoles).insert(
                UserRolesCompanion.insert(
                  userId: userId,
                  roleId: role.id,
                  assignedAt: DateTime.now(),
                ),
              );
        }
      }

      return true;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    }
  }

  // Change password
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (state.user == null) return false;

    try {
      final user = state.user!;
      final oldHash = _hashPassword(oldPassword);

      if (user.passwordHash != oldHash) {
        return false;
      }

      final newHash = _hashPassword(newPassword);
      await (_database.update(
        _database.users,
      )..where((tbl) => tbl.id.equals(user.id)))
          .write(
        UsersCompanion(
          passwordHash: Value(newHash),
          updatedAt: Value(DateTime.now()),
        ),
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  // Hash password
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Get current user
  User? get currentUser => state.user;

  // Get current user roles
  List<String> get currentUserRoles => state.userRoles;

  // Get current user's assigned sites
  List<int> get currentUserSites => state.userSites;

  // Check if user can access all sites (SUPER_ADMIN or FINANCE)
  bool get canAccessAllSites {
    return state.userRoles.contains('SUPER_ADMIN') ||
        state.userRoles.contains('FINANCE');
  }

  // Check if user has specific permission
  bool hasPermission(Permission permission) {
    if (state.user == null || state.userRoles.isEmpty) return false;

    final checker = PermissionChecker(state.userRoles);
    return checker.hasPermission(permission);
  }

  // Check if user can access a route
  bool canAccessRoute(String routePath) {
    if (state.user == null || state.userRoles.isEmpty) return false;

    final checker = PermissionChecker(state.userRoles);
    return checker.canAccessRoute(routePath);
  }

  // Check if user has any of the specified roles
  bool hasAnyRole(List<String> roleNames) {
    if (state.user == null || state.userRoles.isEmpty) return false;

    final checker = PermissionChecker(state.userRoles);
    return checker.hasAnyRole(roleNames);
  }

  // Check if user has all of the specified roles
  bool hasAllRoles(List<String> roleNames) {
    if (state.user == null || state.userRoles.isEmpty) return false;

    final checker = PermissionChecker(state.userRoles);
    return checker.hasAllRoles(roleNames);
  }
}

// Auth State
class AuthState {
  final User? user;
  final List<String> userRoles;
  final List<int> userSites;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.userRoles = const [],
    this.userSites = const [],
    this.isLoading = false,
    this.error,
  });

  factory AuthState.initial() => AuthState();

  factory AuthState.loading() => AuthState(isLoading: true);

  factory AuthState.authenticated(
          User user, List<String> roles, List<int> sites) =>
      AuthState(user: user, userRoles: roles, userSites: sites);

  factory AuthState.unauthenticated({String? error}) => AuthState(error: error);

  bool get isAuthenticated => user != null;
}

// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final database = ref.watch(databaseProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthNotifier(database, storage);
});
