-- Migration: Add Apple to auth_provider check constraint
-- Date: 2026-04-06
-- Description: Updates the users table auth_provider check constraint to include 'apple'
--              and updates existing Apple users who were created before this constraint

-- Drop the existing check constraint
ALTER TABLE users 
DROP CONSTRAINT IF EXISTS users_auth_provider_check;

-- Add the updated check constraint with apple included
ALTER TABLE users 
ADD CONSTRAINT users_auth_provider_check 
CHECK (auth_provider IN ('email', 'google', 'apple'));

-- Update existing Apple users (identified by privaterelay email addresses)
UPDATE users 
SET auth_provider = 'apple'
WHERE email LIKE '%@privaterelay.appleid.com'
  AND auth_provider IS NULL;

-- Verify the constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'users_auth_provider_check'
    ) THEN
        RAISE EXCEPTION 'Failed to create users_auth_provider_check constraint';
    END IF;
    
    RAISE NOTICE 'Successfully added apple to auth_provider check constraint';
    RAISE NOTICE 'Updated existing Apple users to have auth_provider = apple';
END $$;
