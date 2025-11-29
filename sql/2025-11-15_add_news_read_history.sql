-- 2025-11-15_add_news_read_history.sql
-- Purpose: Optional server-side history storage for analytics and History view sync

create table if not exists public.news_read_history (
  read_id bigserial primary key,
  user_profile_id integer not null references public.user_profiles(user_profile_id) on delete cascade,
  news_item_id integer not null references public.news_items(news_item_id) on delete cascade,
  category_id integer references public.categories(category_id) on delete set null,
  started_at timestamptz,
  ended_at timestamptz,
  duration_seconds integer,
  created_at timestamptz not null default now()
);

create index if not exists idx_read_history_user_time on public.news_read_history(user_profile_id, created_at desc);
create index if not exists idx_read_history_news on public.news_read_history(news_item_id);

alter table public.news_read_history enable row level security;

-- Policies (PostgreSQL no soporta IF NOT EXISTS en CREATE POLICY)
-- Drop defensivo para idempotencia
drop policy if exists read_history_select_self on public.news_read_history;
create policy read_history_select_self on public.news_read_history
for select using (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = news_read_history.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
);

drop policy if exists read_history_cud_self on public.news_read_history;
create policy read_history_cud_self on public.news_read_history
for all using (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = news_read_history.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
) with check (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = news_read_history.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
);
