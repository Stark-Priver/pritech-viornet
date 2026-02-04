import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Token Management
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: AppConstants.keyAccessToken, value: token);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.keyAccessToken);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: AppConstants.keyRefreshToken, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AppConstants.keyRefreshToken);
  }

  // User Data
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: AppConstants.keyUserId, value: userId);
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: AppConstants.keyUserId);
  }

  Future<void> saveUserRole(String role) async {
    await _storage.write(key: AppConstants.keyUserRole, value: role);
  }

  Future<String?> getUserRole() async {
    return await _storage.read(key: AppConstants.keyUserRole);
  }

  // Login Status
  Future<void> setLoggedIn(bool value) async {
    await _storage.write(
      key: AppConstants.keyIsLoggedIn,
      value: value.toString(),
    );
  }

  Future<bool> isLoggedIn() async {
    final value = await _storage.read(key: AppConstants.keyIsLoggedIn);
    return value == 'true';
  }

  // Sync Time
  Future<void> saveLastSyncTime(DateTime time) async {
    await _storage.write(
      key: AppConstants.keyLastSyncTime,
      value: time.toIso8601String(),
    );
  }

  Future<DateTime?> getLastSyncTime() async {
    final value = await _storage.read(key: AppConstants.keyLastSyncTime);
    if (value != null) {
      return DateTime.parse(value);
    }
    return null;
  }

  // Clear all data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Clear auth data only
  Future<void> clearAuthData() async {
    await _storage.delete(key: AppConstants.keyAccessToken);
    await _storage.delete(key: AppConstants.keyRefreshToken);
    await _storage.delete(key: AppConstants.keyUserId);
    await _storage.delete(key: AppConstants.keyUserRole);
    await _storage.delete(key: AppConstants.keyIsLoggedIn);
  }
}
