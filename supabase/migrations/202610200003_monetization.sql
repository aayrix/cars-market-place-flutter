create table if not exists public.boost_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid not null references public.cars(id) on delete cascade,
  plan_days integer not null check (plan_days in (7,15,30)),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);
alter table public.boost_requests enable row level security;
drop policy if exists boost_requests_owner_all on public.boost_requests;
create policy boost_requests_owner_all on public.boost_requests for all to authenticated
  using (user_id=auth.uid()) with check (user_id=auth.uid());
grant select, insert on public.boost_requests to authenticated;

create or replace view public.public_seller_profiles with (security_barrier=true) as
select p.id, p.full_name, p.phone, p.city, p.avatar_url, p.is_verified, p.created_at, p.verified_phone, p.account_type
from public.profiles p
where exists (select 1 from public.cars c where c.seller_id=p.id and c.is_hidden=false and c.status='active');
