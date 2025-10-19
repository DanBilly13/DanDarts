# ✅ Avatar Upload Feature - Setup Guide

## What's Been Implemented:

### 1. **AsyncAvatarImage Component** ✅
- Displays both local assets and remote URLs
- Shows loading spinner for remote images
- Handles image load failures gracefully
- Used in: TopBar, PlayerCard, ProfileHeaderView

### 2. **AuthService.uploadAvatar()** ✅
- Uploads image to Supabase Storage
- Generates unique filename with timestamp
- Compresses image to JPEG (0.8 quality)
- Updates user profile in database
- Returns public URL of uploaded avatar

### 3. **ProfileView Integration** ✅
- PhotosPicker for selecting images
- Automatic upload on selection
- Shows selected image preview immediately
- Error handling with user-friendly alerts
- Clears preview after successful upload

## Setup Required:

### Step 1: Create Supabase Storage Bucket

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Click **New Query**
3. Copy and paste the SQL from: `/supabase_migrations/002_create_avatars_bucket.sql`
4. Click **Run** (or Ctrl/Cmd + Enter)

**Or manually:**
1. Go to **Storage** in Supabase Dashboard
2. Click **New bucket**
3. Name: `avatars`
4. **Public bucket**: ✅ Enable
5. Click **Create bucket**

### Step 2: Configure Storage Policies (if created manually)

If you created the bucket manually, you need to set up RLS policies:

```sql
-- Allow authenticated users to upload
CREATE POLICY "Users can upload avatars"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'avatars');

-- Allow public read access
CREATE POLICY "Public avatar access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');
```

### Step 3: Test the Feature

1. **Build and run** the app on your device
2. **Navigate to Profile** (tap avatar in top bar)
3. **Tap the camera icon** on your profile picture
4. **Select a photo** from your library
5. **Wait for upload** (you'll see the selected image immediately)
6. **Check the result:**
   - Avatar should update in profile
   - Avatar should update in top bar
   - Avatar should persist after app restart

## How It Works:

### Upload Flow:
1. User selects photo from PhotosPicker
2. Image loads and displays immediately (preview)
3. Image compresses to JPEG (80% quality)
4. Uploads to Supabase Storage bucket `avatars/`
5. Gets public URL from Supabase
6. Updates `users` table with new `avatar_url`
7. Updates local `AuthService.currentUser`
8. UI refreshes automatically (SwiftUI @Published)

### File Naming:
```
avatars/{user_id}_{timestamp}.jpg
```
Example: `avatars/123e4567-e89b-12d3-a456-426614174000_1729339200.123.jpg`

### Image Specs:
- **Format:** JPEG
- **Compression:** 80% quality
- **Max Size:** ~2-3 MB (depends on original)
- **Storage:** Supabase Storage (public bucket)

## Features:

✅ **Automatic Upload** - No "Save" button needed  
✅ **Image Compression** - Reduces file size  
✅ **Unique Filenames** - Prevents conflicts  
✅ **Public URLs** - Images accessible via CDN  
✅ **Error Handling** - User-friendly error messages  
✅ **Loading States** - Shows upload progress  
✅ **Preview** - See image before upload completes  
✅ **Remote & Local** - Supports both URL and asset images  

## Troubleshooting:

### "Failed to upload avatar"
- Check Supabase Storage bucket exists
- Verify RLS policies are set correctly
- Check network connection
- Look at Xcode console for detailed error

### Avatar doesn't show after upload
- Check the `users` table - is `avatar_url` updated?
- Verify the URL is publicly accessible
- Try force-quitting and reopening the app

### Image quality is poor
- Adjust compression quality in ProfileView.swift line 87:
  ```swift
  uiImage.jpegData(compressionQuality: 0.9) // Higher = better quality, larger file
  ```

## Next Steps:

- ✅ Avatar display working
- ✅ Avatar upload working
- 🔄 **Optional:** Add image cropping before upload
- 🔄 **Optional:** Add avatar size limits
- 🔄 **Optional:** Delete old avatars when uploading new ones

## Files Modified:

1. **AuthService.swift** - Added `uploadAvatar()` method
2. **ProfileView.swift** - Integrated upload on photo selection
3. **AsyncAvatarImage.swift** - New component for displaying avatars
4. **TopBar.swift** - Uses AsyncAvatarImage
5. **PlayerCard.swift** - Uses AsyncAvatarImage
6. **ProfileHeaderView.swift** - Uses AsyncAvatarImage

**Status: Ready to test! 🚀**
