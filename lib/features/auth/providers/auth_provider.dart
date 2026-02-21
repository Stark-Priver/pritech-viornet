import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/providers/providers.dart';
import '../../../core/rbac/permissions.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseDataService _svc;
  final SecureStorageService _storage;

  AuthNotifier(this._svc, this._storage) : super(AuthState.initial()) {
    _checkAuthStatus();
  }

  // Check if user is already logged in (stored session)
  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await _storage.isLoggedIn();
    if (isLoggedIn) {
      final userId = await _storage.getUserId();
      if (userId != null) {
        final user = await _svc.getUserById(int.parse(userId));
        if (user != null) {
          final userRoles = await _svc.getUserRoleNames(user.id);
          final userSites = await _svc.getUserSiteIds(user.id);
          state = AuthState.authenticated(user, userRoles, userSites);
        } else {
          await logout();
        }
      }
    }
  }

  // Login with email or phone + password
  Future<bool> login(String emailOrPhone, String password) async {
    try {
      state = AuthState.loading();

      final hashedPassword = _hashPassword(password);

      debugPrint('🔐 Login attempt:');
      debugPrint('   Email/Phone: $emailOrPhone');
      debugPrint('   Hashed Password: $hashedPassword');

      final user = await _svc.loginUser(emailOrPhone, hashedPassword);

      debugPrint('   User found: ${user != null}');
      if (user != null) {
        debugPrint('   User active: ${user.isActive}');
        debugPrint('   User role: ${user.role}');
      }

      if (user != null) {
        final userRoles = await _svc.getUserRoleNames(user.id);
        final userSites = await _svc.getUserSiteIds(user.id);

        await _storage.saveUserId(user.id.toString());
        await _storage.saveUserRole(user.role);
        await _storage.setLoggedIn(true);

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

      final existing = await _svc.getUserByEmail(email);
      if (existing != null) return false;

      final user = await _svc.createUser(
        name: name,
        email: email,
        passwordHash: hashedPassword,
        role: roleNames.isNotEmpty ? roleNames.first : 'AGENT',
        phone: phone,
      );

      for (final roleName in roleNames) {
        final role = await _svc.getRoleByName(roleName);
        if (role != null) {
          await _svc.assignUserRole(user.id, role.id);
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

      if (user.passwordHash != oldHash) return false;

      final newHash = _hashPassword(newPassword);
      await _svc.updateUser(user.id, {'password_hash': newHash});
      return true;
    } catch (e) {
      return false;
    }
  }

  // Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  AppUser? get currentUser => state.user;
  List<String> get currentUserRoles => state.userRoles;
  List<int> get currentUserSites => state.userSites;

  bool get canAccessAllSites {
    return state.userRoles.contains('SUPER_ADMIN') ||
        state.userRoles.contains('FINANCE');
  }

  bool hasPermission(Permission permission) {
    if (state.user == null || state.userRoles.isEmpty) return false;
    final checker = PermissionChecker(state.userRoles);
    return checker.hasPermission(permission);
  }

  bool canAccessRoute(String routePath) {
    if (state.user == null || state.userRoles.isEmpty) return false;
    final checker = PermissionChecker(state.userRoles);
    return checker.canAccessRoute(routePath);
  }

  bool hasAnyRole(List<String> roleNames) {
    if (state.user == null || state.userRoles.isEmpty) return false;
    final checker = PermissionChecker(state.userRoles);
    return checker.hasAnyRole(roleNames);
  }

  bool hasAllRoles(List<String> roleNames) {
    if (state.user == null || state.userRoles.isEmpty) return false;
    final checker = PermissionChecker(state.userRoles);
    return checker.hasAllRoles(roleNames);
  }
}

// Auth State
class AuthState {
  final AppUser? user;
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
          AppUser user, List<String> roles, List<int> sites) =>
      AuthState(user: user, userRoles: roles, userSites: sites);

  factory AuthState.unauthenticated({String? error}) => AuthState(error: error);

  bool get isAuthenticated => user != null;
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final svc = ref.watch(supabaseDataServiceProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthNotifier(svc, storage);
});
