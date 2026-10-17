-- Run in Supabase SQL Editor after deploying the chat-push Edge Function.
-- Existing profiles and listings are preserved; no Storage bucket is created.

-- Device tokens are private to their authenticated owner. Only the server-side
-- Edge Function uses its service credential to find the recipient's tokens.
create table if not exists public.push_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null default 'android',
  updated_at timestamptz not null default now()
);

create index if not exists push_tokens_user_id_idx
  on public.push_tokens(user_id);

alter table public.push_tokens enable row level security;
grant select, insert, update, delete on public.push_tokens to authenticated;

drop policy if exists "users manage own push tokens" on public.push_tokens;
create policy "users manage own push tokens" on public.push_tokens
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Expose only intended public seller-card fields, and only for accounts that
-- have a public listing. The app's seller detail already displays the phone
-- field as the seller's contact method.
alter table public.profiles
  add column if not exists avatar_url text not null default '';

create or replace view public.public_seller_profiles
  with (security_barrier = true)
as
select p.id, p.full_name, p.phone, p.city, p.avatar_url, p.is_verified, p.created_at
from public.profiles p
where exists (
  select 1 from public.cars c where c.seller_id = p.id
);

grant select on public.public_seller_profiles to anon, authenticated;

notify pgrst, 'reload schema';
