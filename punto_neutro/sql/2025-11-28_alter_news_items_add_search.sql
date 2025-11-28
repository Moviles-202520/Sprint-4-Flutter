-- =====================================================
-- Migration: Add Full-Text Search to news_items
-- Date: 2025-11-28
-- Description: Add search_vector (tsvector) and source_domain for better search
-- =====================================================

-- Add source_domain column (extracted from original_source_url)
ALTER TABLE news_items 
ADD COLUMN IF NOT EXISTS source_domain TEXT 
GENERATED ALWAYS AS (
    CASE 
        WHEN original_source_url IS NOT NULL THEN
            REGEXP_REPLACE(
                REGEXP_REPLACE(original_source_url, '^https?://(www\.)?', ''),
                '/.*$',
                ''
            )
        ELSE NULL
    END
) STORED;

-- Add search_vector column (generated from title + descriptions)
ALTER TABLE news_items 
ADD COLUMN IF NOT EXISTS search_vector TSVECTOR 
GENERATED ALWAYS AS (
    to_tsvector('spanish',
        COALESCE(title, '') || ' ' ||
        COALESCE(short_description, '') || ' ' ||
        COALESCE(long_description, '')
    )
) STORED;

-- Add comments
COMMENT ON COLUMN news_items.source_domain IS 'Domain extracted from original_source_url for filtering/grouping';
COMMENT ON COLUMN news_items.search_vector IS 'Full-text search vector for Spanish text search';

-- Create GIN index for full-text search (most important for performance)
CREATE INDEX IF NOT EXISTS idx_news_items_search_vector 
    ON news_items USING GIN(search_vector);

-- Create index on lowercase title for autocomplete/prefix searches
CREATE INDEX IF NOT EXISTS idx_news_items_title_lower 
    ON news_items(LOWER(title));

-- Create index on source_domain for filtering by source
CREATE INDEX IF NOT EXISTS idx_news_items_source_domain 
    ON news_items(source_domain);

-- Create composite index for category + date (common query pattern)
CREATE INDEX IF NOT EXISTS idx_news_items_category_date 
    ON news_items(category_id, publication_date DESC);

-- =====================================================
-- HELPER FUNCTIONS FOR SEARCH
-- =====================================================

-- Function to search news items with ranking
CREATE OR REPLACE FUNCTION search_news_items(
    search_query TEXT,
    category_filter BIGINT DEFAULT NULL,
    limit_results INTEGER DEFAULT 20,
    offset_results INTEGER DEFAULT 0
)
RETURNS TABLE (
    news_item_id BIGINT,
    title TEXT,
    short_description TEXT,
    category_id BIGINT,
    publication_date TIMESTAMPTZ,
    source_domain TEXT,
    rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ni.news_item_id,
        ni.title,
        ni.short_description,
        ni.category_id,
        ni.publication_date,
        ni.source_domain,
        ts_rank(ni.search_vector, plainto_tsquery('spanish', search_query)) as rank
    FROM news_items ni
    WHERE 
        ni.search_vector @@ plainto_tsquery('spanish', search_query)
        AND (category_filter IS NULL OR ni.category_id = category_filter)
    ORDER BY rank DESC, ni.publication_date DESC
    LIMIT limit_results
    OFFSET offset_results;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get search suggestions from titles
CREATE OR REPLACE FUNCTION get_title_suggestions(
    prefix TEXT,
    limit_results INTEGER DEFAULT 10
)
RETURNS TABLE (
    news_item_id BIGINT,
    title TEXT,
    category_id BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ni.news_item_id,
        ni.title,
        ni.category_id
    FROM news_items ni
    WHERE LOWER(ni.title) LIKE LOWER(prefix || '%')
    ORDER BY ni.publication_date DESC
    LIMIT limit_results;
END;
$$ LANGUAGE plpgsql STABLE;

-- =====================================================
-- TESTING QUERIES
-- =====================================================

-- Test full-text search
-- SELECT * FROM search_news_items('NASA Europa vida', NULL, 10, 0);

-- Test full-text search with category filter
-- SELECT * FROM search_news_items('economía inflación', 4, 10, 0);

-- Test title autocomplete
-- SELECT * FROM get_title_suggestions('NASA', 5);

-- Test raw full-text search with highlighting
-- SELECT 
--     news_item_id,
--     title,
--     ts_rank(search_vector, plainto_tsquery('spanish', 'NASA')) as rank,
--     ts_headline('spanish', 
--         title || ' ' || short_description, 
--         plainto_tsquery('spanish', 'NASA'),
--         'MaxWords=50, MinWords=20'
--     ) as highlighted_text
-- FROM news_items
-- WHERE search_vector @@ plainto_tsquery('spanish', 'NASA')
-- ORDER BY rank DESC
-- LIMIT 10;

-- Test source_domain extraction
-- SELECT 
--     news_item_id,
--     title,
--     original_source_url,
--     source_domain
-- FROM news_items
-- LIMIT 10;

-- Get articles by source domain
-- SELECT 
--     source_domain,
--     COUNT(*) as article_count,
--     AVG(average_reliability_score) as avg_reliability
-- FROM news_items
-- WHERE source_domain IS NOT NULL
-- GROUP BY source_domain
-- ORDER BY article_count DESC;

-- =====================================================
-- PERFORMANCE NOTES
-- =====================================================
-- The GIN index on search_vector makes searches very fast (typically <100ms)
-- The generated columns are automatically updated on INSERT/UPDATE
-- Spanish text configuration provides better stemming for Spanish language
-- Use plainto_tsquery for simple searches, to_tsquery for advanced boolean searches

-- =====================================================
-- ROLLBACK SCRIPT
-- =====================================================
-- DROP FUNCTION IF EXISTS search_news_items(TEXT, BIGINT, INTEGER, INTEGER);
-- DROP FUNCTION IF EXISTS get_title_suggestions(TEXT, INTEGER);
-- DROP INDEX IF EXISTS idx_news_items_search_vector;
-- DROP INDEX IF EXISTS idx_news_items_title_lower;
-- DROP INDEX IF EXISTS idx_news_items_source_domain;
-- DROP INDEX IF EXISTS idx_news_items_category_date;
-- ALTER TABLE news_items DROP COLUMN IF EXISTS search_vector;
-- ALTER TABLE news_items DROP COLUMN IF EXISTS source_domain;
