-- 2025-11-15_renumber_rating_items.sql
-- Purpose: Renumber rating_item_id sequentially from 1..N and reset sequence.
-- WARNING: This script updates primary keys. It will ABORT if other tables have FK references
-- to rating_items. Backup DB before running.

-- Safety check: abort if any foreign key references rating_items from other tables
do $$
declare
  refcount int;
begin
  select count(*) into refcount
  from pg_constraint c
  join pg_class conf on c.confrelid = conf.oid
  where c.contype = 'f' and conf.relname = 'rating_items';
  if refcount > 0 then
    raise exception 'Aborting: % foreign key constraints reference rating_items. Please handle FK updates first.', refcount;
  end if;
end$$;

begin;

-- Create mapping old_id -> new_id (1..N ordered by current rating_item_id asc)
create temp table tmp_rating_id_map as
select rating_item_id as old_id,
       row_number() over (order by rating_item_id) as new_id
from public.rating_items;

-- Update existing rating_item_id to temporary negative values to avoid PK conflicts
update public.rating_items r
set rating_item_id = -m.new_id
from tmp_rating_id_map m
where r.rating_item_id = m.old_id;

-- Convert negative temporary ids to final positive ids
update public.rating_items
set rating_item_id = -rating_item_id;

-- Reset sequence to max id
select setval(pg_get_serial_sequence('public.rating_items','rating_item_id'), coalesce((select max(rating_item_id) from public.rating_items), 1), true);

commit;

-- Optional: show mapping (uncomment to inspect)
-- select * from tmp_rating_id_map order by old_id;

-- Note: If there are other processes depending on rating_item_id values, coordinate downtime.
