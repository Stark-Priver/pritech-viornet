# Supabase RLS Policy Fix - 403 Error Solution

## 🚨 Problem

When uploading database to Supabase, you get:
```
❌ Upload failed: StorageException(message: new row violates row-level security policy, statusCode: 403, error: Unauthorized)
```

## 🔍 Root Cause

The Supabase storage bucket has **Row Level Security (RLS)** enabled, but no policies are configured to allow authenticated users to upload files.

## ✅ Solution: Configure RLS Policies

### Step 1: Go to Supabase Dashboard

1. Visit https://supabase.com/dashboard
2. Select your project: **bylovbbaatsigcfsdspn**
3. Click **Storage** in the left sidebar
4. Click on your **viornet-backups** bucket

### Step 2: Add Storage Policies (SHARED TEAM DATABASE)

Click the **Policies** tab (or go to Storage > viornet-backups > Policies)

**IMPORTANT**: These policies allow ALL authenticated users to access the SAME shared database. This enables team collaboration where everyone syncs the same data.

#### Policy 1: Allow All Authenticated Users to Upload (INSERT)

```sql
CREATE POLICY "Allow all authenticated users to upload shared database"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'viornet-backups' 
  AND name = 'viornet_local.db'
);
```

**What this does**: Allows ANY authenticated user to upload to the shared team database

#### Policy 2: Allow All Authenticated Users to Update (UPDATE)

```sql
CREATE POLICY "Allow all authenticated users to update shared database"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'viornet-backups' 
  AND name = 'viornet_local.db'
)
WITH CHECK (
  bucket_id = 'viornet-backups' 
  AND name = 'viornet_local.db'
);
```

**What this does**: Allows ANY authenticated user to replace/update the shared team database

#### Policy 3: Allow All Authenticated Users to Download (SELECT)

```sql
CREATE POLICY "Allow all authenticated users to download shared database"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'viornet-backups' 
  AND name = 'viornet_local.db'
);
```

**What this does**: Allows ANY authenticated user to download the shared team database

#### Policy 4: Allow All Authenticated Users to Delete (DELETE)

```sql
CREATE POLICY "Allow all authenticated users to delete shared database"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'viornet-backups' 
  AND name = 'viornet_local.db'
);
```

**What this does**: Allows ANY authenticated user to delete the shared team database (backup management)

### Step 3: Apply Policies via Supabase UI

**Easier Method - Use the UI:**

1. Go to **Storage** > **Policies** > **New Policy**
2. For each policy above:
   - **Policy Name**: Copy the text in quotes (e.g., "Allow authenticated users to upload their own files")
   - **Target Roles**: Select `authenticated`
   - **Policy Command**: Select `INSERT`, `UPDATE`, `SELECT`, or `DELETE`
   - **Policy Definition (USING)**: Enter the SQL condition
   - **WITH CHECK** (for INSERT/UPDATE): Enter the SQL condition
   - Click **Review** then **Save Policy**

**Alternative - SQL Editor:**

1. Go to **SQL Editor** in Supabase Dashboard
2. Click **New Query**
3. Paste ALL four policies above (copy them all at once)
4. Click **Run** or press `Ctrl+Enter`
5. Verify all 4 policies were created successfully

### Step 4: Verify Bucket Configuration

1. Go to **Storage** > **viornet-backups**
2. Click **Configuration** (gear icon)
3. Verify settings:
   - **Public bucket**: ❌ OFF (must be private)
   - **Restrict file upload size**: 50 MB (optional)
   - **Allowed MIME types**: Leave empty (allow all)

### Step 5: Test the Fix

1. **Stop your app** if it's running
2. **Clear app data** (optional - to test fresh):
   ```powershell
   flutter run -d <device-id>
   ```
3. **Log in** to your app
4. **Click the cloud icon** (Sync to Cloud)
5. **Sign in to Supabase** (create account or sign in)
6. **Try uploading** - should work now! ✅

Expected output:
```
I/flutter: 📤 Starting database upload to Supabase...
I/flutter: 📦 Database size: 96.00 KB
I/flutter: ✅ Upload successful
I/flutter: 📅 Last sync: 2026-02-06 14:30:00
```

## 🔐 Security Explanation

### ⚠️ IMPORTANT: Shared Team Database Model

This configuration creates a **SHARED database accessible by ALL authenticated users**. This is designed for team collaboration:

1. **Team Collaboration**: 
   - ALL authenticated users access the SAME database: `viornet_local.db`
   - When User A adds data and uploads → User B can download and see it
   - Perfect for teams working on shared data

2. **Authentication Required**:
   - Only authenticated users can upload/download
   - Anonymous users have NO access
   - Must sign up or sign in to Supabase

3. **Single Source of Truth**:
   - Everyone works with the same database file
   - No user-specific folders
   - Last upload wins (be aware of potential conflicts)

### ⚠️ Conflict Warning

Since all users share the same database:
- **Last upload overwrites**: If User A and User B both make changes offline, the last one to upload will overwrite the other's changes
- **Recommended workflow**: 
  1. Download (sync) before making changes
  2. Make your changes
  3. Upload immediately
  4. Tell team members to sync

### Alternative: Per-User Isolation

If you want each user to have their OWN separate database, use these policies instead:

```sql
-- Per-user isolation (original design)
CREATE POLICY "Allow users to upload their own files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'viornet-backups' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

This would create: `user-uuid-1/viornet_local.db`, `user-uuid-2/viornet_local.db`, etc.

## 📂 File Structure in Supabase

After policies are applied, your bucket will have ONE shared database:

```
viornet-backups/
└── viornet_local.db (SHARED by all team members - 96 KB)
```

**Team Collaboration:**
- User A uploads → File updated
- User B downloads → Gets User A's changes
- User C uploads → Overwrites with their version
- All users work with the SAME database file

## 🧪 Testing Checklist

After applying policies, test these scenarios:

### ✅ Should Work (Team Collaboration):
- [ ] User A: Sign up with Supabase account
- [ ] User A: Upload database after authentication
- [ ] User B: Sign up with different Supabase account
- [ ] User B: Download database (should get User A's data)
- [ ] User B: Add new data locally
- [ ] User B: Upload database (overwrites shared database)
- [ ] User A: Download database (should get User B's updates)
- [ ] All team members see the same data when syncing

### ❌ Should Fail (Security Working):
- [ ] Upload without authentication → 401 Unauthorized
- [ ] Anonymous user tries to download → 403 Forbidden

## 🐛 Troubleshooting

### Still getting 403 error?

**Check 1**: Verify policies are applied
```sql
-- Run in SQL Editor to see all policies
SELECT * FROM pg_policies 
WHERE schemaname = 'storage' 
AND tablename = 'objects';
```

**Check 2**: Check if user is authenticated
- The app should show a dialog asking to sign in
- After signing in, you should see user email in logs
- Check Supabase Dashboard > Authentication > Users to see registered users

**Check 3**: Bucket name matches
- Code uses: `viornet-backups`
- Dashboard shows: `viornet-backups`
- Must be EXACT match (case-sensitive)

**Check 4**: Check bucket privacy
- Bucket MUST be **Private** (not Public)
- Public buckets don't use RLS policies

### Getting "Bucket not found"?

Create the bucket manually:
1. Go to **Storage** > **New Bucket**
2. Name: `viornet-backups`
3. Public: ❌ OFF
4. Click **Create**

### Getting "Invalid JWT"?

Your Supabase credentials might be wrong:
1. Go to **Settings** > **API**
2. Copy **Project URL** and **anon public** key
3. Update [main.dart](lib/main.dart) with correct values

## 📊 Policy Testing (SQL Editor)

Run these queries to test if policies work:

```sql
-- Test 1: Check if user can upload (should return true)
SELECT storage.extension('viornet-backups', 'user-id/test.db') AS can_upload;

-- Test 2: List all policies on storage.objects
SELECT * FROM pg_policies WHERE tablename = 'objects';

-- Test 3: Check bucket configuration
SELECT * FROM storage.buckets WHERE name = 'viornet-backups';
```

## ✅ Success Criteria

You'll know it's working when:

1. **No 403 errors** in logs
2. **Upload succeeds**: See ✅ messages in console
3. **Files appear in Storage**: Go to Storage > viornet-backups > see user folders
4. **Last sync time shows**: Check the cloud icon in app
5. **Download works**: Try "Sync from Cloud" on another device

## 🎉 After Fix

Your users will be able to:
- ✅ Sign up with their own Supabase account (FREE)
- ✅ Upload database to cloud (automatic backup)
- ✅ Download database on other devices (sync)
- ✅ Complete privacy (each user has isolated storage)
- ✅ Works on ALL platforms (Windows, Android, iOS, Web)

---

## 📞 Still Having Issues?

If policies are applied but still getting errors:

1. **Check Supabase logs**:
   - Dashboard > Logs > Filter by "storage" or "auth"
   - Look for detailed error messages

2. **Verify user authentication**:
   - Add this debug code to [supabase_sync_service.dart](lib/core/services/supabase_sync_service.dart):
   ```dart
   debugPrint('🔐 Current user: ${currentUser?.id}');
   debugPrint('📧 Current email: ${userEmail}');
   debugPrint('🔑 Is signed in: $isSignedIn');
   ```

3. **Test with Supabase Storage API**:
   - Use Postman or curl to test upload directly
   - See if it's an app issue or Supabase issue

4. **Check quota limits**:
   - Dashboard > Settings > Billing
   - Verify you haven't exceeded free tier limits

---

**Last Updated**: February 6, 2026  
**Status**: 🔧 Fix Required - Apply RLS Policies  
**Estimated Time**: 10 minutes
