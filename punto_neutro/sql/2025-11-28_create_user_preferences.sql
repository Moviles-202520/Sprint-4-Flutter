-- =====================================================
-- Migration: Create user_preferences table
-- Date: 2025-11-28
-- Description: User preferences for dark mode, notifications, and language
-- =====================================================

-- Create the user_preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
    user_profile_id BIGINT PRIMARY KEY REFERENCES user_profiles(user_profile_id) ON DELETE CASCADE,
    dark_mode BOOLEAN NOT NULL DEFAULT false,
    notifications_enabled BOOLEAN NOT NULL DEFAULT true,
    language TEXT NOT NULL DEFAULT 'es', -- 'es', 'en', etc.
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comment to table
COMMENT ON TABLE user_preferences IS 'Stores user preferences for UI and notifications';
COMMENT ON COLUMN user_preferences.user_profile_id IS 'Foreign key to user_profiles';
COMMENT ON COLUMN user_preferences.dark_mode IS 'Whether dark mode is enabled';
COMMENT ON COLUMN user_preferences.notifications_enabled IS 'Whether notifications are enabled';
COMMENT ON COLUMN user_preferences.language IS 'User preferred language (ISO 639-1 code)';

-- Create trigger function for updated_at (if it doesn't exist)
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
CREATE TRIGGER trigger_set_updated_at_user_preferences
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- Enable Row Level Security
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view own preferences" ON user_preferences;
DROP POLICY IF EXISTS "Users can insert own preferences" ON user_preferences;
DROP POLICY IF EXISTS "Users can update own preferences" ON user_preferences;
DROP POLICY IF EXISTS "Users can delete own preferences" ON user_preferences;

-- RLS Policy: Users can only view their own preferences
CREATE POLICY "Users can view own preferences"
    ON user_preferences
    FOR SELECT
    TO authenticated
    USING (
        user_profile_id IN (
            SELECT user_profile_id 
            FROM user_profiles 
            WHERE user_auth_id::text = auth.uid()::text
        )
    );

-- RLS Policy: Users can insert their own preferences
CREATE POLICY "Users can insert own preferences"
    ON user_preferences
    FOR INSERT
    TO authenticated
    WITH CHECK (
        user_profile_id IN (
            SELECT user_profile_id 
            FROM user_profiles 
            WHERE user_auth_id::text = auth.uid()::text
        )
    );

-- RLS Policy: Users can update their own preferences
CREATE POLICY "Users can update own preferences"
    ON user_preferences
    FOR UPDATE
    TO authenticated
    USING (
        user_profile_id IN (
            SELECT user_profile_id 
            FROM user_profiles 
            WHERE user_auth_id::text = auth.uid()::text
        )
    )
    WITH CHECK (
        user_profile_id IN (
            SELECT user_profile_id 
            FROM user_profiles 
            WHERE user_auth_id::text = auth.uid()::text
        )
    );

-- RLS Policy: Users can delete their own preferences
CREATE POLICY "Users can delete own preferences"
    ON user_preferences
    FOR DELETE
    TO authenticated
    USING (
        user_profile_id IN (
            SELECT user_profile_id 
            FROM user_profiles 
            WHERE user_auth_id::text = auth.uid()::text
        )
    );

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_profile_id 
    ON user_preferences(user_profile_id);

-- =====================================================
-- TESTING QUERIES
-- =====================================================
-- Insert test preference (replace with actual user_profile_id)
-- INSERT INTO user_preferences (user_profile_id, dark_mode, notifications_enabled, language)
-- VALUES (1, true, true, 'es');

-- Select preferences for current user
-- SELECT * FROM user_preferences 
-- WHERE user_profile_id IN (
--     SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
-- );

-- Update preferences
-- UPDATE user_preferences 
-- SET dark_mode = true, language = 'en'
-- WHERE user_profile_id IN (
--     SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
-- );

-- =====================================================
-- ROLLBACK SCRIPT
-- =====================================================
-- DROP TRIGGER IF EXISTS trigger_set_updated_at_user_preferences ON user_preferences;
-- DROP TABLE IF EXISTS user_preferences CASCADE;
-- -- Note: Don't drop set_updated_at() function if other tables use it
