-- 2025-11-15_add_user_preferences_and_notifications.sql
-- Purpose: Support User Preferences (favorites, dark mode) and Notifications Center

-- USER PREFERENCES
create table if not exists public.user_preferences (
  user_profile_id integer primary key references public.user_profiles(user_profile_id) on delete cascade,
  dark_mode boolean not null default false,
  language text,
  notifications_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_favorite_categories (
  user_profile_id integer not null references public.user_profiles(user_profile_id) on delete cascade,
  category_id integer not null references public.categories(category_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_profile_id, category_id)
);

-- trigger to keep updated_at fresh
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end; $$;

drop trigger if exists trg_user_preferences_updated_at on public.user_preferences;
create trigger trg_user_preferences_updated_at
before update on public.user_preferences
for each row execute function public.set_updated_at();

-- RLS
alter table public.user_preferences enable row level security;
alter table public.user_favorite_categories enable row level security;

-- Policies (remove unsupported IF NOT EXISTS; cast text -> uuid)
drop policy if exists user_prefs_select_self on public.user_preferences;
create policy user_prefs_select_self on public.user_preferences
for select using (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = user_preferences.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
);

drop policy if exists user_prefs_ins_self on public.user_preferences;
create policy user_prefs_ins_self on public.user_preferences
for insert with check (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = user_preferences.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
);

drop policy if exists user_prefs_upd_self on public.user_preferences;
create policy user_prefs_upd_self on public.user_preferences
for update using (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = user_preferences.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
) with check (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = user_preferences.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
);

drop policy if exists fav_cats_select_self on public.user_favorite_categories;
create policy fav_cats_select_self on public.user_favorite_categories
for select using (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = user_favorite_categories.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
);

drop policy if exists fav_cats_cud_self on public.user_favorite_categories;
create policy fav_cats_cud_self on public.user_favorite_categories
for all using (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = user_favorite_categories.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
) with check (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = user_favorite_categories.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
);

-- NOTIFICATIONS
-- Ensure enum exists: DROP then CREATE for idempotency and older PG compatibility
drop type if exists notification_type;
create type notification_type as enum (
  'rating_received',
  'comment_received',
  'article_published',
  'system'
);

create table if not exists public.notifications (
  notification_id bigserial primary key,
  user_profile_id integer not null references public.user_profiles(user_profile_id) on delete cascade,
  actor_user_profile_id integer references public.user_profiles(user_profile_id) on delete set null,
  news_item_id integer references public.news_items(news_item_id) on delete set null,
  type notification_type not null,
  payload jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_user on public.notifications(user_profile_id, is_read, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists notif_select_self on public.notifications;
create policy notif_select_self on public.notifications
for select using (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = notifications.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
);

drop policy if exists notif_update_self on public.notifications;
create policy notif_update_self on public.notifications
for update using (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = notifications.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
) with check (
  exists (
    select 1 from public.user_profiles p
    where p.user_profile_id = notifications.user_profile_id
      and p.user_auth_id::uuid = auth.uid()
  )
);

-- Trigger: generate notifications from engagement_events (ratings/comments completed)
create or replace function public.create_notification_from_engagement()
returns trigger language plpgsql as $$
declare
  owner_id integer;
  notif_type notification_type;
  actor_id integer;
begin
  if (new.action = 'completed' and (new.event_type = 'rating' or new.event_type = 'comment')) then
    select ni.user_profile_id into owner_id from public.news_items ni where ni.news_item_id = new.news_item_id;
    if owner_id is null then
      return new; -- nothing to do
    end if;
    -- map type
    if new.event_type = 'rating' then
      notif_type := 'rating_received';
    else
      notif_type := 'comment_received';
    end if;
    -- infer actor from sessions if possible
    select us.user_profile_id into actor_id from public.user_sessions us where us.user_session_id = new.user_session_id;

    insert into public.notifications(user_profile_id, actor_user_profile_id, news_item_id, type, payload)
    values (
      owner_id,
      actor_id,
      new.news_item_id,
      notif_type,
      jsonb_build_object(
        'event_id', new.event_id,
        'event_type', new.event_type,
        'action', new.action,
        'created_at', new.created_at
      )
    );
  end if;
  return new;
end; $$;

drop trigger if exists trg_engagement_to_notifications on public.engagement_events;
create trigger trg_engagement_to_notifications
after insert on public.engagement_events
for each row execute function public.create_notification_from_engagement();
