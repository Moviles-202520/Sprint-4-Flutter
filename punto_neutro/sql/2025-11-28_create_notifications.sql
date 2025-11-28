-- =====================================================
-- Migration: Create notifications system
-- Date: 2025-11-28
-- Description: Notifications table with trigger from engagement_events
-- =====================================================

-- Create notification_type enum
DO $$ BEGIN
    CREATE TYPE notification_type AS ENUM (
        'rating_received',
        'comment_received', 
        'article_published',
        'system'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create the notifications table
CREATE TABLE IF NOT EXISTS notifications (
    notification_id BIGSERIAL PRIMARY KEY,
    user_profile_id BIGINT NOT NULL REFERENCES user_profiles(user_profile_id) ON DELETE CASCADE,
    actor_user_profile_id BIGINT REFERENCES user_profiles(user_profile_id) ON DELETE SET NULL,
    news_item_id BIGINT REFERENCES news_items(news_item_id) ON DELETE CASCADE,
    type notification_type NOT NULL,
    payload JSONB,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comments
COMMENT ON TABLE notifications IS 'Stores user notifications from engagement events and system messages';
COMMENT ON COLUMN notifications.user_profile_id IS 'Recipient user (the one receiving the notification)';
COMMENT ON COLUMN notifications.actor_user_profile_id IS 'User who performed the action (nullable for system notifications)';
COMMENT ON COLUMN notifications.news_item_id IS 'Related news item (nullable for system notifications)';
COMMENT ON COLUMN notifications.type IS 'Type of notification: rating_received, comment_received, article_published, system';
COMMENT ON COLUMN notifications.payload IS 'Additional data as JSON (e.g., comment text, rating value)';
COMMENT ON COLUMN notifications.is_read IS 'Whether the user has read the notification';

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread_date 
    ON notifications(user_profile_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_date 
    ON notifications(user_profile_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_actor 
    ON notifications(actor_user_profile_id);

CREATE INDEX IF NOT EXISTS idx_notifications_news_item 
    ON notifications(news_item_id);

-- Enable Row Level Security
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;

-- RLS Policy: Users can only view their own notifications
CREATE POLICY "Users can view own notifications"
    ON notifications
    FOR SELECT
    TO authenticated
    USING (
        user_profile_id IN (
            SELECT user_profile_id 
            FROM user_profiles 
            WHERE user_auth_id::text = auth.uid()::text
        )
    );

-- RLS Policy: Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications"
    ON notifications
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

-- =====================================================
-- TRIGGER: Create notification from engagement_events
-- =====================================================

-- Create trigger function
CREATE OR REPLACE FUNCTION create_notification_from_engagement()
RETURNS TRIGGER AS $$
DECLARE
    v_news_author_id BIGINT;
    v_notification_type notification_type;
    v_payload JSONB;
    v_comment_text TEXT;
    v_rating_score NUMERIC;
BEGIN
    -- Only process 'completed' actions
    IF NEW.action != 'completed' THEN
        RETURN NEW;
    END IF;

    -- Get the author of the news item
    SELECT user_profile_id INTO v_news_author_id
    FROM news_items
    WHERE news_item_id = NEW.news_item_id;

    -- Don't create notification if user is interacting with their own news
    IF v_news_author_id IS NULL OR v_news_author_id = NEW.user_profile_id THEN
        RETURN NEW;
    END IF;

    -- Determine notification type and build payload
    IF NEW.event_type = 'rating' THEN
        v_notification_type := 'rating_received';
        
        -- Get rating score if available
        SELECT assigned_reliability_score INTO v_rating_score
        FROM rating_items
        WHERE news_item_id = NEW.news_item_id 
          AND user_profile_id = NEW.user_profile_id
        ORDER BY rating_date DESC
        LIMIT 1;
        
        v_payload := jsonb_build_object(
            'event_id', NEW.event_id,
            'rating_score', COALESCE(v_rating_score, 0)
        );
        
    ELSIF NEW.event_type = 'comment' THEN
        v_notification_type := 'comment_received';
        
        -- Get comment text if available
        SELECT content INTO v_comment_text
        FROM comments
        WHERE news_item_id = NEW.news_item_id 
          AND user_profile_id = NEW.user_profile_id
        ORDER BY timestamp DESC
        LIMIT 1;
        
        v_payload := jsonb_build_object(
            'event_id', NEW.event_id,
            'comment_preview', COALESCE(LEFT(v_comment_text, 100), '')
        );
    ELSE
        -- Unknown event type, skip
        RETURN NEW;
    END IF;

    -- Insert the notification
    INSERT INTO notifications (
        user_profile_id,
        actor_user_profile_id,
        news_item_id,
        type,
        payload,
        is_read,
        created_at
    ) VALUES (
        v_news_author_id,      -- Recipient is the news author
        NEW.user_profile_id,   -- Actor is the user who rated/commented
        NEW.news_item_id,
        v_notification_type,
        v_payload,
        false,
        NEW.created_at
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on engagement_events
DROP TRIGGER IF EXISTS trigger_create_notification_from_engagement ON engagement_events;

CREATE TRIGGER trigger_create_notification_from_engagement
    AFTER INSERT ON engagement_events
    FOR EACH ROW
    EXECUTE FUNCTION create_notification_from_engagement();

-- =====================================================
-- TESTING QUERIES
-- =====================================================
-- View all notifications for current user
-- SELECT 
--     n.*,
--     actor.user_auth_email as actor_email,
--     ni.title as news_title
-- FROM notifications n
-- LEFT JOIN user_profiles actor ON n.actor_user_profile_id = actor.user_profile_id
-- LEFT JOIN news_items ni ON n.news_item_id = ni.news_item_id
-- WHERE n.user_profile_id IN (
--     SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
-- )
-- ORDER BY n.created_at DESC;

-- Mark notification as read
-- UPDATE notifications
-- SET is_read = true
-- WHERE notification_id = 1
--   AND user_profile_id IN (
--       SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
--   );

-- Mark all notifications as read
-- UPDATE notifications
-- SET is_read = true
-- WHERE user_profile_id IN (
--     SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
-- )
-- AND is_read = false;

-- Get unread count
-- SELECT COUNT(*) as unread_count
-- FROM notifications
-- WHERE user_profile_id IN (
--     SELECT user_profile_id FROM user_profiles WHERE user_auth_id = auth.uid()
-- )
-- AND is_read = false;

-- =====================================================
-- ROLLBACK SCRIPT
-- =====================================================
-- DROP TRIGGER IF EXISTS trigger_create_notification_from_engagement ON engagement_events;
-- DROP FUNCTION IF EXISTS create_notification_from_engagement();
-- DROP TABLE IF EXISTS notifications CASCADE;
-- DROP TYPE IF EXISTS notification_type CASCADE;
