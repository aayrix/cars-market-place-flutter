-- Run in Supabase SQL Editor to enable account profile photos.
-- Uses the existing public `car-images` bucket; creates no bucket and changes
-- no database RLS settings.

alter table public.profiles
  add column if not exists avatar_url text not null default '';

-- Keep the existing car ownership check while allowing each signed-in user
-- to write only under profiles/<their-auth-uid>/.
drop policy if exists "car images owner boundary" on storage.objects;
create policy "car images owner boundary" on storage.objects
  as restrictive
  for insert to public
  with check (
    bucket_id <> 'car-images'
    or (
      name ~* '\.[a-z0-9]+$'
      and (
        (
          (storage.foldername(name))[1] = 'profiles'
          and (storage.foldername(name))[2] = auth.uid()::text
        )
        or exists (
          select 1
          from public.cars c
          where c.id::text = (storage.foldername(name))[1]
            and c.seller_id = auth.uid()
        )
      )
    )
  );

drop policy if exists "profile images authenticated upload" on storage.objects;
create policy "profile images authenticated upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'car-images'
    and (storage.foldername(name))[1] = 'profiles'
    and (storage.foldername(name))[2] = auth.uid()::text
    and name ~* '\.[a-z0-9]+$'
  );

drop policy if exists "profile images authenticated delete" on storage.objects;
create policy "profile images authenticated delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'car-images'
    and (storage.foldername(name))[1] = 'profiles'
    and (storage.foldername(name))[2] = auth.uid()::text
  );
