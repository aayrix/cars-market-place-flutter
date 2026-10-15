-- Remove only the verified-email gates added by
-- email_confirmation_rls.sql. Existing owner policies, RLS settings, data,
-- tables, and Storage bucket policies remain in place.
drop policy if exists "verified email required for car insert" on public.cars;
drop policy if exists "verified email required for car update" on public.cars;
drop policy if exists "verified email required for car image rows" on public.car_images;
drop policy if exists "verified email required for car image row updates" on public.car_images;
drop policy if exists "verified email required for car-images upload" on storage.objects;
