-- Run once in Supabase → SQL Editor (https://supabase.com/dashboard)

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  body_type text not null default '',
  model_name text not null default '',
  model_year integer,
  registration_number text not null default '',
  color text not null default '',
  engine_cc integer,
  location_area text not null default '',
  seller_name text not null default '',
  seller_phone text not null default '',
  asking_price_pkr integer,
  notes text,
  images jsonb not null default '[]'::jsonb,
  seller_id text default 'local-user',
  created_at timestamptz not null default now()
);

alter table public.listings enable row level security;

create policy "Anyone can read listings"
  on public.listings for select
  using (true);

create policy "Anyone can insert listings"
  on public.listings for insert
  with check (true);

create policy "Anyone can update listings"
  on public.listings for update
  using (true);

create policy "Anyone can delete listings"
  on public.listings for delete
  using (true);
