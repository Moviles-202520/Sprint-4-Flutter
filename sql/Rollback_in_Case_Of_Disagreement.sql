-- =========================================
-- ROLLBACK DE MIGRACIONES 2025-11-15
-- Revierten:
-- 1) user_preferences, user_favorite_categories
-- 2) notifications + trigger desde engagement_events
-- 3) bookmarks LWW (updated_at, is_deleted, unique index, trigger)
-- 4) news_read_history
-- 5) Full-Text Search (search_vector, índices)
-- 6) source_domain en news_items
-- =========================================

-- 1. Eliminar trigger de notificaciones antes de borrar tabla notifications
drop trigger if exists trg_engagement_to_notifications on public.engagement_events;
drop function if exists public.create_notification_from_engagement();

-- 2. Eliminar tablas nuevas (notificaciones primero por enum)
drop table if exists public.notifications cascade;
drop table if exists public.user_favorite_categories cascade;
drop table if exists public.user_preferences cascade;
drop table if exists public.news_read_history cascade;

-- 3. Eliminar enum notification_type si ya no está en uso
do $$
begin
  if exists (
    select 1
    from pg_type t
    where t.typname = 'notification_type'
  ) then
    drop type notification_type;
  end if;
end$$;

-- 4. Revertir cambios en bookmarks
-- Eliminar trigger y función de updated_at
drop trigger if exists trg_bookmarks_updated_at on public.bookmarks;
drop function if exists public.set_updated_at_bookmarks();

-- Eliminar índice único LWW (si existe)
do $$
begin
  if exists (
    select 1 from pg_indexes
    where schemaname='public' and indexname='uq_bookmarks_user_news'
  ) then
    drop index public.uq_bookmarks_user_news;
  end if;
end$$;

-- Eliminar columnas agregadas
alter table if exists public.bookmarks
  drop column if exists updated_at,
  drop column if exists is_deleted;

-- 5. Revertir cambios en news_items: search_vector, source_domain + índices
-- Borrar índices primero si existen
do $$
begin
  if exists (
    select 1 from pg_indexes
    where schemaname='public' and indexname='idx_news_items_search_vector'
  ) then
    drop index public.idx_news_items_search_vector;
  end if;

  if exists (
    select 1 from pg_indexes
    where schemaname='public' and indexname='idx_news_items_title_lower'
  ) then
    drop index public.idx_news_items_title_lower;
  end if;

  if exists (
    select 1 from pg_indexes
    where schemaname='public' and indexname='idx_news_items_source_domain'
  ) then
    drop index public.idx_news_items_source_domain;
  end if;
end$$;

alter table if exists public.news_items
  drop column if exists search_vector,
  drop column if exists source_domain;

-- 6. Eliminar función genérica de updated_at si solo se usaba para user_preferences
drop trigger if exists trg_user_preferences_updated_at on public.user_preferences;
drop function if exists public.set_updated_at();

-- 7. Eliminar políticas RLS creadas (condicionalmente)
-- Nota: versiones antiguas de Postgres no soportan IF EXISTS en DROP POLICY, así que usamos DO blocks.

-- user_preferences policies
do $$
declare
  pol text;
begin
  for pol in
    select policyname from pg_policies where schemaname='public' and tablename='user_preferences'
  loop
    execute format('drop policy %I on public.user_preferences', pol);
  end loop;
end$$;

-- user_favorite_categories policies
do $$
declare
  pol text;
begin
  for pol in
    select policyname from pg_policies where schemaname='public' and tablename='user_favorite_categories'
  loop
    execute format('drop policy %I on public.user_favorite_categories', pol);
  end loop;
end$$;

-- notifications policies
do $$
declare
  pol text;
begin
  for pol in
    select policyname from pg_policies where schemaname='public' and tablename='notifications'
  loop
    execute format('drop policy %I on public.notifications', pol);
  end loop;
end$$;

-- news_read_history policies
do $$
declare
  pol text;
begin
  for pol in
    select policyname from pg_policies where schemaname='public' and tablename='news_read_history'
  loop
    execute format('drop policy %I on public.news_read_history', pol);
  end loop;
end$$;

-- bookmarks policies añadidas (solo si quieres revertir a estado anterior sin RLS custom)
do $$
declare
  pol text;
begin
  for pol in
    select policyname from pg_policies where schemaname='public' and tablename='bookmarks'
      and policyname in ('bookmarks_select_self','bookmarks_cud_self')
  loop
    execute format('drop policy %I on public.bookmarks', pol);
  end loop;
end$$;

-- Opcional: deshabilitar RLS en tablas nuevas (ya borradas) no necesario.
-- Si quieres también quitar RLS de bookmarks:
-- alter table public.bookmarks disable row level security;

-- 8. Limpieza final: confirmar que no queda nada huérfano (no obligatorio)

-- FIN ROLLBACK