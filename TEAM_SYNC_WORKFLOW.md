# Team Sync Workflow - Best Practices

## 🎯 Overview

Your Viornet app now uses a **SHARED team database** model. This means:
- ✅ All team members sync the SAME database
- ✅ When User A adds data and uploads → User B can 

### Architecture
```
Team Member A                     Supabase Cloud                    Team Member B
    |                                  |                                  |
    | 1. Add customer data            |                                  |
    | 2. Click "Sync to Cloud" -----> |                                  |
    |                                  | [viornet_local.db]              |
    |                                  | <----- 3. Click "Sync from Cloud"|
    |                                  |        4. Downloads same data     |
    |                                  |        5. Sees customer A added   |
```

### File Structure
```
Supabase Storage (viornet-backups/):
└── viornet_local.db  ← ONE shared file for entire team
```

---

## ✅ Recommended Workflow

### Daily Work Routine

#### When Starting Work:
```
1. Open app
2. Click "Sync from Cloud" (download icon)
3. Sign in to Supabase (if not already)
4. Wait for download to complete
5. Now your local database has latest team changes
```

#### When Making Changes:
```
1. Make your changes (add customers, products, etc.)
2. Click "Sync to Cloud" (upload icon)
3. Wait for upload to complete
4. Notify team: "I just synced latest changes!"
```

#### Before Closing App:
```
1. Click "Sync to Cloud" one final time
2. Ensure upload succeeds
3. Your changes are now available to team
```

---

## ⚠️ Conflict Prevention

### The Problem: Last Upload Wins

**Scenario without proper workflow:**
```
Time    Team Member A               Team Member B
-----   -----------------------     -----------------------
9:00    Downloads database          Downloads database
        (both have same data)       (both have same data)

9:30    Adds Customer #1            Adds Customer #2
        (locally only)              (locally only)

10:00   Uploads to cloud            (still working...)
        ✅ Cloud has Customer #1    

10:15                               Uploads to cloud
                                    ✅ Cloud has Customer #2
                                    ❌ Customer #1 is LOST!
```

**Result**: Team Member A's work is overwritten and lost! 😱

### The Solution: Sync Early, Sync Often

**Correct workflow:**
```
Time    Team Member A               Team Member B
-----   -----------------------     -----------------------
9:00    Downloads database          Downloads database

9:30    Adds Customer #1            Adds Customer #2
        Uploads immediately ✅      (still working...)

9:35                                Downloads before upload ✅
                                    (gets Customer #1)
                                    Now has Customer #1 + #2
                                    Uploads ✅

9:40    Downloads ✅                
        (gets Customer #2)          
        Both customers preserved!   Both customers preserved!
```

**Result**: No data loss! Everyone has both customers! ✅

---

## 📋 Best Practices

### 1. Download Before Making Changes
```
Always sync FROM cloud before making changes.
This ensures you have the latest team data.
```

### 2. Upload Immediately After Changes
```
Don't wait hours before uploading.
Upload right after completing a task.
```

### 3. Communicate with Team
```
Use Slack/Teams/WhatsApp to notify:
"Just added 5 new customers - synced to cloud!"
"Everyone please sync before making changes"
```

### 4. Avoid Simultaneous Editing
```
If possible, coordinate who's working on what:
- Team Member A: Handles customers 9-11am
- Team Member B: Handles products 2-4pm
```

### 5. Check Last Sync Time
```
Before uploading, check the timestamp:
- If it's recent: Someone else just synced
- Download first to get their changes
- Then upload your changes
```

---

## 🔄 Sync Frequency Recommendations

### Small Team (2-5 people):
- Sync **every 30 minutes** while working
- Sync **before and after** each major task

### Medium Team (5-15 people):
- Sync **every 15 minutes** while working
- Use team chat to announce syncs

### Large Team (15+ people):
- Consider implementing **automatic sync** (future feature)
- Or use **per-user databases** instead of shared

---

## 🚨 What to Do If Conflict Happens

### Symptoms:
- Data you added is missing
- Another team member's data overwrote yours
- Unexpected database state

### Recovery Steps:

#### 1. Check Local Backups
```dart
// The app creates automatic backups before downloading
// Location: Documents folder
// Files: viornet_local_backup_<timestamp>.db
```

**Windows**: `C:\Users\YourName\Documents\viornet_local_backup_*.db`
**Android**: `/storage/emulated/0/Android/data/com.pritechvior.viornet/files/`

#### 2. Restore from Backup
```powershell
# Find the backup file with your data
# Copy it back to main database location
Copy-Item "viornet_local_backup_1675689600000.db" "viornet_local.db"
```

#### 3. Re-upload Your Data
```
1. Open app with restored database
2. Verify your data is there
3. Click "Sync to Cloud" to upload
4. Notify team to sync
```

#### 4. Merge Manually (if needed)
```
1. Download latest cloud database (has other's data)
2. Open your backup database (has your data)
3. Manually add your missing entries
4. Upload merged database
```

---

## 💡 Tips for Smooth Collaboration

### Use Descriptive Actions
When syncing, think about what you changed:
```
✅ Good: "Synced 3 new customers + updated Product X pricing"
❌ Bad: "Synced stuff"
```

### Keep Team Chat Open
```
Quick messages prevent conflicts:
"About to sync 20 new entries - wait 2 min before uploading"
"Sync complete - go ahead!"
```

### Designate a Team Lead
```
One person coordinates major sync operations:
- Morning sync check
- End-of-day sync review
- Conflict resolution
```

### Schedule Sync Times
```
Example routine:
9:00 AM  - Everyone syncs to start day
12:00 PM - Lunch sync
3:00 PM  - Afternoon sync
5:00 PM  - End-of-day sync
```

---

## 🔮 Future Improvements

### Planned Features:
- [ ] **Auto-sync**: Automatic upload/download every X minutes
- [ ] **Conflict detection**: Warn if database changed since last download
- [ ] **Version history**: Keep multiple backup versions in cloud
- [ ] **Change log**: See what changed between syncs
- [ ] **Real-time sync**: Instant updates across all devices
- [ ] **Merge conflicts UI**: Visual tool to resolve conflicts

---

## 📊 Sync Status Indicators

### In the App:

**Cloud Icon (Upload)**:
- 🔵 Blue: Ready to upload
- 🟡 Yellow: Uploading...
- 🟢 Green: Upload successful (2 sec)
- 🔴 Red: Upload failed

**Download Icon (Sync from Cloud)**:
- 🔵 Blue: Ready to download
- 🟡 Yellow: Downloading...
- 🟢 Green: Download successful (2 sec)
- 🔴 Red: Download failed

**Last Sync Time**:
- Shown after successful sync
- Format: "Synced at 2:45 PM"
- Helps coordinate with team

---

## 🎓 Training Your Team

### New Team Member Onboarding:

#### Step 1: Create Supabase Account
```
1. Ask team lead for Supabase project URL
2. Sign up at app login screen
3. Use company email (recommended)
4. Verify email
```

#### Step 2: First Sync
```
1. Click "Sync from Cloud"
2. Sign in with Supabase account
3. Download team database
4. Verify data looks correct
```

#### Step 3: Practice Workflow
```
1. Add a test customer/product
2. Upload to cloud
3. Delete test entry
4. Download from cloud
5. Verify test entry is back
```

#### Step 4: Daily Routine
```
- Morning: Download first thing
- During work: Upload after each major task
- Before breaks: Upload
- End of day: Final upload
```

---

## 📞 Support

### Common Questions:

**Q: Can I work offline?**
A: Yes! Make changes offline, then upload when back online.

**Q: How big is the database?**
A: Typically 1-5 MB. Free Supabase tier allows 1GB total.

**Q: What if internet is slow?**
A: Upload/download will take longer but will complete. Be patient.

**Q: Can I use multiple devices?**
A: Yes! Sync on Device 1, then sync on Device 2 to get updates.

**Q: What if I forget to sync?**
A: Your changes stay local. Upload when you remember. But your team won't see them until you do.

---

## ✅ Quick Reference Card

### Before Working:
```
1. Open app
2. Sync FROM cloud ⬇️
3. Wait for completion
```

### After Working:
```
1. Save your changes
2. Sync TO cloud ⬆️
3. Notify team
```

### If Unsure:
```
1. Download first (safe operation)
2. Check if your data is there
3. If yes: Upload
4. If no: Don't upload (ask team lead)
```

---

**Created**: February 6, 2026  
**Status**: ✅ Active - Shared Team Database Model  
**Contact**: See team lead for sync issues
