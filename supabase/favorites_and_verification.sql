-- ============================================================
-- Apni Gari — Favorites + Verified seller badge
-- Run in Supabase → SQL Editor
-- Additive only — existing tables and policies are preserved.
-- ============================================================

-- ---------- 1. favorites table ----------
create table if not exists public.favorites (
  id        uuid primary key default gen_random_uuid(),
  user_id   uuid not null references auth.users(id) on delete cascade,
  car_id    uuid not null references public.cars(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_id, car_id)
);

create index if not exists favorites_user_id_idx on public.favorites(user_id);
create index if not exists favorites_car_id_idx on public.favorites(car_id);

alter table public.favorites enable row level security;
grant select, insert, delete on public.favorites to authenticated;

drop policy if exists "users manage own favorites" on public.favorites;
create policy "users manage own favorites" on public.favorites
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- ---------- 2. verified flag on profiles ----------
alter table public.profiles
  add column if not exists is_verified boolean not null default false;

-- Expose is_verified and created_at in the public seller view so the app can read it
create or replace view public.public_seller_profiles
  with (security_barrier = true)
as
select p.id, p.full_name, p.phone, p.city, p.avatar_url, p.is_verified, p.created_at
from public.profiles p
where exists (
  select 1 from public.cars c where c.seller_id = p.id
);

notify pgrst, 'reload schema';
