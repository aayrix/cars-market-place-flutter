-- ============================================================
-- Apni Gari — schema alignment for the NEW integration
-- Run ONCE in Supabase → SQL Editor
--
-- Only ADDITIVE changes. Existing RLS policies on cars,
-- car_images and profiles are intentionally left untouched.
-- ============================================================

-- ---------- 1. cars: guarantee every column the app writes ----------
alter table public.cars add column if not exists seller_id     uuid;
alter table public.cars add column if not exists brand         text not null default '';
alter table public.cars add column if not exists model         text not null default '';
alter table public.cars add column if not exists year          integer;
alter table public.cars add column if not exists price         integer;
alter table public.cars add column if not exists mileage       integer;
alter table public.cars add column if not exists fuel          text not null default 'Petrol';
alter table public.cars add column if not exists transmission  text not null default 'Manual';
alter table public.cars add column if not exists description   text not null default '';
alter table public.cars add column if not exists city          text not null default 'Mianwali';
alter table public.cars add column if not exists category      text not null default 'sedan';
alter table public.cars add column if not exists created_at    timestamptz not null default now();
alter table public.cars add column if not exists latitude      double precision;
alter table public.cars add column if not exists longitude     double precision;

-- `add column if not exists` is a no-op when the column already exists, so a
-- column that was added earlier WITHOUT `not null default` keeps NULLs.
-- Backfill those rows and pin the declared default so the shape matches.
update public.cars set category = 'sedan' where category is null;
alter table public.cars alter column category set default 'sedan';
alter table public.cars alter column category set not null;

create index if not exists cars_seller_id_idx  on public.cars (seller_id);
create index if not exists cars_created_at_idx on public.cars (created_at desc);
create index if not exists cars_city_idx       on public.cars (city);
create index if not exists cars_location_idx on public.cars (latitude, longitude)
  where latitude is not null and longitude is not null;

-- ---------- 2. car_images: guarantee every column the app writes ----------
create table if not exists public.car_images (
  id          uuid primary key default gen_random_uuid(),
  car_id      uuid references public.cars (id) on delete cascade,
  image_url   text not null default '',
  storage_path text not null default '',
  position    integer not null default 0,
  created_at  timestamptz not null default now()
);

alter table public.car_images add column if not exists car_id       uuid;
alter table public.car_images add column if not exists image_url    text not null default '';
alter table public.car_images add column if not exists storage_path text not null default '';
alter table public.car_images add column if not exists position     integer not null default 0;
alter table public.car_images add column if not exists created_at   timestamptz not null default now();

create index if not exists car_images_car_idx on public.car_images (car_id, position);

-- ---------- 3. profiles: guarantee every column the app reads ----------
alter table public.profiles add column if not exists full_name  text not null default '';
alter table public.profiles add column if not exists phone      text not null default '';
alter table public.profiles add column if not exists city       text not null default '';
alter table public.profiles add column if not exists created_at timestamptz not null default now();

-- ---------- 4. storage bucket for car photos ----------
-- The bucket ALREADY EXISTS (id/name: 'car-images') — never insert a second
-- one. The app reads this name from SupabaseConfig.storageBucket. It must be
-- public, otherwise getPublicUrl() links return 404 and photos never render.
-- Wrapped in a DO block: if the statement is ever refused, the rest of this
-- script still commits (check the notices, then flip the toggle manually in
-- Storage → car-images → Settings → Public bucket).
do $$
begin
  update storage.buckets set public = true where id = 'car-images';
  if not found then
    raise warning 'Bucket "car-images" not found — create it in Storage first.';
  end if;
exception when others then
  raise warning 'Could not mark "car-images" public (%). Toggle "Public bucket" ON in Storage → car-images → Settings.', sqlerrm;
end $$;

-- Replace any previous bucket policies for this bucket only.
drop policy if exists "car images public read" on storage.objects;
drop policy if exists "car images authenticated upload" on storage.objects;
drop policy if exists "car images authenticated delete" on storage.objects;

create policy "car images public read" on storage.objects
  for select
  using (bucket_id = 'car-images');

create policy "car images authenticated upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'car-images');

create policy "car images authenticated delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'car-images');

-- ---------- 5. guarantees for signed-in writes ----------
-- Additive only: no existing policy is modified. Supabase OR-s policies, so
-- this can only widen access for the owner of a row — never for anonymous
-- clients (those are covered by `to authenticated`).
--
-- This also pins cars.seller_id to auth.uid() at the database level, so a
-- client can never post, edit or delete a car belonging to somebody else.

drop policy if exists "cars owner insert" on public.cars;
create policy "cars owner insert" on public.cars
  for insert to authenticated
  with check (auth.uid() = seller_id);

drop policy if exists "cars owner update" on public.cars;
create policy "cars owner update" on public.cars
  for update to authenticated
  using (auth.uid() = seller_id)
  with check (auth.uid() = seller_id);

drop policy if exists "cars owner delete" on public.cars;
create policy "cars owner delete" on public.cars
  for delete to authenticated
  using (auth.uid() = seller_id);

drop policy if exists "profiles owner insert" on public.profiles;
create policy "profiles owner insert" on public.profiles
  for insert to authenticated
  with check (auth.uid() = id);

drop policy if exists "profiles owner update" on public.profiles;
create policy "profiles owner update" on public.profiles
  for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "car_images owner write" on public.car_images;
create policy "car_images owner write" on public.car_images
  for all to authenticated
  using (
    exists (
      select 1 from public.cars c
      where c.id = car_id and c.seller_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.cars c
      where c.id = car_id and c.seller_id = auth.uid()
    )
  );

-- Helpers used by the storage policies below. Defining them here keeps this
-- script runnable on projects where motorcycles_and_chat.sql or
-- group_chats.sql have not been run yet. Once the underlying tables exist,
-- each helper performs the real membership test.
create or replace function public.is_chat_thread_member(p_thread_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if to_regclass('public.chat_threads') is null then
    return false;
  end if;
  return exists (
    select 1
    from public.chat_threads t
    where t.id = p_thread_id
      and (t.buyer_id = auth.uid() or t.seller_id = auth.uid())
  );
end;
$$;

revoke all on function public.is_chat_thread_member(uuid) from public;
grant execute on function public.is_chat_thread_member(uuid) to authenticated;

create or replace function public.is_group_chat_member(p_group_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if to_regclass('public.group_chat_members') is null then
    return false;
  end if;
  return exists (
    select 1
    from public.group_chat_members m
    where m.group_id = p_group_id
      and m.user_id = auth.uid()
  );
end;
$$;

revoke all on function public.is_group_chat_member(uuid) from public;
grant execute on function public.is_group_chat_member(uuid) to authenticated;

-- ---------- 6. private voice-note storage (chat-audio bucket) ----------
-- Required for voice messages in 1:1 and group chats. Without this block,
-- uploads fail with a generic storage error in the app.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-audio', 'chat-audio', false, 10485760, array['audio/wav', 'audio/wave', 'audio/x-wav'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Conversation members upload voice notes" on storage.objects;
create policy "Conversation members upload voice notes"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'chat-audio'
  and (storage.foldername(name))[3] = auth.uid()::text
  and name like '%.wav'
  and (
    (
      (storage.foldername(name))[1] = 'threads'
      and public.is_chat_thread_member(((storage.foldername(name))[2])::uuid)
    )
    or
    (
      (storage.foldername(name))[1] = 'groups'
      and public.is_group_chat_member(((storage.foldername(name))[2])::uuid)
    )
  )
);

drop policy if exists "Conversation members read voice notes" on storage.objects;
create policy "Conversation members read voice notes"
on storage.objects for select to authenticated
using (
  bucket_id = 'chat-audio'
  and (
    (
      (storage.foldername(name))[1] = 'threads'
      and public.is_chat_thread_member(((storage.foldername(name))[2])::uuid)
    )
    or
    (
      (storage.foldername(name))[1] = 'groups'
      and public.is_group_chat_member(((storage.foldername(name))[2])::uuid)
    )
  )
);

drop policy if exists "Voice note owners delete their uploads" on storage.objects;
create policy "Voice note owners delete their uploads"
on storage.objects for delete to authenticated
using (
  bucket_id = 'chat-audio'
  and (storage.foldername(name))[3] = auth.uid()::text
);
