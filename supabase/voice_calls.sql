-- Run once in the Supabase SQL Editor to enable one-to-one voice call signaling.
create table if not exists public.chat_calls (
  id uuid primary key default gen_random_uuid(),
  thread_id text not null references public.chat_threads(id) on delete cascade,
  caller_id uuid not null references auth.users(id) on delete cascade,
  callee_id uuid not null references auth.users(id) on delete cascade,
  room_name text not null unique,
  call_type text not null default 'voice' check (call_type in ('voice', 'video')),
  status text not null default 'ringing'
    check (status in ('ringing', 'accepted', 'declined', 'ended')),
  created_at timestamptz not null default now(),
  ended_at timestamptz,
  constraint chat_calls_distinct_users check (caller_id <> callee_id)
);

alter table public.chat_calls add column if not exists call_type text not null default 'voice';
alter table public.chat_calls drop constraint if exists chat_calls_call_type_check;
alter table public.chat_calls add constraint chat_calls_call_type_check check (call_type in ('voice', 'video'));

create index if not exists chat_calls_thread_created_idx
  on public.chat_calls(thread_id, created_at desc);

alter table public.chat_calls enable row level security;
grant select, insert on public.chat_calls to authenticated;
grant update (status, ended_at) on public.chat_calls to authenticated;

drop policy if exists "chat participants read calls" on public.chat_calls;
create policy "chat participants read calls" on public.chat_calls
  for select to authenticated using (
    auth.uid() = caller_id or auth.uid() = callee_id
  );

drop policy if exists "chat participants create calls" on public.chat_calls;
create policy "chat participants create calls" on public.chat_calls
  for insert to authenticated with check (
    auth.uid() = caller_id
    and status = 'ringing'
    and exists (
      select 1 from public.chat_threads t
      where t.id = thread_id
        and (auth.uid() = t.buyer_id or auth.uid() = t.seller_id)
        and (callee_id = t.buyer_id or callee_id = t.seller_id)
        and caller_id in (t.buyer_id, t.seller_id)
        and caller_id <> callee_id
    )
  );

drop policy if exists "call participants update calls" on public.chat_calls;
create policy "call participants update calls" on public.chat_calls
  for update to authenticated using (
    auth.uid() = caller_id or auth.uid() = callee_id
  ) with check (
    (auth.uid() = caller_id or auth.uid() = callee_id)
    and status in ('ringing', 'accepted', 'declined', 'ended')
  );

do $$ begin
  alter publication supabase_realtime add table public.chat_calls;
exception when duplicate_object then null;
end $$;
