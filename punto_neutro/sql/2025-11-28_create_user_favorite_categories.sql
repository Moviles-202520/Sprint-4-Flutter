-- =====================================================
-- Migration: Create user_favorite_categories table
-- Date: 2025-11-28
-- Description: User's favorite categories for personalized feed
-- =====================================================

-- Create the user_favorite_categories table
CREATE TABLE IF NOT EXISTS user_favorite_categories (
    user_profile_id BIGINT NOT NULL REFERENCES user_profiles(user_profile_id) ON DELETE CASCADE,
    category_id BIGINT NOT NULL REFERENCES categories(category_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Composite primary key
    PRIMARY KEY (user_profile_id, category_id)
);

-- Add comments
COMMENT ON TABLE user_favorite_categories IS 'Stores user favorite categories for feed prioritization';
COMMENT ON COLUMN user_favorite_categories.user_profile_id IS 'Foreign key to user_profiles';
COMMENT ON COLUMN user_favorite_categories.category_id IS 'Foreign key to categories';

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_favorite_categories_user 
    ON user_favorite_categories(user_profile_id);

CREATE INDEX IF NOT EXISTS idx_user_favorite_categories_category 
    ON user_favorite_categories(category_id);

-- Enable Row Level Security
ALTER TABLE user_favorite_categories ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view own favorite categories" ON user_favorite_categories;
DROP POLICY IF EXISTS "Users can insert own favorite categories" ON user_favorite_categories;
DROP POLICY IF EXISTS "Users can delete own favorite categories" ON user_favorite_categories;

-- RLS Policy: Users can only view their own favorite categories
CREATE POLICY "Users can view own favorite categories"
    ON user_favorite_categories
    FOR SELECT
    TO authenticated
    USING (
        user_profile_id IN (
            SELECT user_profile_id 
            FROM user_profiles 
            WHERE user_auth_id::text = auth.uid()::text
        )
    );

-- RLS Policy: Users can insert their own favorite categories
CREATE POLICY "Users can insert own favorite categories"
    ON user_favorite_categories
    FOR INSERT
    TO authenticated
    WITH CHECK (
        user_profile_id IN (
            SELECT user_profile_id 
            FROM user_profiles 
            WHERE user_auth_id::text = auth.uid()::text
        )
    );

-- RLS Policy: Users can delete their own favorite categories
CREATE POLICY "Users can delete own favorite categories"
    ON user_favorite_categories
    FOR DELETE
    TO authenticated
    USING (
        user_profile_id IN (
            SELECT user_profile_id 
            FROM user_profiles 
            WHERE user_auth_id::text = auth.uid()::text
        )
    );

-- =====================================================
-- TESTING QUERIES
-- =====================================================
-- Insert test favorite category (replace with actual user_profile_id and category_id)
-- INSERT INTO user_favorite_categories (user_profile_id, category_id)
-- VALUES (1, 3), (1, 4); -- User 1 favorites Science and Economics

-- Select favorite categories for current user
-- SELECT ufc.*, c.name AS category_name
-- FROM user_favorite_categories ufc
-- JOIN categories c ON ufc.category_id = c.category_id
-- WHERE ufc.user_profile_id IN (
--     SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
-- );

-- Delete a favorite category
-- DELETE FROM user_favorite_categories
-- WHERE user_profile_id IN (
--     SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
-- )
-- AND category_id = 3;

-- =====================================================
-- ROLLBACK SCRIPT
-- =====================================================
-- DROP TABLE IF EXISTS user_favorite_categories CASCADE;
