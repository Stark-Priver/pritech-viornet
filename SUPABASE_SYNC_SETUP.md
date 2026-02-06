# Supabase Cloud Sync - FREE Cross-Platform Setup

This guide will help you set up **FREE** cloud synchronization for ViorNet using Supabase. Each user creates their own FREE Supabase account to sync their data.

## ✨ Why Supabase?

- ✅ **100% FREE** tier (1GB storage, 2GB bandwidth per month)
- ✅ **Works on ALL platforms** (Windows, Android, iOS, Web, Linux, macOS)
- ✅ **Each user has their own account** (no shared credentials)
- ✅ **No plugin issues** (pure HTTP API, no platform-specific dependencies)
- ✅ **Built-in authentication** (email/password)
- ✅ **Secure** (OAuth 2.0, encrypted connections)
- ✅ **Easy setup** (15 minutes)

## 📋 Prerequisites

- Internet connection
- Email address (for Supabase account)

---

## Part 1: Developer Setup (One-Time)

### Step 1: Create FREE Supabase Project

1. Go to [supabase.com](https://supabase.com/)
2. Click **"Start your project"** (free)
3. Sign in with GitHub, Google, or email
4. Click **"New project"**
5. Fill in:
   - **Name**: `viornet` (or any name you want)
   - **Database Password**: Create a strong password (save it!)
   - **Region**: Choose closest to you
   - **Pricing Plan**: Select **FREE**
6. Click **"Create new project"**
7. Wait 2-3 minutes for project to initialize

### Step 2: Get Your Supabase Credentials

1. In your Supabase dashboard, go to **Settings** (⚙️) > **API**
2. Copy these values:
   - **Project URL** (looks like: `https://xxxxxxxxxxxxx.supabase.co`)
   - **anon public** key (long string starting with `eyJ...`)

### Step 3: Create Storage Bucket

1. In Supabase dashboard, go to **Storage** (📦)
2. Click **"New bucket"**
3. Name: `viornet-backups`
4. **Public bucket**: Toggle **OFF** (keep it private)
5. Click **"Create bucket"**
6. Click on the bucket, then **"Policies"** tab
7. Click **"New policy"** > **"For full customization"**
8. Create policy:
   - **Name**: `User can manage own files`
   - **Allowed operation**: All (SELECT, INSERT, UPDATE, DELETE)
   - **Policy definition**:
   ```sql
   (bucket_id = 'viornet-backups'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)
   ```
9. Click **"Review"** then **"Save policy"**

### Step 4: Update Your App Code

1. Open `lib/main.dart`
2. Add Supabase initialization BEFORE `runApp()`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/supabase_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseSyncService.initialize(
    supabaseUrl: 'https://xxxxxxxxxxxxx.supabase.co',  // YOUR PROJECT URL
    supabaseAnonKey: 'eyJxxxxxxxxxxxxxxxxx...',         // YOUR ANON KEY
  );
  
  runApp(const MyApp());
}
```

3. Replace `xxxxxxxxxxxxx.supabase.co` with YOUR Project URL
4. Replace `eyJxxxxxxxxxxxxxxxxx...` with YOUR anon key

### Step 5: Update Login Screen

Open `lib/features/auth/screens/login_screen.dart` and replace the `_handleSyncFromCloud` method:

```dart
Future<void> _handleSyncFromCloud() async {
  try {
    final supabaseService = ref.read(supabaseSyncServiceProvider);

    // Check if user is signed in to Supabase
    if (!supabaseService.isSignedIn) {
      // Show auth dialog
      final authenticated = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const SupabaseAuthDialog(isDownload: true),
      );

      if (authenticated != true) return;
    }

    // Show loading dialog
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

    // Download database
    final downloadSuccess = await supabaseService.downloadDatabase();

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (downloadSuccess) {
      // Show success dialog
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
            'Database synced from cloud. Please restart the app to load the data.',
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
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

Don't forget to add the import:
```dart
import '../widgets/supabase_auth_dialog.dart';
```

### Step 6: Update Main Layout (Upload Button)

Open `lib/core/layout/main_layout.dart` and replace the `_handleSyncToCloud` method:

```dart
Future<void> _handleSyncToCloud() async {
  if (_isSyncing) return;

  setState(() => _isSyncing = true);

  try {
    final supabaseService = ref.read(supabaseSyncServiceProvider);

    // Check if user is signed in
    if (!supabaseService.isSignedIn) {
      // Show auth dialog
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

    // Upload database
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
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _isSyncing = false);
    }
  }
}
```

Add the import:
```dart
import '../../features/auth/widgets/supabase_auth_dialog.dart';
```

### Step 7: Install Dependencies

```powershell
flutter pub get
```

### Step 8: Build and Test

```powershell
# For Windows
flutter run -d windows

# For Android
flutter run -d android

# For iOS
flutter run -d ios
```

---

## Part 2: End User Guide

### First Time Setup

1. **Launch ViorNet app**
2. Click **"Sync from Cloud"** button on login screen
3. Click **"Sign Up"** in the dialog
4. Enter your email and password (minimum 6 characters)
5. Click **"Sign Up"**
6. Check your email for verification link (optional for testing)
7. Sign in with your credentials
8. If you have a backup, it will download automatically
9. Restart the app

### Regular Usage - Backup to Cloud

1. Login to ViorNet
2. Click the **cloud icon** (☁️) in the top right corner
3. If not signed in, enter your credentials
4. Wait for "Data synced to cloud" message
5. Your database is now backed up!

### Using on Multiple Devices

1. Install ViorNet on new device
2. Click "Sync from Cloud" on login screen
3. Sign in with **your Supabase credentials** (email/password)
4. Your data downloads automatically
5. Restart app and login to ViorNet

### Important Notes

- 📧 Each user needs their **own Supabase account** (use your email)
- 🔒 Your credentials are **personal** - don't share them
- ☁️ FREE tier: 1GB storage (thousands of sync operations)
- 📱 Works on **all platforms** (Windows, Android, iOS, Web)
- 🔄 **Manual sync only** - click button when you want to backup

---

## 🔍 Troubleshooting

### "Failed to sign up"
- Check internet connection
- Use a valid email address
- Password must be at least 6 characters
- Email might already be registered - try signing in instead

### "Failed to download"
- Make sure you've uploaded a backup first
- Check if you're signed in with the correct account
- Verify internet connection

### "Invalid credentials"
- Double-check email and password
- Use "Forgot Password?" to reset if needed

### "No backup found"
- This is your first sync - upload a backup first
- Or you're signed in with wrong account

### Windows-specific issues
- None! Supabase works perfectly on Windows
- No platform-specific configuration needed

---

## 🔒 Security

- ✅ **Encrypted connections** (HTTPS)
- ✅ **Password hashed** (never stored in plain text)
- ✅ **Private storage** (only you can access your files)
- ✅ **No credentials in app** (authenticated via Supabase)
- ✅ **Email verification** (optional, recommended)

---

## 💰 Pricing (FREE Forever)

| Plan | Storage | Bandwidth | Users | Price |
|------|---------|-----------|-------|-------|
| **Free** | 1GB | 2GB/month | Unlimited | $0 |
| Pro | 8GB | 50GB/month | Unlimited | $25/month |

**For typical usage:**
- Average database size: 1-5MB
- Can sync **200+ times/month** on free tier
- Perfect for small teams and personal use

---

## 🆚 Comparison

| Feature | Supabase | Google Drive |
|---------|----------|--------------|
| **Windows Support** | ✅ Perfect | ❌ Plugin issues |
| **Cross-Platform** | ✅ All platforms | ⚠️ Mobile only |
| **User Accounts** | ✅ Personal | ❌ Shared |
| **Free Tier** | ✅ 1GB | ✅ 15GB |
| **Setup Time** | ⏱️ 15 min | ⏱️ 30 min |
| **Authentication** | ✅ Email/Password | ❌ OAuth (complex) |
| **Reliability** | ✅ Enterprise | ✅ Enterprise |

---

## 📚 Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Supabase Storage](https://supabase.com/docs/guides/storage)
- [Supabase Authentication](https://supabase.com/docs/guides/auth)

---

## 🎉 Quick Checklist

**Developer Setup:**
- [ ] Created FREE Supabase project
- [ ] Copied Project URL and anon key
- [ ] Created storage bucket `viornet-backups`
- [ ] Set up bucket policy
- [ ] Updated `main.dart` with credentials
- [ ] Updated `login_screen.dart`
- [ ] Updated `main_layout.dart`
- [ ] Ran `flutter pub get`
- [ ] Tested on Windows

**User Experience:**
- [ ] Can sign up with email/password
- [ ] Can sign in to existing account
- [ ] Can download backup from cloud
- [ ] Can upload backup to cloud
- [ ] Works on all devices
- [ ] No plugin errors!

---

**Implementation Date**: February 6, 2026  
**Status**: ✅ Ready to use on ALL platforms!  
**Cost**: 💯 FREE Forever (within limits)
