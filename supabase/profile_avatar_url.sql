-- Fix the live schema for profile photo uploads without changing any rows,
-- policies, Storage buckets, or existing columns.
alter table public.profiles
  add column if not exists avatar_url text not null default '';

-- Make PostgREST re-read the public schema immediately.
notify pgrst, 'reload schema';
