alter table public.cars add column if not exists status text not null default 'active';
alter table public.cars add column if not exists is_hidden boolean not null default false;
alter table public.cars add column if not exists is_featured boolean not null default false;
alter table public.cars add column if not exists featured_until timestamptz;
alter table public.profiles add column if not exists verified_phone boolean not null default false;
alter table public.profiles add column if not exists account_type text not null default 'individual';

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  target_type text not null check (target_type in ('listing','user')),
  listing_id uuid references public.cars(id) on delete set null,
  reported_user_id uuid references auth.users(id) on delete set null,
  reason text not null,
  details text not null default '',
  created_at timestamptz not null default now(),
  check ((target_type = 'listing' and listing_id is not null) or
         (target_type = 'user' and reported_user_id is not null))
);
alter table public.reports enable row level security;
drop policy if exists reports_insert_own on public.reports;
create policy reports_insert_own on public.reports for insert to authenticated
  with check (reporter_id = auth.uid());
drop policy if exists reports_read_own on public.reports;
create policy reports_read_own on public.reports for select to authenticated
  using (reporter_id = auth.uid());
grant insert, select on public.reports to authenticated;

create table if not exists public.blocked_users (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
alter table public.blocked_users enable row level security;
drop policy if exists blocks_read_own on public.blocked_users;
create policy blocks_read_own on public.blocked_users for select to authenticated using (blocker_id = auth.uid());
drop policy if exists blocks_insert_own on public.blocked_users;
create policy blocks_insert_own on public.blocked_users for insert to authenticated with check (blocker_id = auth.uid());
drop policy if exists blocks_update_own on public.blocked_users;
create policy blocks_update_own on public.blocked_users for update to authenticated
  using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());
drop policy if exists blocks_delete_own on public.blocked_users;
create policy blocks_delete_own on public.blocked_users for delete to authenticated using (blocker_id = auth.uid());
grant select, insert, update, delete on public.blocked_users to authenticated;

-- Restrictive policies compose with existing permissive policies.
drop policy if exists cars_visible_unblocked_and_active on public.cars;
create policy cars_visible_unblocked_and_active on public.cars as restrictive for select to anon, authenticated
  using (seller_id = auth.uid() or (not is_hidden and status = 'active' and (auth.uid() is null or not exists (
    select 1 from public.blocked_users b where b.blocker_id = auth.uid() and b.blocked_id = cars.seller_id
  ))));
drop policy if exists chats_no_blocked_participants on public.chat_threads;
create policy chats_no_blocked_participants on public.chat_threads as restrictive for insert to authenticated
  with check (not exists (select 1 from public.blocked_users b where b.blocker_id = auth.uid() and b.blocked_id = chat_threads.seller_id)
    and not exists (select 1 from public.blocked_users b where b.blocker_id = chat_threads.buyer_id and b.blocked_id = auth.uid()));
drop policy if exists messages_no_blocked_participants on public.chat_messages;
create policy messages_no_blocked_participants on public.chat_messages as restrictive for insert to authenticated
  with check (exists (select 1 from public.chat_threads t where t.id=chat_messages.thread_id
    and not exists (select 1 from public.blocked_users b where b.blocker_id=auth.uid() and b.blocked_id=case when t.buyer_id=auth.uid() then t.seller_id else t.buyer_id end)
    and not exists (select 1 from public.blocked_users b where b.blocker_id=case when t.buyer_id=auth.uid() then t.seller_id else t.buyer_id end and b.blocked_id=auth.uid())));
-- Admin review: run in the Supabase SQL editor with an admin role.
-- select r.*, c.brand, c.model, c.year, c.price from public.reports r
-- left join public.cars c on c.id = r.listing_id order by r.created_at desc;
