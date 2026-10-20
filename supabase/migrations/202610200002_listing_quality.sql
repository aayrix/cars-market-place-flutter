alter table public.cars add column if not exists expires_at timestamptz not null default (now() + interval '60 days');
update public.cars set status='expired' where status='active' and expires_at < now();
create index if not exists cars_active_expiry_idx on public.cars(expires_at) where status='active';

create or replace function public.enforce_listing_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare recent_count integer; is_verified boolean;
begin
  if auth.uid() is null or new.seller_id <> auth.uid() then raise exception 'Sign in to post a listing'; end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));
  select coalesce(p.verified_phone, false) into is_verified from public.profiles p where p.id=auth.uid();
  if coalesce(is_verified, false) then return new; end if;
  select count(*) into recent_count from public.cars c where c.seller_id=auth.uid() and c.created_at >= now()-interval '1 day';
  if recent_count >= 3 then raise exception 'Verify your phone to post more than 3 listings per day'; end if;
  return new;
end $$;
revoke all on function public.enforce_listing_limit() from public;
drop trigger if exists enforce_listing_limit_before_insert on public.cars;
create trigger enforce_listing_limit_before_insert before insert on public.cars for each row execute function public.enforce_listing_limit();

create or replace function public.expire_old_listings()
returns integer language plpgsql security definer set search_path = '' as $$
declare changed integer;
begin
  update public.cars set status='expired' where status='active' and expires_at <= now();
  get diagnostics changed = row_count;
  return changed;
end $$;
revoke all on function public.expire_old_listings() from public;
grant execute on function public.expire_old_listings() to authenticated;

do $$ begin
  if exists (select 1 from pg_extension where extname='pg_cron') then
    perform cron.schedule('apni-gari-expire-listings', '0 * * * *', 'select public.expire_old_listings()');
  end if;
end $$;

create or replace function public.protect_listing_admin_fields()
returns trigger language plpgsql set search_path = '' as $$
begin
  if auth.uid() is not null and old.seller_id = auth.uid() and
     (new.is_hidden is distinct from old.is_hidden or new.is_featured is distinct from old.is_featured or new.featured_until is distinct from old.featured_until) then
    raise exception 'Only marketplace administrators can change listing moderation and feature status';
  end if;
  return new;
end $$;
drop trigger if exists protect_listing_admin_fields_before_update on public.cars;
create trigger protect_listing_admin_fields_before_update before update on public.cars for each row execute function public.protect_listing_admin_fields();
