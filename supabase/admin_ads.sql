-- Admin access for managing every car advertisement.
-- The email below must belong to an existing Auth user; this does not create
-- an account.

-- Public profile cards need a safe view that works for non-sellers too.
alter table public.profiles
  add column if not exists avatar_url text not null default '';
do $$
begin
  if to_regclass('public.public_user_profiles') is null then
    execute 'create view public.public_user_profiles with (security_barrier = true) as select id, full_name, city, avatar_url from public.profiles';
  end if;
end;
$$;
grant select on public.public_user_profiles to anon, authenticated;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;
revoke all on public.admin_users from anon, authenticated;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admin_users where user_id = (select auth.uid())
  );
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

-- Admins can edit or remove any ad. Existing owner policies remain intact.
drop policy if exists "admins read any car" on public.cars;
create policy "admins read any car" on public.cars
  for select to authenticated using (public.is_admin());
do $$
begin
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'cars'
      and policyname = 'cars active read boundary'
  ) and exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'cars'
      and column_name = 'is_active'
  ) then
    execute 'drop policy "cars active read boundary" on public.cars';
    execute 'create policy "cars active read boundary" on public.cars as restrictive for select to anon, authenticated using (is_active or (auth.uid() is not null and public.is_admin()))';
  end if;

  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'cars'
      and policyname = 'cars_visible_unblocked_and_active'
  ) and to_regclass('public.blocked_users') is not null then
    execute 'drop policy cars_visible_unblocked_and_active on public.cars';
    execute $policy$
      create policy cars_visible_unblocked_and_active on public.cars
        as restrictive for select to anon, authenticated
        using (
          (auth.uid() is not null and public.is_admin())
          or seller_id = auth.uid()
          or (not is_hidden and status = 'active' and (
            auth.uid() is null or not exists (
              select 1 from public.blocked_users b
              where b.blocker_id = auth.uid() and b.blocked_id = cars.seller_id
            )
          ))
        )
    $policy$;
  end if;
end;
$$;
drop policy if exists "admins update any car" on public.cars;
create policy "admins update any car" on public.cars
  for update to authenticated using (public.is_admin())
  with check (public.is_admin());
drop policy if exists "admins delete any car" on public.cars;
create policy "admins delete any car" on public.cars
  for delete to authenticated using (public.is_admin());

-- If hardening.sql is installed, its restrictive owner boundaries also need
-- an admin exception. Restrictive policies are ANDed with permissive policies.
drop policy if exists "cars owner update boundary" on public.cars;
create policy "cars owner update boundary" on public.cars
  as restrictive for update to authenticated
  using (auth.uid() = seller_id or public.is_admin())
  with check (auth.uid() = seller_id or public.is_admin());
drop policy if exists "cars owner delete boundary" on public.cars;
create policy "cars owner delete boundary" on public.cars
  as restrictive for delete to authenticated
  using (auth.uid() = seller_id or public.is_admin());

-- Admins can maintain image rows for any listing as well.
drop policy if exists "admins manage any car images" on public.car_images;
create policy "admins manage any car images" on public.car_images
  for all to authenticated using (public.is_admin())
  with check (public.is_admin());
do $$
begin
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'car_images'
      and policyname = 'car metadata active read boundary'
  ) then
    execute 'drop policy "car metadata active read boundary" on public.car_images';
    execute 'create policy "car metadata active read boundary" on public.car_images as restrictive for select to anon, authenticated using ((auth.uid() is not null and public.is_admin()) or exists (select 1 from public.cars c where c.id = car_images.car_id and c.is_active))';
  end if;
end;
$$;
drop policy if exists "car metadata owner write boundary" on public.car_images;
create policy "car metadata owner write boundary" on public.car_images
  as restrictive for all to authenticated
  using (
    public.is_admin() or exists (
      select 1 from public.cars c
      where c.id = car_images.car_id and c.seller_id = auth.uid()
    )
  )
  with check (
    public.is_admin() or exists (
      select 1 from public.cars c
      where c.id = car_images.car_id and c.seller_id = auth.uid()
    )
  );

-- The app stores objects below <uploader>/cars/<car-id>/..., so admin
-- image changes need an explicit Storage allowance too.
drop policy if exists "admins manage car image objects" on storage.objects;
create policy "admins manage car image objects" on storage.objects
  for all to authenticated
  using (bucket_id = 'car-images' and public.is_admin())
  with check (bucket_id = 'car-images' and public.is_admin());

-- Some installations have a restrictive owner boundary policy. Recreate it
-- with an admin exception so it does not override the policy above.
drop policy if exists "car images owner boundary" on storage.objects;
create policy "car images owner boundary" on storage.objects
  as restrictive for insert to public
  with check (
    bucket_id <> 'car-images'
    or public.is_admin()
    or exists (
      select 1 from public.cars c
      where c.id::text = (storage.foldername(name))[1]
        and c.seller_id = auth.uid()
    )
  );

drop policy if exists "car-images overwrite boundary" on storage.objects;
create policy "car-images overwrite boundary" on storage.objects
  as restrictive for update to anon, authenticated
  using (
    bucket_id <> 'car-images'
    or (auth.uid() is not null and (storage.foldername(name))[1] = auth.uid()::text)
    or public.is_admin()
  )
  with check (
    bucket_id <> 'car-images'
    or (auth.uid() is not null and (storage.foldername(name))[1] = auth.uid()::text)
    or public.is_admin()
  );
drop policy if exists "car-images delete boundary" on storage.objects;
create policy "car-images delete boundary" on storage.objects
  as restrictive for delete to anon, authenticated
  using (
    bucket_id <> 'car-images'
    or (auth.uid() is not null and (storage.foldername(name))[1] = auth.uid()::text)
    or public.is_admin()
  );

-- Promote the intended existing account. Replace this email before running.
insert into public.admin_users (user_id)
select id from auth.users
where lower(email) = lower('aliyanniazi374@gmail.com')
on conflict (user_id) do nothing;

-- Check the promotion. An empty result means the email did not match an account.
select u.id, u.email
from auth.users u join public.admin_users a on a.user_id = u.id;

notify pgrst, 'reload schema';
