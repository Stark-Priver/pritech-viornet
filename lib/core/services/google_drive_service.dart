import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  GoogleSignIn? _googleSignIn;
  drive.DriveApi? _driveApi;
  GoogleSignInAccount? _currentUser;

  static const List<String> _scopes = [
    drive.DriveApi.driveFileScope,
    drive.DriveApi.driveAppdataScope,
  ];

  static const String _dbFileName = 'viornet_local.db';
  static const String _folderName = 'ViorNet_Backup';

  // Initialize Google Sign In
  Future<void> initialize() async {
    _googleSignIn = GoogleSignIn(
      scopes: _scopes,
    );
  }

  // Check if user is signed in
  bool get isSignedIn => _currentUser != null;

  // Get current user
  GoogleSignInAccount? getCurrentUser() => _currentUser;

  // Get current user email
  String? get userEmail => _currentUser?.email;

  // Sign in to Google
  Future<bool> signIn() async {
    try {
      _googleSignIn ??= GoogleSignIn(scopes: _scopes);

      final account = await _googleSignIn!.signIn();
      if (account == null) {
        debugPrint('❌ Google Sign In cancelled');
        return false;
      }

      _currentUser = account;

      // Create authenticated HTTP client
      final authHeaders = await _currentUser!.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);

      _driveApi = drive.DriveApi(authenticateClient);

      debugPrint('✅ Google Drive connected: ${_currentUser!.email}');
      return true;
    } catch (e) {
      debugPrint('❌ Google Sign In error: $e');
      return false;
    }
  }

  // Sign out from Google
  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
      _currentUser = null;
      _driveApi = null;
      debugPrint('✅ Signed out from Google Drive');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
    }
  }

  // Upload database to Google Drive
  Future<bool> uploadDatabase() async {
    try {
      if (_driveApi == null) {
        final signedIn = await signIn();
        if (!signedIn) return false;
      }

      debugPrint('📤 Starting database upload to Google Drive...');

      // Get the database file
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, _dbFileName));

      if (!await dbFile.exists()) {
        debugPrint('❌ Database file not found');
        return false;
      }

      // Create or get ViorNet folder
      final folderId = await _getOrCreateFolder();

      // Check if database backup already exists
      final existingFileId = await _findExistingFile(folderId);

      final fileSize = await dbFile.length();
      debugPrint(
          '📦 Database size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      // Upload file
      final media = drive.Media(dbFile.openRead(), fileSize);

      if (existingFileId != null) {
        // Update existing file - don't include parents field for updates
        final updateFile = drive.File()
          ..name = _dbFileName
          ..description =
              'ViorNet Database Backup - ${DateTime.now().toIso8601String()}'
          ..modifiedTime = DateTime.now();

        await _driveApi!.files.update(
          updateFile,
          existingFileId,
          uploadMedia: media,
        );
        debugPrint('✅ Database updated on Google Drive');
      } else {
        // Create new file - include parents only for new files
        final newFile = drive.File()
          ..name = _dbFileName
          ..parents = [folderId]
          ..description =
              'ViorNet Database Backup - ${DateTime.now().toIso8601String()}'
          ..modifiedTime = DateTime.now();

        await _driveApi!.files.create(
          newFile,
          uploadMedia: media,
        );
        debugPrint('✅ Database uploaded to Google Drive');
      }

      return true;
    } catch (e) {
      debugPrint('❌ Upload failed: $e');
      return false;
    }
  }

  // Download database from Google Drive
  Future<bool> downloadDatabase() async {
    try {
      if (_driveApi == null) {
        final signedIn = await signIn();
        if (!signedIn) return false;
      }

      debugPrint('📥 Starting database download from Google Drive...');

      // Create or get ViorNet folder
      final folderId = await _getOrCreateFolder();

      // Find the database file
      final fileId = await _findExistingFile(folderId);

      if (fileId == null) {
        debugPrint('❌ No backup found on Google Drive');
        return false;
      }

      // Download the file
      final response = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

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
      final bytes = <int>[];
      await for (var data in response.stream) {
        bytes.addAll(data);
      }

      await dbFile.writeAsBytes(bytes);

      final fileSize = await dbFile.length();
      debugPrint(
          '✅ Database downloaded: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      return true;
    } catch (e) {
      debugPrint('❌ Download failed: $e');
      return false;
    }
  }

  // Get or create ViorNet backup folder
  Future<String> _getOrCreateFolder() async {
    try {
      // Search for existing folder
      final query =
          "name='$_folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final fileList = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id!;
      }

      // Create new folder
      final folder = drive.File()
        ..name = _folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await _driveApi!.files.create(folder);
      debugPrint('📁 Created backup folder: $_folderName');

      return createdFolder.id!;
    } catch (e) {
      debugPrint('❌ Folder creation failed: $e');
      rethrow;
    }
  }

  // Find existing database file
  Future<String?> _findExistingFile(String folderId) async {
    try {
      final query =
          "name='$_dbFileName' and '$folderId' in parents and trashed=false";
      final fileList = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        orderBy: 'modifiedTime desc',
        $fields: 'files(id, name, modifiedTime)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final file = fileList.files!.first;
        debugPrint(
            '📄 Found existing file: ${file.name} (${file.modifiedTime})');
        return file.id;
      }

      return null;
    } catch (e) {
      debugPrint('❌ File search failed: $e');
      return null;
    }
  }

  // Get last sync time from Google Drive
  Future<DateTime?> getLastSyncTime() async {
    try {
      if (_driveApi == null) return null;

      final folderId = await _getOrCreateFolder();
      final query =
          "name='$_dbFileName' and '$folderId' in parents and trashed=false";
      final fileList = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        orderBy: 'modifiedTime desc',
        $fields: 'files(modifiedTime)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.modifiedTime;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Failed to get last sync time: $e');
      return null;
    }
  }
}

// Custom HTTP client for Google APIs authentication
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
