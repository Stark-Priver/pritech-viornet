# Google Drive Sync Setup Guide

This guide will help you configure Google Drive synchronization for ViorNet app to enable cross-device data sharing.

## Prerequisites

- Google Cloud Console account
- ViorNet app installed on your device

## Google Cloud Console Configuration

### 1. Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click on the project dropdown at the top
3. Click "New Project"
4. Enter project name: "ViorNet"
5. Click "Create"

### 2. Enable Google Drive API

1. In your project, go to "APIs & Services" > "Library"
2. Search for "Google Drive API"
3. Click on it and click "Enable"

### 3. Configure OAuth Consent Screen

1. Go to "APIs & Services" > "OAuth consent screen"
2. Select "External" (or "Internal" if you have a Google Workspace)
3. Click "Create"
4. Fill in the required fields:
   - App name: ViorNet
   - User support email: Your email
   - Developer contact email: Your email
5. Click "Save and Continue"
6. Add scopes:
   - Click "Add or Remove Scopes"
   - Select these scopes:
     - `.../auth/drive.file` (View and manage Google Drive files created by this app)
     - `.../auth/drive.appdata` (View and manage its own configuration data)
   - Click "Update" then "Save and Continue"
7. Add test users (for testing phase):
   - Click "Add Users"
   - Enter email addresses of test users
   - Click "Save and Continue"
8. Review and click "Back to Dashboard"

### 4. Create OAuth 2.0 Client IDs

#### For Android:

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth client ID"
3. Select "Android"
4. Enter a name: "ViorNet Android"
5. Get your SHA-1 certificate fingerprint:

   **On Windows (PowerShell):**
   ```powershell
   # Find keytool (usually in Java JDK or Android Studio)
   # Option 1: If Android Studio is installed
   & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore $env:USERPROFILE\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
   
   # Option 2: If Java JDK is installed (replace <version> with your JDK version)
   & "C:\Program Files\Java\jdk-<version>\bin\keytool.exe" -list -v -keystore $env:USERPROFILE\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
   
   # For release certificate:
   & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore your-release-key.keystore -alias your-key-alias
   ```
   
   **On macOS/Linux:**
   ```bash
   # For debug certificate:
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   
   # For release certificate:
   keytool -list -v -keystore your-release-key.keystore -alias your-key-alias
   ```
   
   **Finding keytool on Windows:**
   - Check: `C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`
   - Check: `C:\Program Files\Java\jdk-*\bin\keytool.exe`
   - Or search for "keytool.exe" in Windows Explorer

6. Look for the **SHA1** line in the output (it will look like: `AB:CD:EF:12:34:...`)
7. Enter the SHA-1 fingerprint
8. Enter package name: `com.viornet.app` (or your actual package name)
9. Click "Create"
10. **Copy the Client ID** - you'll need this in the next step

#### For iOS:

1. Click "Create Credentials" > "OAuth client ID"
2. Select "iOS"
3. Enter a name: "ViorNet iOS"
4. Enter Bundle ID from your `ios/Runner/Info.plist`: `com.viornet.app`
5. Click "Create"
6. Download the configuration file

#### For Web:

1. Click "Create Credentials" > "OAuth client ID"
2. Select "Web application"
3. Enter a name: "ViorNet Web"
4. Add Authorized JavaScript origins:
   - `http://localhost:3000`
   - `http://localhost:8080`
   - Your production domain (if any)
5. Add Authorized redirect URIs:
   - `http://localhost:3000`
   - Your production domain (if any)
6. Click "Create"

### 5. Update App Configuration

#### Android (`android/app/src/main/res/values/strings.xml`):

Add your Android OAuth Client ID to the strings.xml file:

1. Open `android/app/src/main/res/values/strings.xml`
2. Replace `YOUR_ANDROID_CLIENT_ID` with your actual OAuth Client ID from step 4.10:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="default_web_client_id">YOUR_ANDROID_CLIENT_ID</string>
</resources>
```

Example (with a fake Client ID):
```xml
<string name="default_web_client_id">123456789-abc123def456.apps.googleusercontent.com</string>
```

**Note**: The Client ID should end with `.apps.googleusercontent.com`

#### iOS (`ios/Runner/Info.plist`):

Add the following inside the `<dict>` tag:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_IOS_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

Replace `YOUR_IOS_CLIENT_ID` with your iOS OAuth client ID.

#### Web (`web/index.html`):

Add this script tag in the `<head>` section:

```html
<script src="https://accounts.google.com/gsi/client" async defer></script>
```

## App Usage

### First Time Setup (New Device)

1. Open the ViorNet app
2. On the login screen, click **"Sync from Cloud"** button
3. Sign in with your Google account
4. Allow the app to access your Google Drive
5. If a backup exists, it will be downloaded automatically
6. Restart the app to load the synced data
7. Login with your credentials

### Regular Usage (Backup to Cloud)

1. Login to the app
2. Click the **cloud upload icon** in the app bar (top right)
3. The app will upload your current database to Google Drive
4. You'll see a success message with the last sync time

### Syncing to Another Device

1. Install ViorNet on the new device
2. On login screen, click **"Sync from Cloud"**
3. Sign in with the same Google account
4. Your data will be downloaded
5. Restart the app
6. Login with your credentials

## How It Works

### Data Storage

- Database file: `viornet_local.db`
- Google Drive folder: `ViorNet_Backup`
- Location: Root of your Google Drive (shared location)
- File naming: Single shared file for all users
- **Important**: All users should use the **same Google account** to access the shared database

### Sync Behavior

- **Upload (Backup)**: Updates the shared database on Google Drive with your current local data
- **Download (Restore)**: Replaces your local database with the shared cloud database
- **Multi-User Access**: All team members sync to/from the same shared file
- **Conflict Resolution**: Latest upload wins (last person to sync overwrites previous data)
- **Best Practice**: Sync before making changes (download) and after finishing work (upload)
- **Manual Control**: User initiates all sync operations

### Centralized Database Model

This app uses a **centralized shared database** approach:

1. **One Database for Everyone**: All users access the same database file on Google Drive
2. **Role-Based Access**: Your role (Admin, Agent, Finance, etc.) determines what you can see and edit
3. **Sync to Update**: When you sync TO cloud, you're backing up the latest data for everyone
4. **Sync from Cloud**: When you sync FROM cloud, you get the latest data from the team
5. **Google Account**: All team members should know the shared Google account credentials for syncing

**Workflow Example:**
- Morning: Agent A syncs FROM cloud to get latest data
- During day: Agent A adds new clients and sales
- Evening: Agent A syncs TO cloud to share updates
- Next morning: Agent B syncs FROM cloud to see Agent A's work

### Security

- OAuth 2.0 authentication required
- Data stored in user's personal Google Drive
- App-specific folder with restricted access
- No automatic syncing - manual triggers only

## Troubleshooting

### "Failed to sign in to Google Drive"

- Check internet connection
- Verify Google Cloud Console configuration
- Ensure OAuth consent screen is properly configured
- Add your Google account to test users list

### "No backup found in Google Drive"

- No previous backup exists - create one by clicking sync button after login
- Wrong Google account - use the account that created the backup
- Check if "ViorNet_Backup" folder exists in Google Drive

### "Failed to sync data to cloud"

- Check internet connection
- Verify Google Drive API is enabled
- Check OAuth client IDs are correctly configured
- Try signing out and signing in again

### App crashes after restore

- Database might be corrupted
- Check if you have enough storage space
- Try uninstalling and reinstalling the app

## Best Practices

1. **Regular Backups**: Sync to cloud regularly (daily or after important changes)
2. **Multiple Devices**: Always sync from cloud on new devices before making changes
3. **Internet Connection**: Ensure stable connection during sync operations
4. **Storage Space**: Keep enough space on both device and Google Drive
5. **Testing**: Test sync on a development device before production use

## Support

For issues or questions:
- Email: support@viornet.com
- GitHub: [Your Repository URL]
- Documentation: [Your Docs URL]

---

**Note**: This sync feature requires Google Drive API access. Make sure your Google Cloud project is properly configured and the app has necessary permissions.
