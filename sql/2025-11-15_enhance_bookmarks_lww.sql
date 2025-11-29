-- 2025-11-15_enhance_bookmarks_lww.sql
-- Purpose: Make bookmarks conflict-resilient for Local-First + Eventual Connectivity

-- Ensure unique constraint and LWW fields
alter table if exists public.bookmarks
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists is_deleted boolean not null default false;

-- If primary key is bookmark_id already, also enforce per-user uniqueness to avoid dupes
do $$ begin
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'uq_bookmarks_user_news'
  ) then
    create unique index uq_bookmarks_user_news on public.bookmarks(user_profile_id, news_item_id);
  end if;
end $$;

-- trigger for updated_at
create or replace function public.set_updated_at_bookmarks()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end; $$;

drop trigger if exists trg_bookmarks_updated_at on public.bookmarks;
create trigger trg_bookmarks_updated_at
before update on public.bookmarks
for each row execute function public.set_updated_at_bookmarks();

-- RLS (assumes already enabled). Add self-manage policies if missing.
alter table public.bookmarks enable row level security;

drop policy if exists bookmarks_select_self on public.bookmarks;
create policy bookmarks_select_self on public.bookmarks
for select using (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = bookmarks.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
);

drop policy if exists bookmarks_cud_self on public.bookmarks;
create policy bookmarks_cud_self on public.bookmarks
for all using (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = bookmarks.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
) with check (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = bookmarks.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
);
