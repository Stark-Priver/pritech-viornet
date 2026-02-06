# Quick Start: Supabase CLI Setup

## 🚀 5-Minute Setup

### 1. Install Supabase CLI

**Windows - Using Scoop (Recommended)**:

```powershell
# Install Scoop if you don't have it
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# Install Supabase CLI
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Verify
supabase --version
```

**Windows - Direct Download (Alternative)**:

```powershell
# Download and extract
Invoke-WebRequest -Uri "https://github.com/supabase/cli/releases/latest/download/supabase_windows_amd64.zip" -OutFile "supabase.zip"
Expand-Archive -Path "supabase.zip" -DestinationPath "$env:USERPROFILE\supabase-cli"

# Add to PATH (then restart PowerShell)
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:USERPROFILE\supabase-cli", "User")

# Verify (restart PowerShell first)
supabase --version
```

### 2. Login & Link Project

```powershell
# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref bylovbbaatsigcfsdspn
# Enter your database password when prompted
```

### 3. Push Migrations

```powershell
# Navigate to your project
cd f:\PROJECTS\viornet

# Push all migrations
supabase db push
```

✅ **Done!** Your database schema is live on Supabase.

### 4. Get Service Role Key

```powershell
# View your keys
supabase status
```

Copy the **`service_role key`** from the output.

### 5. Update main.dart

Replace the Supabase initialization:

```dart
await SupabaseSyncService.initialize(
  supabaseUrl: 'https://bylovbbaatsigcfsdspn.supabase.co',
  supabaseServiceKey: 'YOUR_SERVICE_ROLE_KEY_HERE',
);
```

### 6. Run Your App

```powershell
flutter pub get
flutter run
```

---

## 📝 Common Commands

```powershell
# View database status
supabase status

# Create new migration
supabase migration new add_new_table

# Reset database (deletes all data!)
supabase db reset

# Pull schema from remote
supabase db pull

# View logs
supabase logs
```

---

## 🔄 Making Schema Changes

### Workflow:

1. **Create Migration**:
   ```powershell
   supabase migration new add_customer_notes
   ```

2. **Edit SQL File**:
   - File created in `supabase/migrations/`
   - Add your SQL changes

3. **Push to Cloud**:
   ```powershell
   supabase db push
   ```

4. **Update Local Dart Schema**:
   - Update `lib/core/database/database.dart`
   - Run `flutter pub run build_runner build`

5. **Update Sync Service**:
   - Add push/pull methods for new table
   - Follow the pattern in `supabase_postgres_sync_service.dart`

---

## 🐛 Troubleshooting

### "supabase: command not found"

**If using Scoop**:
```powershell
# Reinstall
scoop uninstall supabase
scoop install supabase
```

**If using direct download**:
```powershell
# Make sure it's in your PATH
$env:Path += ";$env:USERPROFILE\supabase-cli"

# Permanent PATH (then restart PowerShell):
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:USERPROFILE\supabase-cli", "User")
```

**Quick test**:
```powershell
# Navigate to the folder manually
cd $env:USERPROFILE\supabase-cli
.\supabase.exe --version
```

### "Project not linked"

```powershell
supabase link --project-ref bylovbbaatsigcfsdspn
```

### "Migration already applied"

```powershell
# View migration status
supabase migration list --remote

# If needed, reset and reapply
supabase db reset
supabase db push
```

### "Permission denied"

- Make sure you're using the correct database password
- Check project ref is correct: `bylovbbaatsigcfsdspn`

---

## 🎯 Next Steps

1. ✅ CLI installed and linked
2. ✅ Migrations pushed
3. ✅ Service key obtained
4. ⏭️ Update `main.dart` with service key
5. ⏭️ Update sync buttons (see [SUPABASE_POSTGRES_SETUP.md](SUPABASE_POSTGRES_SETUP.md))
6. ⏭️ Test sync functionality

---

**See full guide**: [SUPABASE_POSTGRES_SETUP.md](SUPABASE_POSTGRES_SETUP.md)
