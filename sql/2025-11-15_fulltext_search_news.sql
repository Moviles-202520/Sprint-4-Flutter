-- 2025-11-15_fulltext_search_news.sql
-- Purpose: Improve search performance and relevance for Buscador

-- Add generated tsvector column combining title, short and long description
alter table if exists public.news_items
  add column if not exists search_vector tsvector generated always as (
    to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(short_description,'') || ' ' || coalesce(long_description,''))
  ) stored;

-- Create GIN index for fast full-text search
create index if not exists idx_news_items_search_vector on public.news_items using GIN (search_vector);

-- Optional functional index on lower(title) for prefix searches
create index if not exists idx_news_items_title_lower on public.news_items (lower(title));
