-- Run in Supabase SQL Editor to add group conversations.
begin;

create table if not exists public.group_chats (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 60),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message text not null default '',
  last_message_at timestamptz not null default now()
);

create table if not exists public.group_chat_members (
  group_id uuid not null references public.group_chats(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table if not exists public.group_chat_messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.group_chats(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  sender_name text not null default '',
  body text not null check (length(trim(body)) > 0),
  sent_at timestamptz not null default now()
);

create index if not exists group_chat_members_user_idx
  on public.group_chat_members(user_id, group_id);
create index if not exists group_chat_messages_recent_idx
  on public.group_chat_messages(group_id, sent_at desc);

alter table public.group_chats enable row level security;
alter table public.group_chat_members enable row level security;
alter table public.group_chat_messages enable row level security;

grant select on public.group_chats to authenticated;
grant select on public.group_chat_members to authenticated;
grant select, insert on public.group_chat_messages to authenticated;

create or replace function public.is_group_chat_member(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.group_chat_members m
    where m.group_id = p_group_id and m.user_id = auth.uid()
  );
$$;
revoke all on function public.is_group_chat_member(uuid) from public;
grant execute on function public.is_group_chat_member(uuid) to authenticated;

drop policy if exists "Members read group chats" on public.group_chats;
create policy "Members read group chats" on public.group_chats
  for select to authenticated
  using (public.is_group_chat_member(id));

drop policy if exists "Members read group membership" on public.group_chat_members;
create policy "Members read group membership" on public.group_chat_members
  for select to authenticated
  using (public.is_group_chat_member(group_id));

drop policy if exists "Members read group messages" on public.group_chat_messages;
create policy "Members read group messages" on public.group_chat_messages
  for select to authenticated
  using (public.is_group_chat_member(group_id));

drop policy if exists "Members send group messages" on public.group_chat_messages;
create policy "Members send group messages" on public.group_chat_messages
  for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and public.is_group_chat_member(group_id)
  );

create or replace function public.create_group_chat(
  p_name text,
  p_member_ids uuid[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_group uuid;
begin
  if v_user is null then raise exception 'Sign in to create a group.'; end if;
  if length(trim(coalesce(p_name, ''))) not between 2 and 60 then
    raise exception 'Group name must be between 2 and 60 characters.';
  end if;
  if cardinality(coalesce(p_member_ids, '{}'::uuid[])) > 49 then
    raise exception 'A group can have at most 50 members.';
  end if;
  if not exists (
    select 1 from unnest(coalesce(p_member_ids, '{}'::uuid[])) requested(user_id)
    where requested.user_id <> v_user
  ) then
    raise exception 'Select at least one connection for the group.';
  end if;
  if exists (
    select 1 from unnest(coalesce(p_member_ids, '{}'::uuid[])) requested(user_id)
    where requested.user_id <> v_user
      and not exists (
        select 1 from public.user_connections c
        where c.status = 'accepted'
          and ((c.requester_id = v_user and c.addressee_id = requested.user_id)
            or (c.addressee_id = v_user and c.requester_id = requested.user_id))
      )
  ) then
    raise exception 'Groups can only include your connections.';
  end if;

  insert into public.group_chats(name, created_by)
  values (trim(p_name), v_user)
  returning id into v_group;

  insert into public.group_chat_members(group_id, user_id, role)
  select v_group, members.user_id,
         case when members.user_id = v_user then 'owner' else 'member' end
  from (select distinct unnest(coalesce(p_member_ids, '{}'::uuid[])) as user_id
        union select v_user) members;

  return v_group;
end;
$$;

revoke all on function public.create_group_chat(text, uuid[]) from public;
grant execute on function public.create_group_chat(text, uuid[]) to authenticated;

create or replace function public.update_group_chat_preview()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.group_chats
  set last_message = new.body, last_message_at = new.sent_at
  where id = new.group_id;
  return new;
end;
$$;

drop trigger if exists group_chat_message_preview on public.group_chat_messages;
create trigger group_chat_message_preview
  after insert on public.group_chat_messages
  for each row execute function public.update_group_chat_preview();

do $$
declare t text;
begin
  foreach t in array array['group_chats', 'group_chat_members', 'group_chat_messages'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

notify pgrst, 'reload schema';
commit;
