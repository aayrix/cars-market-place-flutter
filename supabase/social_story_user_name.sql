-- Run in Supabase SQL Editor to add uploader name to user stories.
-- This lets the status strip show the name of the user who posted each story.

alter table public.user_stories add column if not exists user_name text not null default '';

-- Backfill existing stories with the profile name where available.
update public.user_stories us
set user_name = p.full_name
from public.profiles p
where p.id = us.user_id
  and (us.user_name is null or us.user_name = '');

notify pgrst, 'reload schema';
