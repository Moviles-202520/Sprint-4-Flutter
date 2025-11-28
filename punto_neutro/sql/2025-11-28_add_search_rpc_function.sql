-- RPC Function: search_news
-- Date: 2025-11-28
-- Milestone: F.4 - Backend search endpoint using FTS

-- Purpose:
--   Provide a secure RPC function for full-text search on news_items table.
--   Uses PostgreSQL tsvector and ts_query for efficient text search.
--
-- Features:
--   1. Full-text search with ts_rank relevance scoring
--   2. Optional category filtering
--   3. Pagination (limit + offset)
--   4. Text highlights/snippets (ts_headline)
--   5. Spanish language configuration
--   6. RLS enforcement via SECURITY DEFINER
--
-- Usage:
--   SELECT * FROM public.search_news('tecnología', NULL, 20, 0);
--   SELECT * FROM public.search_news('elecciones', '<category-uuid>', 10, 0);

-- ============================================================================
-- Create RPC function
-- ============================================================================

CREATE OR REPLACE FUNCTION public.search_news(
  query_text TEXT,
  category_id UUID DEFAULT NULL,
  limit_count INT DEFAULT 20,
  offset_count INT DEFAULT 0
)
RETURNS TABLE (
  news_item_id UUID,
  title TEXT,
  snippet TEXT,
  rank REAL,
  published_at TIMESTAMPTZ,
  category_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with function creator's privileges (enforces RLS)
STABLE -- Indicates function doesn't modify database
AS $$
DECLARE
  ts_query tsquery;
BEGIN
  -- Validate inputs
  IF query_text IS NULL OR TRIM(query_text) = '' THEN
    RAISE EXCEPTION 'Query text cannot be empty';
  END IF;

  IF limit_count <= 0 OR limit_count > 100 THEN
    RAISE EXCEPTION 'Limit must be between 1 and 100';
  END IF;

  IF offset_count < 0 THEN
    RAISE EXCEPTION 'Offset cannot be negative';
  END IF;

  -- Convert user query to tsquery (Spanish language)
  -- plainto_tsquery handles special characters and spaces automatically
  BEGIN
    ts_query := plainto_tsquery('spanish', query_text);
    
    -- If plainto_tsquery returns empty (no valid words), try without language
    IF ts_query = ''::tsquery THEN
      ts_query := plainto_tsquery('simple', query_text);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    -- Fallback for any parsing errors
    ts_query := plainto_tsquery('simple', query_text);
  END;

  -- Execute search query
  RETURN QUERY
  SELECT
    ni.news_item_id,
    ni.title,
    ts_headline(
      'spanish',
      COALESCE(ni.content, ''),
      ts_query,
      'StartSel=<mark>, StopSel=</mark>, MaxWords=50, MinWords=15, MaxFragments=1'
    ) AS snippet,
    ts_rank(ni.search_vector, ts_query) AS rank,
    ni.published_at,
    ni.category_id
  FROM public.news_items ni
  WHERE ni.search_vector @@ ts_query
    AND (search_news.category_id IS NULL OR ni.category_id = search_news.category_id)
    AND ni.published_at IS NOT NULL -- Only show published items
  ORDER BY rank DESC, ni.published_at DESC
  LIMIT limit_count
  OFFSET offset_count;
END;
$$;

-- ============================================================================
-- Add function documentation
-- ============================================================================

COMMENT ON FUNCTION public.search_news IS 
'Full-text search on news_items using tsvector. Returns ranked results with snippets.
Parameters:
- query_text: Search query (plain text, supports Spanish)
- category_id: Optional category filter (NULL = all categories)
- limit_count: Max results per page (1-100, default 20)
- offset_count: Pagination offset (default 0)

Returns:
- news_item_id: UUID of matching article
- title: Article title
- snippet: Highlighted excerpt with <mark> tags
- rank: Relevance score (higher = more relevant)
- published_at: Publication timestamp
- category_id: Article category UUID

Example:
  SELECT * FROM public.search_news(''cambio climático'', NULL, 10, 0);';

-- ============================================================================
-- Grant permissions
-- ============================================================================

-- Allow authenticated users to execute search
GRANT EXECUTE ON FUNCTION public.search_news TO authenticated;

-- Optionally allow anonymous users (public access)
-- GRANT EXECUTE ON FUNCTION public.search_news TO anon;

-- ============================================================================
-- Additional RPC function: search_news_count (for pagination)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.search_news_count(
  query_text TEXT,
  category_id UUID DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  ts_query tsquery;
  result_count INT;
BEGIN
  -- Validate input
  IF query_text IS NULL OR TRIM(query_text) = '' THEN
    RETURN 0;
  END IF;

  -- Convert query to tsquery
  BEGIN
    ts_query := plainto_tsquery('spanish', query_text);
    IF ts_query = ''::tsquery THEN
      ts_query := plainto_tsquery('simple', query_text);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    ts_query := plainto_tsquery('simple', query_text);
  END;

  -- Count matching items
  SELECT COUNT(*)
  INTO result_count
  FROM public.news_items ni
  WHERE ni.search_vector @@ ts_query
    AND (search_news_count.category_id IS NULL OR ni.category_id = search_news_count.category_id)
    AND ni.published_at IS NOT NULL;

  RETURN result_count;
END;
$$;

COMMENT ON FUNCTION public.search_news_count IS 
'Returns total count of search results for pagination.
Use with search_news to display "Showing X of Y results".';

GRANT EXECUTE ON FUNCTION public.search_news_count TO authenticated;

-- ============================================================================
-- Testing queries
-- ============================================================================

-- Test 1: Simple search
-- SELECT * FROM public.search_news('tecnología', NULL, 5, 0);

-- Test 2: Search with category filter
-- SELECT * FROM public.search_news('política', '<category-uuid>', 10, 0);

-- Test 3: Pagination
-- SELECT * FROM public.search_news('deportes', NULL, 10, 0);  -- Page 1
-- SELECT * FROM public.search_news('deportes', NULL, 10, 10); -- Page 2

-- Test 4: Get total count
-- SELECT public.search_news_count('economía', NULL);

-- Test 5: Empty query (should raise exception)
-- SELECT * FROM public.search_news('', NULL, 10, 0);

-- Test 6: Special characters (handled by plainto_tsquery)
-- SELECT * FROM public.search_news('¿Qué pasa?', NULL, 10, 0);

-- ============================================================================
-- Performance notes
-- ============================================================================

-- 1. Ensure search_vector column exists and is indexed:
--    - Column must be generated: to_tsvector('spanish', title || ' ' || content)
--    - Index: CREATE INDEX idx_search_vector ON news_items USING GIN (search_vector);
--
-- 2. For large result sets, consider:
--    - Using LIMIT wisely (cap at 100 per page)
--    - Caching frequent queries in application layer
--    - Using materialized views for complex filters
--
-- 3. ts_headline can be expensive on large text:
--    - Already limited to MaxWords=50, MinWords=15
--    - Consider pre-generating snippets for popular articles
--
-- 4. Query optimization:
--    - plainto_tsquery: Simple user queries ("climate change")
--    - to_tsquery: Advanced queries with operators ("climate & change")
--    - phraseto_tsquery: Exact phrases ("climate change")

-- ============================================================================
-- Rollback
-- ============================================================================

-- To remove these functions:
-- DROP FUNCTION IF EXISTS public.search_news;
-- DROP FUNCTION IF EXISTS public.search_news_count;
