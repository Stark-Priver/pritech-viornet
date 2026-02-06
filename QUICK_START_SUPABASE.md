# Quick Implementation Guide - Supabase Cloud Sync

## 🚀 Get Started in 5 Steps

### Step 1: Install Dependencies (2 minutes)

```powershell
flutter pub get
```

### Step 2: Create FREE Supabase Project (5 minutes)

1. Go to https://supabase.com/
2. Sign up/in (free)
3. Create new project
4. Copy **Project URL** and **anon key**

### Step 3: Create Storage Bucket (3 minutes)

1. In Supabase dashboard → **Storage**
2. Create bucket: `viornet-backups` (private)
3. Add policy:
   ```sql
   (bucket_id = 'viornet-backups'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)
   ```

### Step 4: Update main.dart (1 minute)

Add BEFORE `runApp()`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/supabase_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SupabaseSyncService.initialize(
    supabaseUrl: 'YOUR_PROJECT_URL',      // Replace this
    supabaseAnonKey: 'YOUR_ANON_KEY',     // Replace this
  );
  
  runApp(const MyApp());
}
```

### Step 5: Update Sync Methods (4 minutes)

**In `lib/features/auth/screens/login_screen.dart`:**

Add import:
```dart
import '../widgets/supabase_auth_dialog.dart';
```

Replace `_handleSyncFromCloud()` with:
```dart
Future<void> _handleSyncFromCloud() async {
  try {
    final supabaseService = ref.read(supabaseSyncServiceProvider);

    if (!supabaseService.isSignedIn) {
      final authenticated = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const SupabaseAuthDialog(isDownload: true),
      );
      if (authenticated != true) return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Downloading from cloud...'),
              ],
            ),
          ),
        ),
      ),
    );

    final downloadSuccess = await supabaseService.downloadDatabase();

    if (!mounted) return;
    Navigator.pop(context);

    if (downloadSuccess) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Sync Successful'),
            ],
          ),
          content: const Text(
            'Database synced from cloud. Please restart the app.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please restart the app'),
                    duration: Duration(seconds: 5),
                  ),
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No backup found or download failed'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
    );
  }
}
```

**In `lib/core/layout/main_layout.dart`:**

Add import:
```dart
import '../../features/auth/widgets/supabase_auth_dialog.dart';
```

Replace `_handleSyncToCloud()` with:
```dart
Future<void> _handleSyncToCloud() async {
  if (_isSyncing) return;

  setState(() => _isSyncing = true);

  try {
    final supabaseService = ref.read(supabaseSyncServiceProvider);

    if (!supabaseService.isSignedIn) {
      final authenticated = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const SupabaseAuthDialog(isDownload: false),
      );

      if (authenticated != true) {
        setState(() => _isSyncing = false);
        return;
      }
    }

    final uploadSuccess = await supabaseService.uploadDatabase();

    if (uploadSuccess) {
      final lastSync = await supabaseService.getLastSyncTime();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Data synced to cloud${lastSync != null ? ' at ${_formatTime(lastSync)}' : ''}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to sync to cloud'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
    );
  } finally {
    if (mounted) {
      setState(() => _isSyncing = false);
    }
  }
}
```

---

## ✅ Done! Run Your App

```powershell
flutter run -d windows
```

**No more plugin errors!** 🎉

---

## 📱 User Flow

1. User clicks "Sync from Cloud"
2. Dialog appears: Sign up or Sign in
3. User creates account with email/password
4. Data syncs automatically
5. Works on ALL devices!

---

## 📚 Full Documentation

- **[SUPABASE_SYNC_SETUP.md](./SUPABASE_SYNC_SETUP.md)** - Complete guide
- **[SUPABASE_MIGRATION_SUMMARY.md](./SUPABASE_MIGRATION_SUMMARY.md)** - Technical details

---

## 🆘 Need Help?

Check the troubleshooting sections in the full guides or file an issue.

**Status**: ✅ Ready to use!
