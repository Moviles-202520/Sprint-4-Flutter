-- =====================================================
-- Migration: Create analytics RPC functions for Business Questions
-- Date: 2025-11-29
-- Description: SQL functions for dashboard analytics (BQ H.1 - H.5)
-- =====================================================

-- =====================================================
-- H.1: Dark Mode Adoption Percentage
-- =====================================================
CREATE OR REPLACE FUNCTION get_dark_mode_percentage()
RETURNS NUMERIC AS $$
DECLARE
    total_users INT;
    dark_mode_users INT;
    percentage NUMERIC;
BEGIN
    -- Count total users with preferences
    SELECT COUNT(*) INTO total_users FROM user_preferences;
    
    -- Handle case when no users have preferences set
    IF total_users = 0 THEN
        RETURN 0.0;
    END IF;
    
    -- Count users with dark mode enabled
    SELECT COUNT(*) INTO dark_mode_users 
    FROM user_preferences 
    WHERE dark_mode = true;
    
    -- Calculate percentage
    percentage := (dark_mode_users::NUMERIC / total_users::NUMERIC) * 100.0;
    
    RETURN ROUND(percentage, 2);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Add comment
COMMENT ON FUNCTION get_dark_mode_percentage() IS 
    'Returns percentage of users with dark mode enabled. Returns 0.0 if no preferences exist.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_dark_mode_percentage() TO authenticated;

-- =====================================================
-- TESTING QUERY
-- =====================================================
-- Test the function:
-- SELECT get_dark_mode_percentage();

-- Check user_preferences data:
-- SELECT 
--     COUNT(*) as total_users,
--     COUNT(*) FILTER (WHERE dark_mode = true) as dark_mode_users,
--     ROUND((COUNT(*) FILTER (WHERE dark_mode = true)::NUMERIC / NULLIF(COUNT(*), 0)::NUMERIC) * 100, 2) as percentage
-- FROM user_preferences;

-- =====================================================
-- ROLLBACK SCRIPT
-- =====================================================
-- DROP FUNCTION IF EXISTS get_dark_mode_percentage();
