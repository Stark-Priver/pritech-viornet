import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Supabase-based cloud sync service
/// Works on all platforms (Windows, Android, iOS, Web)
/// Each user signs in with their own FREE Supabase account
class SupabaseSyncService {
  static final SupabaseSyncService _instance = SupabaseSyncService._internal();
  factory SupabaseSyncService() => _instance;
  SupabaseSyncService._internal();

  SupabaseClient? _client;

  static const String _dbFileName = 'viornet_local.db';
  static const String _bucketName = 'viornet-backups';

  // Initialize Supabase
  // Call this in main.dart before runApp
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // Get Supabase client
  SupabaseClient get client {
    _client ??= Supabase.instance.client;
    return _client!;
  }

  // Check if user is signed in
  bool get isSignedIn => client.auth.currentUser != null;

  // Get current user
  User? get currentUser => client.auth.currentUser;

  // Get current user email
  String? get userEmail => currentUser?.email;

  // Sign up new user
  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('✅ Supabase sign up successful: ${response.user!.email}');
        return true;
      }

      debugPrint('❌ Supabase sign up failed: No user returned');
      return false;
    } catch (e) {
      debugPrint('❌ Supabase sign up error: $e');
      return false;
    }
  }

  // Sign in existing user
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('✅ Supabase sign in successful: ${response.user!.email}');
        return true;
      }

      debugPrint('❌ Supabase sign in failed: No user returned');
      return false;
    } catch (e) {
      debugPrint('❌ Supabase sign in error: $e');
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
      debugPrint('✅ Supabase sign out successful');
    } catch (e) {
      debugPrint('❌ Supabase sign out error: $e');
    }
  }

  // Upload database to Supabase Storage
  Future<bool> uploadDatabase() async {
    try {
      if (!isSignedIn) {
        debugPrint('❌ User not signed in');
        return false;
      }

      debugPrint('📤 Starting database upload to Supabase...');

      // Get the database file
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, _dbFileName));

      if (!await dbFile.exists()) {
        debugPrint('❌ Database file not found');
        return false;
      }

      final fileSize = await dbFile.length();
      debugPrint(
          '📦 Database size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      // Read file bytes
      final bytes = await dbFile.readAsBytes();

      // Create bucket if it doesn't exist (first time)
      try {
        await client.storage.getBucket(_bucketName);
      } catch (e) {
        // Bucket doesn't exist, create it
        await client.storage.createBucket(
          _bucketName,
          const BucketOptions(public: false),
        );
        debugPrint('📁 Created backup bucket: $_bucketName');
      }

      // Upload file to SHARED team database path (overwrites if exists)
      // All authenticated users sync the same database
      final filePath =
          _dbFileName; // Shared: viornet_local.db (not user-specific)

      await client.storage.from(_bucketName).uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'application/octet-stream',
            ),
          );

      debugPrint(
          '👥 Uploaded to SHARED team database (accessible by all users)');

      debugPrint('✅ Database uploaded to Supabase');
      return true;
    } catch (e) {
      debugPrint('❌ Upload failed: $e');
      return false;
    }
  }

  // Download database from Supabase Storage
  Future<bool> downloadDatabase() async {
    try {
      if (!isSignedIn) {
        debugPrint('❌ User not signed in');
        return false;
      }

      debugPrint('📥 Starting database download from Supabase...');

      // Download from SHARED team database path
      final filePath =
          _dbFileName; // Shared: viornet_local.db (not user-specific)

      debugPrint(
          '👥 Downloading SHARED team database (synced across all users)');

      // Download the file
      final bytes = await client.storage.from(_bucketName).download(filePath);

      // Save to local database file
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, _dbFileName));

      // Backup existing database
      if (await dbFile.exists()) {
        final backupFile = File(p.join(
          dbFolder.path,
          'viornet_local_backup_${DateTime.now().millisecondsSinceEpoch}.db',
        ));
        await dbFile.copy(backupFile.path);
        debugPrint('💾 Existing database backed up');
      }

      // Write downloaded data
      await dbFile.writeAsBytes(bytes);

      final fileSize = await dbFile.length();
      debugPrint(
          '✅ Database downloaded: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      return true;
    } catch (e) {
      if (e is StorageException && e.statusCode == '404') {
        debugPrint('❌ No backup found on Supabase');
      } else {
        debugPrint('❌ Download failed: $e');
      }
      return false;
    }
  }

  // Check if backup exists
  Future<bool> hasBackup() async {
    try {
      if (!isSignedIn) return false;

      // Check for SHARED team database (no user-specific path)
      final files = await client.storage.from(_bucketName).list();

      return files.any((file) => file.name == _dbFileName);
    } catch (e) {
      debugPrint('❌ Backup check failed: $e');
      return false;
    }
  }

  // Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    try {
      if (!isSignedIn) return null;

      // Get SHARED team database info (no user-specific path)
      final files = await client.storage.from(_bucketName).list();

      final dbFile = files.firstWhere(
        (file) => file.name == _dbFileName,
        orElse: () => throw Exception('File not found'),
      );

      return dbFile.updatedAt != null
          ? DateTime.parse(dbFile.updatedAt!)
          : null;
    } catch (e) {
      debugPrint('❌ Failed to get last sync time: $e');
      return null;
    }
  }

  // Delete backup
  Future<bool> deleteBackup() async {
    try {
      if (!isSignedIn) return false;

      final userId = currentUser!.id;
      final filePath = '$userId/$_dbFileName';

      await client.storage.from(_bucketName).remove([filePath]);

      debugPrint('✅ Backup deleted from Supabase');
      return true;
    } catch (e) {
      debugPrint('❌ Delete backup failed: $e');
      return false;
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email);
      debugPrint('✅ Password reset email sent');
      return true;
    } catch (e) {
      debugPrint('❌ Password reset failed: $e');
      return false;
    }
  }
}
