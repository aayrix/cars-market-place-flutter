-- Run after the social tables query. Story photos use the existing public
-- car-images bucket at stories/<auth-user-id>/<generated-file-name>.

-- Extend the existing restrictive upload boundary while preserving the
-- existing car-photo and profile-photo paths.
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
        or (
          (storage.foldername(name))[1] = 'stories'
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

drop policy if exists "story images authenticated upload" on storage.objects;
create policy "story images authenticated upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'car-images'
    and (storage.foldername(name))[1] = 'stories'
    and (storage.foldername(name))[2] = auth.uid()::text
    and name ~* '\.[a-z0-9]+$'
  );

drop policy if exists "story images authenticated delete" on storage.objects;
create policy "story images authenticated delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'car-images'
    and (storage.foldername(name))[1] = 'stories'
    and (storage.foldername(name))[2] = auth.uid()::text
  );
