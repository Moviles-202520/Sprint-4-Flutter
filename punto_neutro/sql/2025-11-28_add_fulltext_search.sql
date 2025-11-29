-- Migration: Add Full-Text Search (FTS) support for news_items
-- Date: 2025-11-28
-- Milestone: F - Feature 5: Searcher + Search Cache

-- Purpose:
--   Enable efficient full-text search over news articles using PostgreSQL's tsvector.
--   This migration adds a generated column for search vector and indexes for performance.
--
-- Features:
--   1. search_vector: tsvector generated column combining title + content
--   2. GIN index on search_vector for fast FTS queries
--   3. Optional lower(title) index for prefix search fallback
--   4. Spanish language configuration (configurable)
--
-- Usage:
--   Query example: SELECT * FROM news_items 
--                  WHERE search_vector @@ to_tsquery('spanish', 'tecnología & innovación');

-- ============================================================================
-- 1. Add search_vector generated column
-- ============================================================================

-- Check if column already exists (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'news_items' 
    AND column_name = 'search_vector'
  ) THEN
    -- Add generated column combining title + content with Spanish language config
    -- Weight 'A' for title (highest priority), 'B' for content
    ALTER TABLE public.news_items
    ADD COLUMN search_vector tsvector
    GENERATED ALWAYS AS (
      setweight(to_tsvector('spanish', coalesce(title, '')), 'A') ||
      setweight(to_tsvector('spanish', coalesce(content, '')), 'B')
    ) STORED;
    
    RAISE NOTICE 'Added search_vector generated column to news_items';
  ELSE
    RAISE NOTICE 'search_vector column already exists, skipping';
  END IF;
END $$;

-- ============================================================================
-- 2. Create GIN index on search_vector for FTS performance
-- ============================================================================

-- GIN (Generalized Inverted Index) is optimal for full-text search
-- Provides fast lookups for @@ (match) operator
CREATE INDEX IF NOT EXISTS idx_news_items_search_vector
ON public.news_items USING GIN (search_vector);

COMMENT ON INDEX idx_news_items_search_vector IS 
'GIN index for full-text search on news_items.search_vector. Enables fast queries with @@ operator.';

-- ============================================================================
-- 3. Optional: Create index on LOWER(title) for prefix search
-- ============================================================================

-- Useful for autocomplete/suggestions when user types partial words
-- Uses text_pattern_ops for LIKE 'prefix%' queries
CREATE INDEX IF NOT EXISTS idx_news_items_title_lower
ON public.news_items (LOWER(title) text_pattern_ops);

COMMENT ON INDEX idx_news_items_title_lower IS 
'B-tree index for case-insensitive prefix search on title. Supports LIKE queries for autocomplete.';

-- ============================================================================
-- 4. Optional: Create index on category_id for filtered searches
-- ============================================================================

-- Many searches will filter by category ("sports news about...")
-- Composite index allows efficient filtered FTS
CREATE INDEX IF NOT EXISTS idx_news_items_category_published
ON public.news_items (category_id, published_at DESC);

COMMENT ON INDEX idx_news_items_category_published IS 
'Composite index for category-filtered searches sorted by recency.';

-- ============================================================================
-- 5. Analyze table to update statistics for query planner
-- ============================================================================

ANALYZE public.news_items;

-- ============================================================================
-- Query examples for testing
-- ============================================================================

-- Example 1: Simple search query
-- SELECT news_item_id, title, 
--        ts_rank(search_vector, query) AS rank
-- FROM news_items,
--      to_tsquery('spanish', 'tecnología | innovación') AS query
-- WHERE search_vector @@ query
-- ORDER BY rank DESC
-- LIMIT 20;

-- Example 2: Search with category filter
-- SELECT news_item_id, title,
--        ts_rank(search_vector, query) AS rank
-- FROM news_items,
--      to_tsquery('spanish', 'elecciones & presidenciales') AS query
-- WHERE search_vector @@ query
--   AND category_id = 'some-category-uuid'
-- ORDER BY rank DESC
-- LIMIT 20;

-- Example 3: Search with highlights (show matching text snippets)
-- SELECT news_item_id, 
--        title,
--        ts_headline('spanish', content, query, 
--                    'StartSel=<mark>, StopSel=</mark>, MaxWords=50') AS snippet
-- FROM news_items,
--      to_tsquery('spanish', 'cambio & climático') AS query
-- WHERE search_vector @@ query
-- ORDER BY ts_rank(search_vector, query) DESC
-- LIMIT 10;

-- Example 4: Autocomplete using prefix match on title
-- SELECT news_item_id, title
-- FROM news_items
-- WHERE LOWER(title) LIKE 'tecno%'
-- ORDER BY published_at DESC
-- LIMIT 10;

-- ============================================================================
-- Rollback script (if needed)
-- ============================================================================

-- To rollback this migration:
-- DROP INDEX IF EXISTS idx_news_items_search_vector;
-- DROP INDEX IF EXISTS idx_news_items_title_lower;
-- DROP INDEX IF EXISTS idx_news_items_category_published;
-- ALTER TABLE public.news_items DROP COLUMN IF EXISTS search_vector;

-- ============================================================================
-- Performance notes
-- ============================================================================

-- 1. GIN index rebuild: If table has millions of rows, index creation may take time.
--    Consider creating index CONCURRENTLY in production:
--    CREATE INDEX CONCURRENTLY idx_news_items_search_vector ON public.news_items USING GIN (search_vector);
--
-- 2. Language configuration: Change 'spanish' to 'english' or other language if content is not Spanish.
--    Available configs: SELECT cfgname FROM pg_ts_config;
--
-- 3. Search query optimization:
--    - Use plainto_tsquery() for simple user input (handles spaces/punctuation)
--    - Use to_tsquery() for advanced queries with operators (&, |, !)
--    - Use phraseto_tsquery() for exact phrase matching
--
-- 4. GIN index maintenance:
--    - GIN indexes can become bloated over time
--    - Periodic REINDEX or VACUUM FULL may be needed for large tables

-- ============================================================================
-- End of migration
-- ============================================================================
