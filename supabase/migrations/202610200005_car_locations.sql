-- Optional listing coordinates used by the nearby cars map.
-- Coordinates are only written when the seller explicitly shares them.
alter table public.cars add column if not exists latitude double precision;
alter table public.cars add column if not exists longitude double precision;

create index if not exists cars_location_idx
  on public.cars (latitude, longitude)
  where latitude is not null and longitude is not null;
