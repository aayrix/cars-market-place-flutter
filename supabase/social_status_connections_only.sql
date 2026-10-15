-- Run in Supabase SQL Editor to limit status visibility to the author and
-- their accepted connections. The status strip reads this table directly, so
-- row-level security applies to both initial loads and realtime updates.

drop policy if exists "Anyone can view active stories" on public.user_stories;
drop policy if exists "Connected users can view active stories" on public.user_stories;

create policy "Connected users can view active stories"
  on public.user_stories
  for select
  to authenticated
  using (
    expires_at > now()
    and (
      user_id = (select auth.uid())
      or exists (
        select 1
        from public.user_connections c
        where c.status = 'accepted'
          and (
            (c.requester_id = (select auth.uid()) and c.addressee_id = user_stories.user_id)
            or
            (c.addressee_id = (select auth.uid()) and c.requester_id = user_stories.user_id)
          )
      )
    )
  );

-- The app uses a Supabase realtime stream for the status strip.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'user_stories'
  ) then
    alter publication supabase_realtime add table public.user_stories;
  end if;
end $$;

notify pgrst, 'reload schema';
