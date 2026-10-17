-- Private storage for voice notes in direct and group conversations.
-- Run after motorcycles_and_chat.sql and group_chats.sql.

-- Helpers used by the policies below. Defining them here keeps this script
-- runnable even when motorcycles_and_chat.sql or group_chats.sql has not been
-- applied yet.
create or replace function public.is_chat_thread_member(p_thread_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if to_regclass('public.chat_threads') is null then
    return false;
  end if;
  return exists (
    select 1
    from public.chat_threads t
    where t.id = p_thread_id
      and (t.buyer_id = auth.uid() or t.seller_id = auth.uid())
  );
end;
$$;

revoke all on function public.is_chat_thread_member(uuid) from public;
grant execute on function public.is_chat_thread_member(uuid) to authenticated;

create or replace function public.is_group_chat_member(p_group_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if to_regclass('public.group_chat_members') is null then
    return false;
  end if;
  return exists (
    select 1
    from public.group_chat_members m
    where m.group_id = p_group_id
      and m.user_id = auth.uid()
  );
end;
$$;

revoke all on function public.is_group_chat_member(uuid) from public;
grant execute on function public.is_group_chat_member(uuid) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-audio', 'chat-audio', false, 10485760, array['audio/wav', 'audio/wave', 'audio/x-wav'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Conversation members upload voice notes" on storage.objects;
create policy "Conversation members upload voice notes"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'chat-audio'
  and (storage.foldername(name))[3] = auth.uid()::text
  and name like '%.wav'
  and (
    (
      (storage.foldername(name))[1] = 'threads'
      and public.is_chat_thread_member(((storage.foldername(name))[2])::uuid)
    )
    or
    (
      (storage.foldername(name))[1] = 'groups'
      and public.is_group_chat_member(((storage.foldername(name))[2])::uuid)
    )
  )
);

drop policy if exists "Conversation members read voice notes" on storage.objects;
create policy "Conversation members read voice notes"
on storage.objects for select to authenticated
using (
  bucket_id = 'chat-audio'
  and (
    (
      (storage.foldername(name))[1] = 'threads'
      and public.is_chat_thread_member(((storage.foldername(name))[2])::uuid)
    )
    or
    (
      (storage.foldername(name))[1] = 'groups'
      and public.is_group_chat_member(((storage.foldername(name))[2])::uuid)
    )
  )
);

drop policy if exists "Voice note owners delete their uploads" on storage.objects;
create policy "Voice note owners delete their uploads"
on storage.objects for delete to authenticated
using (
  bucket_id = 'chat-audio'
  and (storage.foldername(name))[3] = auth.uid()::text
);
