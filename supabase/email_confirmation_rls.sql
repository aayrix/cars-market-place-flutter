-- Apni Gari: require a confirmed email for listing/media writes.
-- Run in Supabase SQL Editor after enabling email confirmations in Auth.
-- Additive/restrictive policies preserve existing owner policies and records.

create or replace function public.email_is_verified()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.users u
    where u.id = (select auth.uid())
      and u.email_confirmed_at is not null
  );
$$;

revoke all on function public.email_is_verified() from public;
grant execute on function public.email_is_verified() to anon, authenticated;

-- Ensure the row policies below are active, without disabling or bypassing RLS.
alter table public.cars enable row level security;
alter table public.car_images enable row level security;

-- Restrictive policies combine with existing owner allow policies using AND.
-- This denies writes even if another permissive policy is broader.
drop policy if exists "verified email required for car insert" on public.cars;
create policy "verified email required for car insert" on public.cars
  as restrictive
  for insert to public
  with check (public.email_is_verified());

drop policy if exists "verified email required for car update" on public.cars;
create policy "verified email required for car update" on public.cars
  as restrictive
  for update to public
  using (public.email_is_verified())
  with check (public.email_is_verified());

drop policy if exists "verified email required for car image rows" on public.car_images;
create policy "verified email required for car image rows" on public.car_images
  as restrictive
  for insert to public
  with check (public.email_is_verified());

drop policy if exists "verified email required for car image row updates" on public.car_images;
create policy "verified email required for car image row updates" on public.car_images
  as restrictive
  for update to public
  using (public.email_is_verified())
  with check (public.email_is_verified());

-- Keep the existing car-images bucket, profile/car path boundaries, and
-- public-read setting unchanged. This adds a verified-account requirement to
-- any INSERT in that bucket while leaving other buckets' policies untouched.
drop policy if exists "verified email required for car-images upload" on storage.objects;
create policy "verified email required for car-images upload" on storage.objects
  as restrictive
  for insert to public
  with check (
    bucket_id <> 'car-images'
    or public.email_is_verified()
  );

-- Inspect the effective policies after applying this migration.
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where (schemaname = 'public' and tablename in ('cars', 'car_images'))
   or (schemaname = 'storage' and tablename = 'objects')
order by schemaname, tablename, policyname;
