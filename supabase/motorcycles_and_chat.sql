-- Run in Supabase SQL Editor to enable motorcycle listings and in-app chat.
-- Adds optional motorcycle fields; existing car records are preserved.

alter table public.cars
  add column if not exists engine_cc integer,
  add column if not exists bike_type text,
  add column if not exists variant text;

-- A thread is one buyer + one seller + one listing.
create table if not exists public.chat_threads (
  id text primary key,
  listing_id uuid not null references public.cars(id) on delete cascade,
  listing_title text not null default '',
  buyer_id uuid not null references auth.users(id) on delete cascade,
  buyer_name text not null default '',
  seller_id uuid not null references auth.users(id) on delete cascade,
  seller_name text not null default '',
  last_message text not null default '',
  last_message_at timestamptz not null default now(),
  constraint chat_threads_distinct_users check (buyer_id <> seller_id)
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id text not null references public.chat_threads(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  sender_name text not null default '',
  body text not null check (length(trim(body)) > 0),
  sent_at timestamptz not null default now(),
  read_at timestamptz
);

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'chat_messages'
      and column_name = 'read_at'
  ) then
    alter table public.chat_messages add column read_at timestamptz;
    -- Existing messages predate read receipts, so don't show them as new.
    update public.chat_messages set read_at = now();
  end if;
end $$;

create index if not exists chat_messages_thread_sent_idx
  on public.chat_messages(thread_id, sent_at);
create index if not exists chat_messages_unread_idx
  on public.chat_messages(thread_id, sender_id)
  where read_at is null;

grant select, insert, update on public.chat_threads to authenticated;
grant select, insert on public.chat_messages to authenticated;
grant update (read_at) on public.chat_messages to authenticated;

alter table public.chat_threads enable row level security;
alter table public.chat_messages enable row level security;

drop policy if exists "chat participants read threads" on public.chat_threads;
create policy "chat participants read threads" on public.chat_threads
  for select to authenticated
  using (auth.uid() = buyer_id or auth.uid() = seller_id);

drop policy if exists "buyers create listing chats" on public.chat_threads;
create policy "buyers create listing chats" on public.chat_threads
  for insert to authenticated
  with check (
    auth.uid() = buyer_id
    and exists (
      select 1 from public.cars c
      where c.id = chat_threads.listing_id
        and c.seller_id = chat_threads.seller_id
    )
  );

drop policy if exists "participants update chat threads" on public.chat_threads;
create policy "participants update chat threads" on public.chat_threads
  for update to authenticated
  using (auth.uid() = buyer_id or auth.uid() = seller_id)
  with check (
    (auth.uid() = buyer_id or auth.uid() = seller_id)
    and exists (
      select 1 from public.cars c
      where c.id = chat_threads.listing_id
        and c.seller_id = chat_threads.seller_id
    )
  );

drop policy if exists "chat participants read messages" on public.chat_messages;
create policy "chat participants read messages" on public.chat_messages
  for select to authenticated
  using (
    exists (
      select 1 from public.chat_threads t
      where t.id = chat_messages.thread_id
        and (auth.uid() = t.buyer_id or auth.uid() = t.seller_id)
    )
  );

drop policy if exists "participants send chat messages" on public.chat_messages;
create policy "participants send chat messages" on public.chat_messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.chat_threads t
      where t.id = chat_messages.thread_id
        and (auth.uid() = t.buyer_id or auth.uid() = t.seller_id)
    )
  );

drop policy if exists "recipients mark incoming messages read" on public.chat_messages;
create policy "recipients mark incoming messages read" on public.chat_messages
  for update to authenticated
  using (
    sender_id <> auth.uid()
    and exists (
      select 1 from public.chat_threads t
      where t.id = chat_messages.thread_id
        and (auth.uid() = t.buyer_id or auth.uid() = t.seller_id)
    )
  )
  with check (
    sender_id <> auth.uid()
    and exists (
      select 1 from public.chat_threads t
      where t.id = chat_messages.thread_id
        and (auth.uid() = t.buyer_id or auth.uid() = t.seller_id)
    )
  );

-- Supabase Realtime streams require both tables in the realtime publication.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'chat_threads'
  ) then
    alter publication supabase_realtime add table public.chat_threads;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'chat_messages'
  ) then
    alter publication supabase_realtime add table public.chat_messages;
  end if;
end $$;

-- Make the new relations visible to PostgREST immediately after the migration.
notify pgrst, 'reload schema';
