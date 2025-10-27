# Edit Profile - Database Migration Setup

## Issue
After implementing the edit profile feature, Google users are seeing editable fields instead of locked fields because:
1. The `email` and `auth_provider` columns don't exist in the database yet
2. Existing users don't have these fields populated

## Solution

### Step 1: Run the Migration

Run the migration file to add the new columns:

```bash
# Navigate to your Supabase project in the dashboard
# Go to: SQL Editor > New Query
# Copy and paste the contents of: supabase_migrations/006_add_auth_provider_and_email.sql
# Click "Run"
```

Or if using Supabase CLI:
```bash
supabase db push
```

### Step 2: Verify the Migration

Check that the columns were added:
```sql
SELECT id, display_name, email, auth_provider 
FROM users 
LIMIT 5;
```

You should see:
- `email` column populated with user emails
- `auth_provider` set to either 'email' or 'google'

### Step 3: Test the App

1. **Sign out** of the app
2. **Sign in with Google** again
3. Go to **Edit Profile**
4. You should now see:
   - ✅ Name field: **Locked** with lock icon
   - ✅ Nickname field: **Editable**
   - ✅ Email field: **Locked** with lock icon
   - ✅ Change Password button: **Hidden**

### Step 4: Test Email User

1. **Sign out**
2. **Sign in with email** (or create new email account)
3. Go to **Edit Profile**
4. You should see:
   - ✅ Name field: **Editable**
   - ✅ Nickname field: **Editable**
   - ✅ Email field: **Editable**
   - ✅ Change Password button: **Visible**

## What the Migration Does

1. **Adds `email` column** - Stores user's email address
2. **Adds `auth_provider` column** - Stores 'email' or 'google'
3. **Populates existing Google users** - Identifies by Google avatar URL pattern
4. **Populates existing email users** - Sets remaining users to 'email'
5. **Copies emails from auth.users** - Syncs email addresses

## Troubleshooting

### If fields are still editable for Google users:

**Check the user's auth_provider:**
```sql
SELECT id, display_name, email, auth_provider, avatar_url
FROM users
WHERE display_name = 'Daniel Billingham';
```

**If auth_provider is NULL:**
```sql
-- Manually set to google
UPDATE users 
SET auth_provider = 'google'
WHERE display_name = 'Daniel Billingham';
```

**If email is NULL:**
```sql
-- Manually set email
UPDATE users 
SET email = 'your-email@gmail.com'
WHERE display_name = 'Daniel Billingham';
```

### Force refresh user data in app:

After running the migration, the app needs to reload the user data:
1. Sign out completely
2. Close the app
3. Reopen and sign in again

This ensures the app fetches the updated user data with `auth_provider` and `email` fields.

## Future Users

All new users (both Google and email) will automatically have these fields populated because:
- `AuthService.signUp()` sets `authProvider: .email` and `email: email`
- `AuthService.signInWithGoogle()` sets `authProvider: .google` and `email: googleEmail`

No manual intervention needed for new users! ✅
