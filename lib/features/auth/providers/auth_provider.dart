import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../core/database/database.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/providers.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final AppDatabase _database;
  final SecureStorageService _storage;
  final ApiService _apiService;

  AuthNotifier(this._database, this._storage, this._apiService)
      : super(AuthState.initial()) {
    _checkAuthStatus();
  }

  // Check if user is already logged in
  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await _storage.isLoggedIn();
    if (isLoggedIn) {
      final userId = await _storage.getUserId();
      final userRole = await _storage.getUserRole();

      if (userId != null && userRole != null) {
        final user = await (_database.select(
          _database.users,
        )..where((tbl) => tbl.id.equals(int.parse(userId))))
            .getSingleOrNull();

        if (user != null) {
          state = AuthState.authenticated(user);
        } else {
          await logout();
        }
      }
    }
  }

  // Login
  Future<bool> login(String email, String password) async {
    try {
      state = AuthState.loading();

      // Hash password
      final hashedPassword = _hashPassword(password);

      debugPrint('🔐 Login attempt:');
      debugPrint('   Email: $email');
      debugPrint('   Hashed Password: $hashedPassword');

      // Check local database first (offline-first)
      final user = await (_database.select(_database.users)
            ..where(
              (tbl) =>
                  tbl.email.equals(email) &
                  tbl.passwordHash.equals(hashedPassword),
            ))
          .getSingleOrNull();

      debugPrint('   User found: ${user != null}');
      if (user != null) {
        debugPrint('   User active: ${user.isActive}');
        debugPrint('   User role: ${user.role}');
      }

      if (user != null && user.isActive) {
        // Save auth data
        await _storage.saveUserId(user.id.toString());
        await _storage.saveUserRole(user.role);
        await _storage.setLoggedIn(true);

        // Try to get token from server if online
        try {
          final response = await _apiService.post(
            '/auth/login',
            data: {'email': email, 'password': password},
          );

          if (response.statusCode == 200) {
            final token = response.data['access_token'];
            final refreshToken = response.data['refresh_token'];
            await _storage.saveAccessToken(token);
            await _storage.saveRefreshToken(refreshToken);
          }
        } catch (e) {
          // Ignore network errors, continue with offline mode
        }

        state = AuthState.authenticated(user);
        return true;
      } else {
        state = AuthState.unauthenticated(error: 'Invalid email or password');
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
    required String role,
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

      // Create user
      await _database.into(_database.users).insert(
            UsersCompanion.insert(
              name: name,
              email: email,
              phone: phone != null ? Value(phone) : const Value.absent(),
              role: role,
              passwordHash: hashedPassword,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      return true;
    } catch (e) {
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

  // Check if user has permission
  bool hasPermission(String requiredRole) {
    if (state.user == null) return false;

    final roleHierarchy = {
      'SUPER_ADMIN': 6,
      'MARKETING': 5,
      'SALES': 4,
      'TECHNICAL': 3,
      'FINANCE': 2,
      'AGENT': 1,
    };

    final userRoleLevel = roleHierarchy[state.user!.role] ?? 0;
    final requiredRoleLevel = roleHierarchy[requiredRole] ?? 0;

    return userRoleLevel >= requiredRoleLevel;
  }
}

// Auth State
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  factory AuthState.initial() => AuthState();

  factory AuthState.loading() => AuthState(isLoading: true);

  factory AuthState.authenticated(User user) => AuthState(user: user);

  factory AuthState.unauthenticated({String? error}) => AuthState(error: error);

  bool get isAuthenticated => user != null;
}

// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final database = ref.watch(databaseProvider);
  final storage = ref.watch(secureStorageProvider);
  final apiService = ref.watch(apiServiceProvider);
  return AuthNotifier(database, storage, apiService);
});
