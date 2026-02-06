# Supabase PostgreSQL Sync Setup Guide

## 🎯 Overview

This guide sets up **proper online-offline sync** using:
- **Supabase PostgreSQL** - Cloud database for online operations
- **Local SQLite** - Offline-first local database  
- **Smart Record-Level Sync** - Only syncs changed records, not entire database
- **No Supabase Auth** - Authentication handled locally in Flutter app
- **Conflict Resolution** - Server wins on conflicts

---

## 📋 Setup Steps

### Step 1: Install Supabase CLI (Recommended Method)

#### On Windows:

**Option 1: Using Scoop (Recommended)**

```powershell
# If you don't have Scoop, install it first:
# Visit: https://scoop.sh or run:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# Then install Supabase CLI:
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Verify installation
supabase --version
```

**Option 2: Direct Download (Manual)**

```powershell
# Download the Windows binary
Invoke-WebRequest -Uri "https://github.com/supabase/cli/releases/latest/download/supabase_windows_amd64.zip" -OutFile "supabase.zip"

# Extract
Expand-Archive -Path "supabase.zip" -DestinationPath "$env:USERPROFILE\supabase-cli"

# Add to PATH (restart PowerShell after)
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:USERPROFILE\supabase-cli", "User")

# Verify (restart PowerShell first)
supabase --version
```

#### On Mac/Linux:

```bash
# Using Homebrew (Mac)
brew install supabase/tap/supabase

# Using apt (Linux)
sudo apt update && sudo apt install supabase

# Verify installation
supabase --version
```

### Step 2: Link Your Supabase Project

```powershell
# Login to Supabase
supabase login

# Link to your existing project
supabase link --project-ref bylovbbaatsigcfsdspn

# Enter your database password when prompted
```

### Step 3: Push Migrations to Supabase

```powershell
# Navigate to your project directory
cd f:\PROJECTS\viornet

# Push all migrations to Supabase
supabase db push

# This will automatically:
# ✅ Run 001_initial_schema.sql (creates all tables)
# ✅ Run 002_rls_policies.sql (sets up security policies)
```

That's it! Your database schema is now live on Supabase.

---

### Alternative: Manual Method (Without CLI)

If you prefer not to install Supabase CLI:

1. Go to https://supabase.com/dashboard
2. Select your project: **bylovbbaatsigcfsdspn**
3. Click **SQL Editor** in left sidebar
4. Click **New Query**

#### Migration 1: Create Tables

Copy and paste the entire content of:
```
supabase/migrations/001_initial_schema.sql
```

Click **Run** or press `Ctrl+Enter`

✅ This creates all tables matching your local SQLite schema

#### Migration 2: Set up RLS Policies

Copy and paste the entire content of:
```
supabase/migrations/002_rls_policies.sql
```

Click **Run** or press `Ctrl+Enter`

✅ This allows your app to access the database (since we're not using Supabase Auth)

### Step 4: Get Service Role Key

⚠️ **IMPORTANT**: You need the **Service Role Key**, not the anon key!

#### Using CLI:
```powershell
# Get your service role key
supabase status

# Look for "service_role key" in the output
```

#### Using Dashboard:
1. Go to **Settings** → **API** in Supabase dashboard
2. Find **Project API keys** section
3. Copy the **`service_role`** key (NOT the `anon public` key)
4. This key bypasses RLS since we handle auth locally

⚠️ Keep this key secure - it has full database access!

### Step 5: Update main.dart

Replace the Supabase initialization in `lib/main.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/supabase_postgres_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase PostgreSQL Sync (NO AUTH - just database)
  await SupabaseSyncService.initialize(
    supabaseUrl: 'https://bylovbbaatsigcfsdspn.supabase.co',
    supabaseServiceKey: 'YOUR_SERVICE_ROLE_KEY_HERE', // ⚠️ Use service role key!
  );

  // Initialize API Service
  ApiService().initialize();

  // Initialize local database
  await _initializeDatabase();
6: Update Providers

Update `lib/core/providers/providers.dart`:

```dart
import '../services/supabase_postgres_sync_service.dart';

// Replace old supabase provider with new one
final supabaseSyncServiceProvider = Provider<SupabaseSyncService>((ref) {
  return SupabaseSyncService();
});
```

### Step 7
import '../services/supabase_postgres_sync_service.dart';

// Replace old supabase provider with new one
final supabaseSyncServiceProvider = Provider<SupabaseSyncService>((ref) {
  return SupabaseSyncService();
});
```

### Step 5: Update Sync Buttons

#### In Login Screen (`lib/features/auth/screens/login_screen.dart`):

Replace the `_handleSyncFromCloud()` method:

```dart
Future<void> _handleSyncFromCloud() async {
  try {
    final syncService = ref.read(supabaseSyncServiceProvider);

    // Check connectivity
    final isConnected = await syncService.isConnected();
    if (!isConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading
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
                Text('Syncing from cloud...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Pull changes from cloud
    final result = await syncService.pullFromCloud();

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Synced ${result.pulled} records from cloud' +
            (result.conflicts > 0 ? ' (${result.conflicts} conflicts resolved)' : ''),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: ${result.errors.first}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

#### In Main Layout (`lib/core/layout/main_layout.dart`):

Replace the `_handleSyncToCloud()` method:

```dart
Future<void> _handleSyncToCloud() async {
  if (_isSyncing) return;

  setState(() {
    _isSyncing = true;
  });

  try {
    final syncService = ref.read(supabaseSyncServiceProvider);

    // Check connectivity
    final isConnected = await syncService.isConnected();
    if (!isConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() {
        _isSyncing = false;
      });
      return;
    }

    // Do full sync (push + pull)
    final result = await syncService.syncAll();

    if (!mounted) return;

    if (result.isSuccess) {
      final status = await syncService.getSyncStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Synced: ${result.pushed} pushed, ${result.pulled} pulled' +
            (result.conflicts > 0 ? '\n⚠️ ${result.conflicts} conflicts (server wins)' : ''),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: ${result.errors.first}'),
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
    if (m8: Run and Test

```powershell
flutter pub get
flutter run -d windows
```

---

## 🔧 Useful Supabase CLI Commands

### View Your Database

```powershell
# Open Supabase Studio locally (GUI for database)
supabase start

# View database in browser
# Opens at http://localhost:54323
```

### Manage Migrations

```powershell
# Create a new migration
supabase migration new my_migration_name

# List all migrations
supabase migration list

# Reset database (WARNING: deletes all data!)
supabase db reset

# Pull remote schema changes
supabase db pull

# Generate TypeScript types from database
supabase gen types typescript --local > lib/database_types.dart
```

### Check Database Status

```powershell
# View connection info and keys
supabase status

# Check if migrations are applied
supabase migration list --remote
```

### Troubleshooting

```powershell
# View logs
supabase logs

# Stop local Supabase (if started)
supabase stop

# Unlink project
supabase unlink
  }
}
```

### Step 6: Run and Test

```powershell
flutter pub get
flutter run -d windows
```

---

## 🔄 How Sync Works

### Architecture

```
Local SQLite (Offline-First)
    ↓
User makes changes locally
    ↓
isSynced = false (record marked as changed)
    ↓
User clicks "Sync to Cloud"
    ↓
Push: Only changed records sent to PostgreSQL
    ↓
Pull: Only changed records downloaded from PostgreSQL
    ↓
Local records updated with server_id
    ↓
isSynced = true, lastSyncedAt = now
```

### Key Fields

Every table has these sync fields:
- **`server_id`** - UUID from PostgreSQL (null if never synced)
- **`isSynced`** - false if local changes not yet pushed
- **`lastSyncedAt`** - timestamp of last successful sync
- **`created_at`** - record creation time
- **`updated_at`** - record last modification time (auto-updated)

### Sync Logic

#### Push (Local → Cloud):
1. Find all records where `isSynced = false`
2. For each record:
   - If `server_id` is null: INSERT into PostgreSQL
   - If `server_id` exists: UPDATE in PostgreSQL
3. Update local record: `isSynced = true`, `lastSyncedAt = now`

#### Pull (Cloud → Local):
1. Query PostgreSQL for records `WHERE updated_at > lastSync`
2. For each record:
   - Find local record by `server_id`
   - If exists:
     - Check if local also has `isSynced = false` → **CONFLICT!**
     - Resolve: Server wins (overwrite local)
   - If not exists: INSERT new record locally
3. Mark local record: `isSynced = true`, `lastSyncedAt = now`

### Conflict Resolution

**Simple Rule: Server Always Wins**

```
Scenario: Both local and server modified same record

Local:
- Client "John Doe" modified to "John Smith"
- isSynced = false (not yet pushed)

Server:
- Client "John Doe" modified to "John D." (by another device)

Result after sync:
- Local record updated to "John D." (server wins)
- Local changes "John Smith" are LOST
- User notified: "X conflicts resolved"
```

To avoid conflicts:
1. Sync frequently (before making changes)
2. Push immediately after changes
3. Coordinate with team members

---

## 🧪 Testing

### Test 1: Fresh Sync

```
Device A:
1. Log in
2. Add a new client "Test Client A"
3. Click "Sync to Cloud"
4. Should see: "Synced: 1 pushed, 0 pulled"

Device B:
1. Log in
2. Click "Sync from Cloud" on login screen
3. Should see: "Synced 1 records from cloud"
4. Open clients list → "Test Client A" should appear
```

### Test 2: Two-Way Sync

```
Device A:
1. Add client "Client A"
2. Sync to cloud

Device B:
1. Add client "Client B"  
2. Sync to cloud
3. Should see: "Synced: 1 pushed, 1 pulled"
4. Now has both "Client A" and "Client B"

Device A:
1. Sync to cloud
2. Should see: "Synced: 0 pushed, 1 pulled"
3. Now has both clients
```

### Test 3: Conflict Simulation

```
Both devices offline:

Device A:
1. Edit Client #5 name to "ABC Corp"
2. Do NOT sync yet

Device B:
1. Edit same Client #5 name to "XYZ Ltd"
2. Sync to cloud (goes online first)
3. Server now has "XYZ Ltd"

Device A:
1. Go online
2. Sync to cloud
3. Should see warning: "1 conflicts resolved"
4. Local Client #5 now shows "XYZ Ltd" (server wins)
5. "ABC Corp" change is lost
```

---

## 📊 Monitoring Sync

### Add Sync Status Indicator

Add this to your app bar in `main_layout.dart`:

```dart
// In AppBar actions
IconButton(
  icon: FutureBuilder<SyncStatus>(
    future: ref.read(supabaseSyncServiceProvider).getSyncStatus(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Icon(Icons.cloud_outlined);
      
      final status = snapshot.data!;
      if (!status.isConnected) {
        return const Icon(Icons.cloud_off, color: Colors.red);
      }
      if (status.hasPendingChanges) {
        return Badge(
          label: Text('${status.pendingChanges}'),
          child: const Icon(Icons.cloud_sync, color: Colors.orange),
        );
      }
      return const Icon(Icons.cloud_done, color: Colors.green);
    },
  ),
  onPressed: _handleSyncToCloud,
  tooltip: 'Sync Status',
),
```

---

## ⚠️ Important Notes

### Security

1. **Service Role Key**: Must be kept secure
   - Don't commit to git
   - Use environment variables in production
   - Consider code obfuscation

2. **No Supabase Auth**: 
   - Authentication is in local app only
   - Anyone with service key can access database
   - For production: Add API gateway or IP whitelist

3. **Data Encryption**:
   - Supabase uses HTTPS (encrypted in transit)
   - Consider encrypting sensitive fields (passwords, etc.)

### Performance

1. **Batch Size**: Currently syncs all changes
   - For large datasets: Implement pagination
   - Add progress indicators for long syncs

2. **Indexes**: Migration includes indexes on:
   - `server_id` (for lookups)
   - Foreign keys (for joins)
   - Common query fields (email, phone, etc.)

3. **Network**: 
   - Sync only over WiFi option (add to settings)
   - Compress large payloads
   - Handle timeouts gracefully

### Limitations

1. **Attachments/Files**: 
   - Current sync only handles database records
   - For files: Use Supabase Storage separately

2. **Real-time**: 
   - Current sync is manual (user-triggered)
   - For real-time: Add Supabase Realtime subscriptions

3. **Deleted Records**:
   - Currently no soft delete support
   - Implement `is_deleted` flag if needed

---

## 🔮 Future Enhancements

### Phase 2: Better Conflict Resolution
- [ ] Show conflict dialog to user
- [ ] Let user choose: keep local, use server, or merge
- [ ] Maintain conflict history

### Phase 3: Auto Sync
- [ ] Background sync every X minutes
- [ ] Sync on app resume
- [ ] Sync triggers (after save, delete, etc.)

### Phase 4: Real-time Sync
- [ ] Use Supabase Realtime
- [ ] Instant updates across devices
- [ ] Presence indicators (who's online)

### Phase 5: Advanced Features
- [ ] Selective sync (by date range, site, etc.)
- [ ] Sync analytics dashboard
- [ ] Bandwidth usage monitoring
- [ ] Sync conflict resolution UI

---

## 📞 Troubleshooting

### "Failed to connect to Supabase"
- Check internet connection
- Verify Supabase URL is correct
- Ensure service role key is valid

### "Permission denied" or 403 errors
- Make sure you're using **service role key**, not anon key
- Verify RLS policies are applied (migration 002)

### "Duplicate key" errors
- Check `server_id` uniqueness
- May need to reset sequences in PostgreSQL

### Conflicts not resolving
- Check `updated_at` timestamps are in UTC
- Verify conflict resolution logic in code

### Slow sync
- Check network speed
- Look at record count (may need pagination)
- Add indexes on frequently queried columns

---

## 📚 Documentation Files

- **[001_initial_schema.sql](../supabase/migrations/001_initial_schema.sql)** - PostgreSQL table definitions
- **[002_rls_policies.sql](../supabase/migrations/002_rls_policies.sql)** - Security policies
- **[supabase_postgres_sync_service.dart](../lib/core/services/supabase_postgres_sync_service.dart)** - Sync service code

---

**Created**: February 6, 2026  
**Status**: 🚧 In Progress - TODO: Complete all push/pull methods  
**Architecture**: Offline-First + PostgreSQL Sync
