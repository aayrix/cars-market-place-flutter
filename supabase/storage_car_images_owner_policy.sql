-- Run in Supabase SQL Editor after deploying the Flutter change.
-- Existing bucket only: this does not create a bucket or change table RLS.
-- Public reads are retained because Flutter stores getPublicUrl() values.

-- Remove the app's previous bucket-wide upload rule, if installed.
drop policy if exists "car images authenticated upload" on storage.objects;
drop policy if exists "car images owner boundary" on storage.objects;

-- The app creates the car row before uploading to
-- <car-id>/<timestamp>_<index>.<extension>. A restrictive policy ensures
-- any other permissive INSERT policy cannot grant broader uploads. PUBLIC
-- here means the condition applies to both anon and authenticated roles;
-- auth.uid() ownership makes unauthenticated inserts fail.
create policy "car images owner boundary" on storage.objects
  as restrictive
  for insert to public
  with check (
    bucket_id <> 'car-images'
    or (
      exists (
        select 1
        from public.cars c
        where c.id::text = (storage.foldername(name))[1]
          and c.seller_id = auth.uid()
      )
      and name ~* '\.[a-z0-9]+$'
    )
  );

-- Explicitly grant authenticated owners the intended insert action.
create policy "car images authenticated upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'car-images'
    and exists (
      select 1
      from public.cars c
      where c.id::text = (storage.foldername(name))[1]
        and c.seller_id = auth.uid()
    )
    and name ~* '\.[a-z0-9]+$'
  );

-- The current app uses getPublicUrl(), which requires a public bucket for
-- retrieval. Public read does not grant upload rights.
update storage.buckets
set public = true
where id = 'car-images';

-- Review other policies for consistency and remove obsolete duplicates when
-- appropriate. The restrictive owner boundary above still applies to every
-- INSERT policy on storage.objects.
select policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'storage' and tablename = 'objects';
