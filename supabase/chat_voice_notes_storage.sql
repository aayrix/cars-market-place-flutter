-- Private storage for voice notes in direct and group conversations.
-- Run after motorcycles_and_chat.sql and group_chats.sql.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-audio', 'chat-audio', false, 10485760, array['audio/wav'])
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
      and exists (
        select 1 from public.chat_threads t
        where t.id = (storage.foldername(name))[2]
          and (t.buyer_id = auth.uid() or t.seller_id = auth.uid())
      )
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
      and exists (
        select 1 from public.chat_threads t
        where t.id = (storage.foldername(name))[2]
          and (t.buyer_id = auth.uid() or t.seller_id = auth.uid())
      )
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
