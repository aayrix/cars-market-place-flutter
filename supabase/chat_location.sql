-- Run in Supabase SQL Editor to enable location sharing in chats.
-- Adds location columns to 1:1 and group chat messages, and lets message
-- senders refresh their own live-location pins.

-- ---------- 1:1 chat messages ----------
alter table public.chat_messages add column if not exists latitude double precision;
alter table public.chat_messages add column if not exists longitude double precision;
alter table public.chat_messages add column if not exists location_title text not null default '';
alter table public.chat_messages add column if not exists location_expires_at timestamptz;
alter table public.chat_messages add column if not exists location_updated_at timestamptz;

create index if not exists chat_messages_location_idx
  on public.chat_messages(thread_id) where latitude is not null;

-- ---------- group chat messages ----------
alter table public.group_chat_messages add column if not exists latitude double precision;
alter table public.group_chat_messages add column if not exists longitude double precision;
alter table public.group_chat_messages add column if not exists location_title text not null default '';
alter table public.group_chat_messages add column if not exists location_expires_at timestamptz;
alter table public.group_chat_messages add column if not exists location_updated_at timestamptz;

-- ---------- let senders refresh their own live-location messages ----------
drop policy if exists "sender updates own live location" on public.chat_messages;
create policy "sender updates own live location" on public.chat_messages
  for update to authenticated
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

grant update (latitude, longitude, location_title, location_expires_at, location_updated_at)
  on public.chat_messages to authenticated;

drop policy if exists "sender updates own group live location" on public.group_chat_messages;
create policy "sender updates own group live location" on public.group_chat_messages
  for update to authenticated
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

grant update (latitude, longitude, location_title, location_expires_at, location_updated_at)
  on public.group_chat_messages to authenticated;

-- Keep the generated schema visible to PostGREST / Realtime immediately.
notify pgrst, 'reload schema';
