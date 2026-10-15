-- Apni Gari RLS and Storage hardening. Review and run in staging only.
-- Run after the app, chat, group, social and voice-note schema migrations.
begin;

-- Fail closed for every present public base table, including tables from
-- migrations not checked into this repository.
do $$
declare r record;
begin
  for r in select schemaname, tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table %I.%I enable row level security', r.schemaname, r.tablename);
  end loop;
end;
$$;

-- Cars and motorcycles share public.cars. Existing rows remain active by default.
alter table public.cars add column if not exists is_active boolean not null default true;
revoke all on public.cars from anon, authenticated;
grant select on public.cars to anon, authenticated;
grant insert, update, delete on public.cars to authenticated;
drop policy if exists "cars owner insert" on public.cars;
drop policy if exists "cars owner update" on public.cars;
drop policy if exists "cars owner delete" on public.cars;
drop policy if exists "cars active read" on public.cars;
drop policy if exists "cars active read boundary" on public.cars;
drop policy if exists "cars owner insert boundary" on public.cars;
drop policy if exists "cars owner update boundary" on public.cars;
drop policy if exists "cars owner delete boundary" on public.cars;
create policy "cars active read" on public.cars for select to anon, authenticated using (is_active);
create policy "cars active read boundary" on public.cars as restrictive for select to anon, authenticated using (is_active);
create policy "cars owner insert" on public.cars for insert to authenticated with check (auth.uid() = seller_id);
create policy "cars owner insert boundary" on public.cars as restrictive for insert to authenticated with check (auth.uid() = seller_id);
create policy "cars owner update" on public.cars for update to authenticated using (auth.uid() = seller_id) with check (auth.uid() = seller_id);
create policy "cars owner update boundary" on public.cars as restrictive for update to authenticated using (auth.uid() = seller_id) with check (auth.uid() = seller_id);
create policy "cars owner delete" on public.cars for delete to authenticated using (auth.uid() = seller_id);
create policy "cars owner delete boundary" on public.cars as restrictive for delete to authenticated using (auth.uid() = seller_id);

-- Image metadata follows the owning listing; public reads only for active cars.
revoke all on public.car_images from anon, authenticated;
grant select on public.car_images to anon, authenticated;
grant insert, update, delete on public.car_images to authenticated;
drop policy if exists "car_images owner write" on public.car_images;
drop policy if exists "car_images read with car" on public.car_images;
drop policy if exists "car metadata active read" on public.car_images;
drop policy if exists "car metadata active read boundary" on public.car_images;
drop policy if exists "car metadata owner write" on public.car_images;
drop policy if exists "car metadata owner write boundary" on public.car_images;
create policy "car metadata active read" on public.car_images for select to anon, authenticated using (exists (select 1 from public.cars c where c.id = car_images.car_id and c.is_active));
create policy "car metadata active read boundary" on public.car_images as restrictive for select to anon, authenticated using (exists (select 1 from public.cars c where c.id = car_images.car_id and c.is_active));
create policy "car metadata owner write" on public.car_images for all to authenticated using (exists (select 1 from public.cars c where c.id = car_images.car_id and c.seller_id = auth.uid())) with check (exists (select 1 from public.cars c where c.id = car_images.car_id and c.seller_id = auth.uid()));
create policy "car metadata owner write boundary" on public.car_images as restrictive for all to authenticated using (exists (select 1 from public.cars c where c.id = car_images.car_id and c.seller_id = auth.uid())) with check (exists (select 1 from public.cars c where c.id = car_images.car_id and c.seller_id = auth.uid()));

-- Base profile rows are private. Phone is intentionally public only in the
-- seller contact view; email is never exposed through either view.
revoke all on public.profiles from anon, authenticated;
grant select, insert, update on public.profiles to authenticated;
drop policy if exists "profiles owner insert" on public.profiles;
drop policy if exists "profiles owner update" on public.profiles;
drop policy if exists "profiles own rows" on public.profiles;
drop policy if exists "profiles own rows boundary" on public.profiles;
create policy "profiles own rows" on public.profiles for all to authenticated using (auth.uid() = id) with check (auth.uid() = id);
create policy "profiles own rows boundary" on public.profiles as restrictive for all to authenticated using (auth.uid() = id) with check (auth.uid() = id);
create or replace view public.public_user_profiles with (security_barrier = true) as select id, full_name, city, avatar_url from public.profiles;
grant select on public.public_user_profiles to anon, authenticated;
create or replace view public.public_seller_profiles with (security_barrier = true) as select p.id, p.full_name, p.phone, p.city, p.avatar_url from public.profiles p where exists (select 1 from public.cars c where c.seller_id = p.id and c.is_active);
grant select on public.public_seller_profiles to anon, authenticated;

-- Direct messages: thread membership controls reads and updates; authenticated
-- may update only thread preview fields and message read_at.
revoke all on public.chat_threads from anon, authenticated;
grant select, insert on public.chat_threads to authenticated;
revoke update on public.chat_threads from authenticated;
grant update (last_message, last_message_at) on public.chat_threads to authenticated;
revoke all on public.chat_messages from anon, authenticated;
grant select, insert on public.chat_messages to authenticated;
revoke update on public.chat_messages from authenticated;
revoke update (read_at) on public.chat_messages from authenticated;
grant update (read_at) on public.chat_messages to authenticated;
drop policy if exists "chat participants read threads" on public.chat_threads;
drop policy if exists "buyers create listing chats" on public.chat_threads;
drop policy if exists "participants update chat threads" on public.chat_threads;
drop policy if exists "thread members read" on public.chat_threads;
drop policy if exists "thread members read boundary" on public.chat_threads;
drop policy if exists "buyer creates thread" on public.chat_threads;
drop policy if exists "buyer creates thread boundary" on public.chat_threads;
drop policy if exists "thread participants update" on public.chat_threads;
drop policy if exists "thread participants update boundary" on public.chat_threads;
create policy "thread members read" on public.chat_threads for select to authenticated using (auth.uid() = buyer_id or auth.uid() = seller_id);
create policy "thread members read boundary" on public.chat_threads as restrictive for select to authenticated using (auth.uid() = buyer_id or auth.uid() = seller_id);
create policy "buyer creates thread" on public.chat_threads for insert to authenticated with check (auth.uid() = buyer_id and exists (select 1 from public.cars c where c.id = listing_id and c.seller_id = seller_id));
create policy "buyer creates thread boundary" on public.chat_threads as restrictive for insert to authenticated with check (auth.uid() = buyer_id and exists (select 1 from public.cars c where c.id = listing_id and c.seller_id = seller_id));
create policy "thread participants update" on public.chat_threads for update to authenticated using (auth.uid() = buyer_id or auth.uid() = seller_id) with check (auth.uid() = buyer_id or auth.uid() = seller_id);
create policy "thread participants update boundary" on public.chat_threads as restrictive for update to authenticated using (auth.uid() = buyer_id or auth.uid() = seller_id) with check (auth.uid() = buyer_id or auth.uid() = seller_id);
drop policy if exists "chat participants read messages" on public.chat_messages;
drop policy if exists "participants send chat messages" on public.chat_messages;
drop policy if exists "recipients mark incoming messages read" on public.chat_messages;
drop policy if exists "thread members read messages" on public.chat_messages;
drop policy if exists "thread members read messages boundary" on public.chat_messages;
drop policy if exists "participants send messages" on public.chat_messages;
drop policy if exists "participants send messages boundary" on public.chat_messages;
drop policy if exists "recipients mark messages read" on public.chat_messages;
drop policy if exists "recipients mark messages read boundary" on public.chat_messages;
create policy "thread members read messages" on public.chat_messages for select to authenticated using (exists (select 1 from public.chat_threads t where t.id = thread_id and (auth.uid() = t.buyer_id or auth.uid() = t.seller_id)));
create policy "thread members read messages boundary" on public.chat_messages as restrictive for select to authenticated using (exists (select 1 from public.chat_threads t where t.id = thread_id and (auth.uid() = t.buyer_id or auth.uid() = t.seller_id)));
create policy "participants send messages" on public.chat_messages for insert to authenticated with check (sender_id = auth.uid() and exists (select 1 from public.chat_threads t where t.id = thread_id and (auth.uid() = t.buyer_id or auth.uid() = t.seller_id)));
create policy "participants send messages boundary" on public.chat_messages as restrictive for insert to authenticated with check (sender_id = auth.uid() and exists (select 1 from public.chat_threads t where t.id = thread_id and (auth.uid() = t.buyer_id or auth.uid() = t.seller_id)));
create policy "recipients mark messages read" on public.chat_messages for update to authenticated using (sender_id <> auth.uid() and exists (select 1 from public.chat_threads t where t.id = thread_id and (auth.uid() = t.buyer_id or auth.uid() = t.seller_id))) with check (sender_id <> auth.uid() and exists (select 1 from public.chat_threads t where t.id = thread_id and (auth.uid() = t.buyer_id or auth.uid() = t.seller_id)));
create policy "recipients mark messages read boundary" on public.chat_messages as restrictive for update to authenticated using (sender_id <> auth.uid() and exists (select 1 from public.chat_threads t where t.id = thread_id and (auth.uid() = t.buyer_id or auth.uid() = t.seller_id))) with check (sender_id <> auth.uid() and exists (select 1 from public.chat_threads t where t.id = thread_id and (auth.uid() = t.buyer_id or auth.uid() = t.seller_id)));

-- Group conversations use the membership helper from group_chats.sql.
revoke all on public.group_chats, public.group_chat_members, public.group_chat_messages from anon, authenticated;
grant select on public.group_chats, public.group_chat_members to authenticated;
grant select, insert on public.group_chat_messages to authenticated;
drop policy if exists "Members read group chats" on public.group_chats;
drop policy if exists "Members read group membership" on public.group_chat_members;
drop policy if exists "Members read group messages" on public.group_chat_messages;
drop policy if exists "Members send group messages" on public.group_chat_messages;
drop policy if exists "group members read" on public.group_chats;
drop policy if exists "group members read boundary" on public.group_chats;
drop policy if exists "group members read membership" on public.group_chat_members;
drop policy if exists "group members read membership boundary" on public.group_chat_members;
drop policy if exists "group members read messages" on public.group_chat_messages;
drop policy if exists "group members read messages boundary" on public.group_chat_messages;
drop policy if exists "group members send" on public.group_chat_messages;
drop policy if exists "group members send boundary" on public.group_chat_messages;
create policy "group members read" on public.group_chats for select to authenticated using (public.is_group_chat_member(id));
create policy "group members read boundary" on public.group_chats as restrictive for select to authenticated using (public.is_group_chat_member(id));
create policy "group members read membership" on public.group_chat_members for select to authenticated using (public.is_group_chat_member(group_id));
create policy "group members read membership boundary" on public.group_chat_members as restrictive for select to authenticated using (public.is_group_chat_member(group_id));
create policy "group members read messages" on public.group_chat_messages for select to authenticated using (public.is_group_chat_member(group_id));
create policy "group members read messages boundary" on public.group_chat_messages as restrictive for select to authenticated using (public.is_group_chat_member(group_id));
create policy "group members send" on public.group_chat_messages for insert to authenticated with check (sender_id = auth.uid() and public.is_group_chat_member(group_id));
create policy "group members send boundary" on public.group_chat_messages as restrictive for insert to authenticated with check (sender_id = auth.uid() and public.is_group_chat_member(group_id));

-- Social table definitions are provisioned outside this repo. Policies apply
-- conditionally if the referenced tables exist; check their inferred columns in staging.
do $$
begin
  if to_regclass('public.user_connections') is not null then
    execute 'revoke all on public.user_connections from anon, authenticated';
    execute 'grant select, insert, update on public.user_connections to authenticated';
    execute 'revoke update on public.user_connections from authenticated';
    execute 'grant update (status, updated_at) on public.user_connections to authenticated';
    execute 'drop policy if exists "connection parties read" on public.user_connections';
    execute 'drop policy if exists "connection parties read boundary" on public.user_connections';
    execute 'drop policy if exists "connection requester insert" on public.user_connections';
    execute 'drop policy if exists "connection requester insert boundary" on public.user_connections';
    execute 'drop policy if exists "connection addressee update" on public.user_connections';
    execute 'drop policy if exists "connection addressee update boundary" on public.user_connections';
    execute 'create policy "connection parties read" on public.user_connections for select to authenticated using (auth.uid() = requester_id or auth.uid() = addressee_id)';
    execute 'create policy "connection parties read boundary" on public.user_connections as restrictive for select to authenticated using (auth.uid() = requester_id or auth.uid() = addressee_id)';
    execute 'create policy "connection requester insert" on public.user_connections for insert to authenticated with check (auth.uid() = requester_id and requester_id <> addressee_id)';
    execute 'create policy "connection requester insert boundary" on public.user_connections as restrictive for insert to authenticated with check (auth.uid() = requester_id and requester_id <> addressee_id)';
    execute 'create policy "connection addressee update" on public.user_connections for update to authenticated using (auth.uid() = addressee_id) with check (auth.uid() = addressee_id)';
    execute 'create policy "connection addressee update boundary" on public.user_connections as restrictive for update to authenticated using (auth.uid() = addressee_id) with check (auth.uid() = addressee_id)';
  end if;
  if to_regclass('public.user_stories') is not null then
    execute 'revoke all on public.user_stories from anon, authenticated';
    execute 'grant select on public.user_stories to anon, authenticated';
    execute 'grant insert, update, delete on public.user_stories to authenticated';
    execute 'drop policy if exists "Anyone can view active stories" on public.user_stories';
    execute 'drop policy if exists "Connected users can view active stories" on public.user_stories';
    execute 'drop policy if exists "active stories public read" on public.user_stories';
    execute 'drop policy if exists "active stories public read boundary" on public.user_stories';
    execute 'drop policy if exists "story owner insert" on public.user_stories';
    execute 'drop policy if exists "story owner insert boundary" on public.user_stories';
    execute 'drop policy if exists "story owner update" on public.user_stories';
    execute 'drop policy if exists "story owner update boundary" on public.user_stories';
    execute 'drop policy if exists "story owner delete" on public.user_stories';
    execute 'drop policy if exists "story owner delete boundary" on public.user_stories';
    execute 'create policy "active stories public read" on public.user_stories for select to anon, authenticated using (expires_at > now())';
    execute 'create policy "active stories public read boundary" on public.user_stories as restrictive for select to anon, authenticated using (expires_at > now())';
    execute 'create policy "story owner insert" on public.user_stories for insert to authenticated with check (auth.uid() = user_id)';
    execute 'create policy "story owner insert boundary" on public.user_stories as restrictive for insert to authenticated with check (auth.uid() = user_id)';
    execute 'create policy "story owner update" on public.user_stories for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id)';
    execute 'create policy "story owner update boundary" on public.user_stories as restrictive for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id)';
    execute 'create policy "story owner delete" on public.user_stories for delete to authenticated using (auth.uid() = user_id)';
    execute 'create policy "story owner delete boundary" on public.user_stories as restrictive for delete to authenticated using (auth.uid() = user_id)';
  end if;
end;
$$;

-- Device tokens are private and account-owned.
revoke all on public.push_tokens from anon, authenticated;
grant select, insert, update, delete on public.push_tokens to authenticated;
drop policy if exists "users manage own push tokens" on public.push_tokens;
drop policy if exists "push token owner boundary" on public.push_tokens;
create policy "users manage own push tokens" on public.push_tokens for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "push token owner boundary" on public.push_tokens as restrictive for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Public image retrieval is intentional. All car-images write/delete paths
-- must begin with auth.uid(); storage caps uploads at 5 MB and image MIME types.
update storage.buckets set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp','image/heic','image/avif','image/gif']
where id = 'car-images';
drop policy if exists "car images public read" on storage.objects;
drop policy if exists "car images authenticated upload" on storage.objects;
drop policy if exists "car images authenticated delete" on storage.objects;
drop policy if exists "car images owner boundary" on storage.objects;
drop policy if exists "profile images authenticated upload" on storage.objects;
drop policy if exists "profile images authenticated delete" on storage.objects;
drop policy if exists "story images authenticated upload" on storage.objects;
drop policy if exists "story images authenticated delete" on storage.objects;
drop policy if exists "car-images path boundary" on storage.objects;
drop policy if exists "car-images owner upload" on storage.objects;
drop policy if exists "car-images overwrite boundary" on storage.objects;
drop policy if exists "car-images owner overwrite" on storage.objects;
drop policy if exists "car-images delete boundary" on storage.objects;
drop policy if exists "car-images owner delete" on storage.objects;
create policy "car images public read" on storage.objects for select to anon, authenticated using (bucket_id = 'car-images');
create policy "car-images path boundary" on storage.objects as restrictive for insert to anon, authenticated with check (bucket_id <> 'car-images' or (auth.uid() is not null and (storage.foldername(name))[1] = auth.uid()::text));
create policy "car-images owner upload" on storage.objects for insert to authenticated with check (bucket_id = 'car-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "car-images overwrite boundary" on storage.objects as restrictive for update to anon, authenticated using (bucket_id <> 'car-images' or (auth.uid() is not null and (storage.foldername(name))[1] = auth.uid()::text)) with check (bucket_id <> 'car-images' or (auth.uid() is not null and (storage.foldername(name))[1] = auth.uid()::text));
create policy "car-images owner overwrite" on storage.objects for update to authenticated using (bucket_id = 'car-images' and (storage.foldername(name))[1] = auth.uid()::text) with check (bucket_id = 'car-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "car-images delete boundary" on storage.objects as restrictive for delete to anon, authenticated using (bucket_id <> 'car-images' or (auth.uid() is not null and (storage.foldername(name))[1] = auth.uid()::text));
create policy "car-images owner delete" on storage.objects for delete to authenticated using (bucket_id = 'car-images' and (storage.foldername(name))[1] = auth.uid()::text);

-- SECURITY DEFINER helpers use an explicit path and reject an absent auth user.
create or replace function public.email_is_verified() returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (select 1 from auth.users u where u.id = auth.uid() and u.email_confirmed_at is not null);
$$;
revoke all on function public.email_is_verified() from public;
grant execute on function public.email_is_verified() to anon, authenticated;
create or replace function public.is_group_chat_member(p_group_id uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (select 1 from public.group_chat_members m where m.group_id = p_group_id and m.user_id = auth.uid());
$$;
revoke all on function public.is_group_chat_member(uuid) from public;
grant execute on function public.is_group_chat_member(uuid) to authenticated;
create or replace function public.update_group_chat_preview() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or new.sender_id <> auth.uid() or not public.is_group_chat_member(new.group_id) then raise exception 'Unauthorized group message'; end if;
  update public.group_chats set last_message = new.body, last_message_at = new.sent_at where id = new.group_id;
  return new;
end;
$$;

notify pgrst, 'reload schema';
commit;
