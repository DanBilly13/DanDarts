-- Migration: Add email and auth_provider columns to users table
-- Purpose: Track authentication method and email for profile management

-- Add email column (nullable for now, will be populated)
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS email TEXT;

-- Add auth_provider column with check constraint
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS auth_provider TEXT CHECK (auth_provider IN ('email', 'google'));

-- Update existing users: Set auth_provider based on their authentication method
-- For now, we'll need to identify Google users vs email users
-- Google users typically have avatarURL starting with https://lh3.googleusercontent.com
-- Or we can check if they have a Google OAuth provider in auth.users

-- Update Google users (those with Google avatar URLs)
UPDATE users 
SET auth_provider = 'google'
WHERE avatar_url LIKE 'https://lh3.googleusercontent.com%'
  OR avatar_url LIKE 'https://lh4.googleusercontent.com%'
  OR avatar_url LIKE 'https://lh5.googleusercontent.com%'
  OR avatar_url LIKE 'https://lh6.googleusercontent.com%';

-- Update email users (everyone else who doesn't have auth_provider set)
UPDATE users 
SET auth_provider = 'email'
WHERE auth_provider IS NULL;

-- Populate email from auth.users table
UPDATE public.users 
SET email = auth.users.email
FROM auth.users
WHERE public.users.id = auth.users.id
  AND public.users.email IS NULL;

-- Add comment
COMMENT ON COLUMN users.email IS 'User email address (from auth provider)';
COMMENT ON COLUMN users.auth_provider IS 'Authentication provider: email or google';
