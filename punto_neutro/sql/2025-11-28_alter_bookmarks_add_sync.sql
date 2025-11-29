-- =====================================================
-- Migration: Alter bookmarks for sync support
-- Date: 2025-11-28
-- Description: Add updated_at, is_deleted for LWW conflict resolution
-- =====================================================

-- Add updated_at column (for Last-Write-Wins conflict resolution)
ALTER TABLE bookmarks 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Add is_deleted column (for soft delete during sync)
ALTER TABLE bookmarks 
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT false;

-- Add comments
COMMENT ON COLUMN bookmarks.updated_at IS 'Last update timestamp for Last-Write-Wins (LWW) conflict resolution';
COMMENT ON COLUMN bookmarks.is_deleted IS 'Soft delete flag for sync - true means bookmark was deleted but kept for sync';

-- Create trigger for updating updated_at automatically
DROP TRIGGER IF EXISTS trigger_set_updated_at_bookmarks ON bookmarks;

CREATE TRIGGER trigger_set_updated_at_bookmarks
    BEFORE UPDATE ON bookmarks
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- Create unique index to prevent duplicate bookmarks per user
-- (user_profile_id, news_item_id) should be unique
DROP INDEX IF EXISTS idx_bookmarks_unique_user_news;
CREATE UNIQUE INDEX IF NOT EXISTS idx_bookmarks_unique_user_news 
    ON bookmarks(user_profile_id, news_item_id);

-- Create index for efficient sync queries (get all bookmarks for user)
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_updated 
    ON bookmarks(user_profile_id, updated_at DESC);

-- Create index for filtering non-deleted bookmarks
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_not_deleted 
    ON bookmarks(user_profile_id, created_at DESC) 
    WHERE is_deleted = false;

-- Enable Row Level Security (if not already enabled)
ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to recreate them
DROP POLICY IF EXISTS "Users can view own bookmarks" ON bookmarks;
DROP POLICY IF EXISTS "Users can insert own bookmarks" ON bookmarks;
DROP POLICY IF EXISTS "Users can update own bookmarks" ON bookmarks;
DROP POLICY IF EXISTS "Users can delete own bookmarks" ON bookmarks;

-- RLS Policy: Users can only view their own bookmarks
CREATE POLICY "Users can view own bookmarks"
    ON bookmarks
    FOR SELECT
    TO authenticated
    USING (
        user_profile_id IN (
            SELECT user_profile_id 
            FROM user_profiles 
            WHERE user_auth_id::text = auth.uid()::text
        )
    );

-- RLS Policy: Users can insert their own bookmarks
CREATE POLICY "Users can insert own bookmarks"
    ON bookmarks
    FOR INSERT
    TO authenticated
    WITH CHECK (
        user_profile_id IN (
            SELECT user_profile_id 
            FROM user_profiles 
            WHERE user_auth_id::text = auth.uid()::text
        )
    );

-- RLS Policy: Users can update their own bookmarks
CREATE POLICY "Users can update own bookmarks"
    ON bookmarks
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

-- RLS Policy: Users can delete their own bookmarks
CREATE POLICY "Users can delete own bookmarks"
    ON bookmarks
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
-- HELPER FUNCTIONS FOR SYNC
-- =====================================================

-- Function to get bookmarks modified after a certain timestamp
CREATE OR REPLACE FUNCTION get_bookmarks_since(
    since_timestamp TIMESTAMPTZ,
    for_user_profile_id BIGINT
)
RETURNS TABLE (
    bookmark_id BIGINT,
    user_profile_id BIGINT,
    news_item_id BIGINT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    is_deleted BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.bookmark_id,
        b.user_profile_id,
        b.news_item_id,
        b.created_at,
        b.updated_at,
        b.is_deleted
    FROM bookmarks b
    WHERE 
        b.user_profile_id = for_user_profile_id
        AND b.updated_at > since_timestamp
    ORDER BY b.updated_at ASC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Function to upsert bookmark with LWW conflict resolution
CREATE OR REPLACE FUNCTION upsert_bookmark_lww(
    p_user_profile_id BIGINT,
    p_news_item_id BIGINT,
    p_is_deleted BOOLEAN,
    p_updated_at TIMESTAMPTZ
)
RETURNS TABLE (
    bookmark_id BIGINT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    is_deleted BOOLEAN,
    conflict_occurred BOOLEAN
) AS $$
DECLARE
    v_existing_updated_at TIMESTAMPTZ;
    v_bookmark_id BIGINT;
    v_created_at TIMESTAMPTZ;
    v_conflict BOOLEAN := false;
BEGIN
    -- Check if bookmark exists
    SELECT b.bookmark_id, b.updated_at, b.created_at 
    INTO v_bookmark_id, v_existing_updated_at, v_created_at
    FROM bookmarks b
    WHERE b.user_profile_id = p_user_profile_id 
      AND b.news_item_id = p_news_item_id;

    IF v_bookmark_id IS NULL THEN
        -- Bookmark doesn't exist, insert it
        INSERT INTO bookmarks (user_profile_id, news_item_id, is_deleted, created_at, updated_at)
        VALUES (p_user_profile_id, p_news_item_id, p_is_deleted, p_updated_at, p_updated_at)
        RETURNING bookmarks.bookmark_id, bookmarks.created_at, bookmarks.updated_at, bookmarks.is_deleted
        INTO v_bookmark_id, v_created_at, p_updated_at, p_is_deleted;
        
        RETURN QUERY SELECT v_bookmark_id, v_created_at, p_updated_at, p_is_deleted, false;
    ELSE
        -- Bookmark exists, check Last-Write-Wins
        IF p_updated_at > v_existing_updated_at THEN
            -- Incoming is newer, update
            UPDATE bookmarks
            SET is_deleted = p_is_deleted,
                updated_at = p_updated_at
            WHERE bookmark_id = v_bookmark_id;
            
            RETURN QUERY SELECT v_bookmark_id, v_created_at, p_updated_at, p_is_deleted, true;
        ELSE
            -- Existing is newer or equal, keep existing
            v_conflict := true;
            RETURN QUERY SELECT v_bookmark_id, v_created_at, v_existing_updated_at, 
                               (SELECT is_deleted FROM bookmarks WHERE bookmark_id = v_bookmark_id),
                               v_conflict;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- TESTING QUERIES
-- =====================================================

-- View all bookmarks for current user (including deleted)
-- SELECT 
--     b.*,
--     ni.title as news_title,
--     c.name as category_name
-- FROM bookmarks b
-- JOIN news_items ni ON b.news_item_id = ni.news_item_id
-- JOIN categories c ON ni.category_id = c.category_id
-- WHERE b.user_profile_id IN (
--     SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
-- )
-- ORDER BY b.updated_at DESC;

-- View only active (non-deleted) bookmarks
-- SELECT 
--     b.*,
--     ni.title as news_title
-- FROM bookmarks b
-- JOIN news_items ni ON b.news_item_id = ni.news_item_id
-- WHERE b.user_profile_id IN (
--     SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
-- )
-- AND b.is_deleted = false
-- ORDER BY b.created_at DESC;

-- Soft delete a bookmark (for sync)
-- UPDATE bookmarks
-- SET is_deleted = true, updated_at = NOW()
-- WHERE bookmark_id = 1
--   AND user_profile_id IN (
--       SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
--   );

-- Get bookmarks modified since last sync
-- SELECT * FROM get_bookmarks_since('2025-11-01 00:00:00+00', 2);

-- Test upsert with LWW
-- SELECT * FROM upsert_bookmark_lww(2, 1, false, NOW());

-- Clean up old deleted bookmarks (run periodically)
-- DELETE FROM bookmarks
-- WHERE is_deleted = true 
--   AND updated_at < NOW() - INTERVAL '30 days';

-- =====================================================
-- SYNC PATTERN EXPLANATION
-- =====================================================
-- 1. Client tracks last_sync_timestamp locally
-- 2. On sync, client calls get_bookmarks_since(last_sync_timestamp, user_id)
-- 3. Client receives all changes since last sync
-- 4. Client applies changes locally, resolving conflicts with LWW
-- 5. Client pushes local changes to server using upsert_bookmark_lww
-- 6. Server resolves conflicts with LWW (newer timestamp wins)
-- 7. Client updates last_sync_timestamp to current time

-- =====================================================
-- ROLLBACK SCRIPT
-- =====================================================
-- DROP FUNCTION IF EXISTS get_bookmarks_since(TIMESTAMPTZ, BIGINT);
-- DROP FUNCTION IF EXISTS upsert_bookmark_lww(BIGINT, BIGINT, BOOLEAN, TIMESTAMPTZ);
-- DROP TRIGGER IF EXISTS trigger_set_updated_at_bookmarks ON bookmarks;
-- DROP INDEX IF EXISTS idx_bookmarks_unique_user_news;
-- DROP INDEX IF EXISTS idx_bookmarks_user_updated;
-- DROP INDEX IF EXISTS idx_bookmarks_user_not_deleted;
-- ALTER TABLE bookmarks DROP COLUMN IF EXISTS updated_at;
-- ALTER TABLE bookmarks DROP COLUMN IF EXISTS is_deleted;
