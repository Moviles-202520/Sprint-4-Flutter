-- =====================================================
-- Migration: Create news_read_history table
-- Date: 2025-11-28
-- Description: Optional table for tracking reading history (sync/analytics)
-- =====================================================

-- Create the news_read_history table
CREATE TABLE IF NOT EXISTS news_read_history (
    read_id BIGSERIAL PRIMARY KEY,
    user_profile_id BIGINT NOT NULL REFERENCES user_profiles(user_profile_id) ON DELETE CASCADE,
    news_item_id BIGINT NOT NULL REFERENCES news_items(news_item_id) ON DELETE CASCADE,
    category_id BIGINT REFERENCES categories(category_id) ON DELETE SET NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comments
COMMENT ON TABLE news_read_history IS 'Optional table for tracking user reading history and analytics';
COMMENT ON COLUMN news_read_history.user_profile_id IS 'User who read the article';
COMMENT ON COLUMN news_read_history.news_item_id IS 'Article that was read';
COMMENT ON COLUMN news_read_history.category_id IS 'Category of the article (nullable, for analytics)';
COMMENT ON COLUMN news_read_history.started_at IS 'When the user started reading';
COMMENT ON COLUMN news_read_history.ended_at IS 'When the user finished/exited (nullable if still reading)';
COMMENT ON COLUMN news_read_history.duration_seconds IS 'Time spent reading in seconds';
COMMENT ON COLUMN news_read_history.created_at IS 'When this record was created';

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_news_read_history_user_date 
    ON news_read_history(user_profile_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_news_read_history_news_item 
    ON news_read_history(news_item_id);

CREATE INDEX IF NOT EXISTS idx_news_read_history_category 
    ON news_read_history(category_id);

CREATE INDEX IF NOT EXISTS idx_news_read_history_user_started 
    ON news_read_history(user_profile_id, started_at DESC);

-- Enable Row Level Security
ALTER TABLE news_read_history ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view own read history" ON news_read_history;
DROP POLICY IF EXISTS "Users can insert own read history" ON news_read_history;
DROP POLICY IF EXISTS "Users can update own read history" ON news_read_history;
DROP POLICY IF EXISTS "Users can delete own read history" ON news_read_history;

-- RLS Policy: Users can only view their own read history
CREATE POLICY "Users can view own read history"
    ON news_read_history
    FOR SELECT
    TO authenticated
    USING (
        user_profile_id IN (
            SELECT user_profile_id 
            FROM user_profiles 
            WHERE user_auth_id::text = auth.uid()::text
        )
    );

-- RLS Policy: Users can insert their own read history
CREATE POLICY "Users can insert own read history"
    ON news_read_history
    FOR INSERT
    TO authenticated
    WITH CHECK (
        user_profile_id IN (
            SELECT user_profile_id 
            FROM user_profiles 
            WHERE user_auth_id::text = auth.uid()::text
        )
    );

-- RLS Policy: Users can update their own read history
CREATE POLICY "Users can update own read history"
    ON news_read_history
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

-- RLS Policy: Users can delete their own read history
CREATE POLICY "Users can delete own read history"
    ON news_read_history
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
-- Insert test read history
-- INSERT INTO news_read_history (user_profile_id, news_item_id, category_id, started_at, ended_at, duration_seconds)
-- VALUES (1, 1, 3, NOW() - INTERVAL '5 minutes', NOW(), 300);

-- View reading history for current user
-- SELECT 
--     nrh.*,
--     ni.title as news_title,
--     c.name as category_name
-- FROM news_read_history nrh
-- JOIN news_items ni ON nrh.news_item_id = ni.news_item_id
-- LEFT JOIN categories c ON nrh.category_id = c.category_id
-- WHERE nrh.user_profile_id IN (
--     SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
-- )
-- ORDER BY nrh.created_at DESC
-- LIMIT 20;

-- Get most read articles for current user
-- SELECT 
--     ni.news_item_id,
--     ni.title,
--     COUNT(*) as read_count,
--     SUM(nrh.duration_seconds) as total_duration
-- FROM news_read_history nrh
-- JOIN news_items ni ON nrh.news_item_id = ni.news_item_id
-- WHERE nrh.user_profile_id IN (
--     SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
-- )
-- GROUP BY ni.news_item_id, ni.title
-- ORDER BY read_count DESC
-- LIMIT 10;

-- Get reading statistics by category
-- SELECT 
--     c.name as category_name,
--     COUNT(*) as articles_read,
--     AVG(nrh.duration_seconds) as avg_duration,
--     SUM(nrh.duration_seconds) as total_duration
-- FROM news_read_history nrh
-- JOIN categories c ON nrh.category_id = c.category_id
-- WHERE nrh.user_profile_id IN (
--     SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
-- )
-- GROUP BY c.category_id, c.name
-- ORDER BY articles_read DESC;

-- =====================================================
-- ROLLBACK SCRIPT
-- =====================================================
-- DROP TABLE IF EXISTS news_read_history CASCADE;
