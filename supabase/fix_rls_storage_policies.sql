-- ============================================================
-- Apni Gari — RLS / Storage authorisation FIX
-- Run ONCE in Supabase -> SQL Editor. Idempotent (safe to re-run).
--
-- Diagnosis made against the LIVE project with the publishable key:
--   * public.car_images.storage_path -> 42703 column does not exist
--   * public.car_images.position     -> 42703 column does not exist
--   * public.cars.category           -> exists (add column ran) but
--                                        nullable, NULLs still present
--   * anonymous INSERT into cars / car_images / car-images -> 42501
--     (RLS is ON and blocking anon, as wanted)
--
-- => supabase/schema.sql was NEVER executed, so NONE of the
--    "to authenticated" allow policies exist. Postgres policy
--    evaluation has no allow policy for the `authenticated` role,
--    so every signed-in INSERT/UPDATE/DELETE is refused with 42501
--    "new row violates row-level security policy", which the old
--    build rendered as "Your session is not authorised to do this."
--
-- Constraints honoured: no new bucket, RLS stays ON, writes stay
-- owner-only, no service_role, authentication stays required.
-- ============================================================

-- ---------- 1. car_images: columns the Flutter app writes ----------
alter table public.car_images
  add column if not exists storage_path text not null default '';
alter table public.car_images
  add column if not exists position     integer not null default 0;
create index if not exists car_images_car_idx on public.car_images (car_id, position);

-- ---------- 2. cars.category (the schema mismatch) ----------
-- ADD COLUMN IF NOT EXISTS is a no-op when the column already exists,
-- and a column added that way keeps NULLs -> backfill and pin it.
alter table public.cars add column if not exists category text;
update public.cars set category = 'sedan' where category is null;
alter table public.cars alter column category set default 'sedan';
alter table public.cars alter column category set not null;

-- ---------- 3. cars: signed-in writes pinned to auth.uid() ----------
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

-- ---------- 4. car_images: owner of the parent car may write ----------
-- createCar() inserts the cars row FIRST, then the car_images rows, so
-- the existence check below is satisfied at insert time.
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

-- Image rows are only visible through their (publicly readable) car.
drop policy if exists "car_images read with car" on public.car_images;
create policy "car_images read with car" on public.car_images
  for select
  using (exists (select 1 from public.cars c where c.id = car_id));

-- ---------- 5. profiles: the signed-in user owns their profile row ----------
drop policy if exists "profiles owner insert" on public.profiles;
create policy "profiles owner insert" on public.profiles
  for insert to authenticated
  with check (auth.uid() = id);

drop policy if exists "profiles owner update" on public.profiles;
create policy "profiles owner update" on public.profiles
  for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ---------- 6. Storage: existing bucket "car-images" ----------
-- The Flutter app uses getPublicUrl(), so the intended retrieval model is
-- public reads. This does not make writes public: uploads remain authenticated
-- and are limited to folders for cars owned by auth.uid().
do $$
begin
  update storage.buckets set public = true where id = 'car-images';
  if not found then
    raise warning 'Bucket "car-images" not found - create it in Storage first.';
  end if;
exception when others then
  raise warning 'Could not mark "car-images" public (%).', sqlerrm;
end $$;

drop policy if exists "car images public read" on storage.objects;
drop policy if exists "car images authenticated upload" on storage.objects;
drop policy if exists "car images authenticated delete" on storage.objects;

create policy "car images public read" on storage.objects
  for select
  using (bucket_id = 'car-images');

-- Flutter upload path: '<carId>/<microsecondsSinceEpoch>_<index>.<ext>'.
-- The car row now exists before upload. Require its seller_id to match the
-- authenticated user, preventing writes to another user's car folder.
create policy "car images authenticated upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'car-images'
    and exists (
      select 1 from public.cars c
      where c.id::text = (storage.foldername(name))[1]
        and c.seller_id = auth.uid()
    )
    and name ~* '\.[a-z0-9]+$'
  );

-- Replacements/deletes only work for objects under the authenticated owner's
-- car folders as well. This keeps the existing edit/delete flow functional.
create policy "car images authenticated delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'car-images'
    and exists (
      select 1 from public.cars c
      where c.id::text = (storage.foldername(name))[1]
        and c.seller_id = auth.uid()
    )
  );
