-- 2025-11-15_add_source_domain_generated_column.sql
-- Purpose: Help answer BQ on user conformity by source/platform per category

-- Add generated source_domain column from original_source_url
alter table if exists public.news_items
  add column if not exists source_domain text generated always as (
    lower(split_part(replace(replace(coalesce(original_source_url,''),'https://',''),'http://',''), '/', 1))
  ) stored;

create index if not exists idx_news_items_source_domain on public.news_items (source_domain);
