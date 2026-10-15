# Supabase security audit

This audit describes the SQL checked into this repository, not a live schema
inspection. The existing project was not queried or changed. The checked-in
migrations assume that some baseline tables and policies were created outside
the repository; verify those in staging before applying `supabase/hardening.sql`.

## Tables and effective access

| Table | RLS from checked-in SQL before hardening | `anon` access in checked-in policies | `authenticated` access in checked-in policies |
|---|---|---|---|
| `cars` (car and motorcycle listings) | Enabled by `email_confirmation_rls.sql`; state may depend on pre-existing setup otherwise | The repository does not define a stable public read policy. Writes are denied by owner policies. | Owner insert/update/delete policies use `seller_id`; public read policy is not defined here. |
| `car_images` | Enabled by `email_confirmation_rls.sql` | Public read when the matching read policy is installed; writes denied. | Read rows through a car and write rows for owned cars. |
| `profiles` | Not consistently enabled by the checked-in schema migrations; verify existing project state | Base-table access depends on prior setup. `public_seller_profiles` explicitly exposes name, phone, city and avatar for users with listings. | Owner insert/update; profile views are readable. `public_user_profiles` is queried by the app but is not created in the earlier migrations. |
| `chat_threads` | Enabled by `motorcycles_and_chat.sql` | No access granted by that migration. | Participants read/update; buyer creates a thread linked to the listing seller. |
| `chat_messages` | Enabled by `motorcycles_and_chat.sql` | No access granted by that migration. | Participants read/insert; recipients may update `read_at` on incoming messages. |
| `group_chats` | Enabled by `group_chats.sql` | No grants or public policy. | Group members read. Creation is through `create_group_chat`. |
| `group_chat_members` | Enabled by `group_chats.sql` | No grants or public policy. | Members read membership rows. |
| `group_chat_messages` | Enabled by `group_chats.sql` | No grants or public policy. | Members read and send messages. |
| `user_connections` | Referenced by app and group SQL; its creation/RLS migration is absent here | Unknown from this repository. | App expects users to read their connections, create requests, and accept/reject incoming requests. |
| `user_stories` | Referenced by app and story policy migrations; its creation/RLS migration is absent here | The social visibility migration permits accepted connections and the author to read active stories (until hardening is run). | App inserts stories; owner writes and connection-scoped reads are assumed. |
| `push_tokens` | Enabled by `message_push_and_public_sellers.sql` | No access. | Users manage rows where `user_id = auth.uid()`. |
| `favorites` | Not created or queried by any checked-in SQL/service | Not found. | Not found. |

`schema.sql` creates/aligns `cars` and `car_images`, adds profile fields, and
marks `car-images` public. Its initial car-image upload/delete policy is broad
for any authenticated account; later migrations attempt to narrow it. The
effective policy set depends on which historical scripts have been run and in
what order. `email_confirmation_rls.sql` adds restrictive verified-email
checks. `group_chats.sql` creates three group tables and three
`SECURITY DEFINER` functions. `message_push_and_public_sellers.sql` creates
`push_tokens` and the intentionally phone-bearing seller view. The other SQL
files alter these objects, policies, or the bucket; they do not create a
favorites or separate motorcycle table.

## Views, buckets, policies, and functions

- Views: `public_seller_profiles` exposes `id`, `full_name`, `phone`, `city`,
  and `avatar_url` for users with listings. Phone is intentionally exposed as
  the listing contact. The app also queries `public_user_profiles`; it was
  missing from the checked-in schema and is created by the hardening migration
  with only `id`, `full_name`, `city`, and `avatar_url`.
- Storage buckets: `car-images` is public-readable. `chat-audio` is private
  and is defined by `chat_voice_notes_storage.sql`. No separate avatar bucket
  exists; avatars and story photos use `car-images`.
- Named policies in the checked-in migrations cover cars, car image rows,
  profiles, direct chat threads/messages, group chats/members/messages, push
  tokens, active stories, and `storage.objects`. Several scripts replace the
  same policy names, so an already-live project's effective policies cannot be
  determined from source alone. Inspect `pg_policies` in staging.
- `email_is_verified()` checks the current auth user's confirmation state.
  `is_group_chat_member(uuid)` checks group membership.
  `create_group_chat(text, uuid[])` creates a group and its memberships after
  checking the caller and accepted connections. `update_group_chat_preview()`
  updates the group's last-message preview from a message trigger. All are
  `SECURITY DEFINER`; the hardening migration pins their search path and
  validates the authenticated caller where invoked.

## Hardening migration behavior

`supabase/hardening.sql` enables RLS on every existing public base table, then
sets explicit rules for known app tables. It creates `cars.is_active` with
existing rows defaulting to active, limits public listing reads to active
rows, restricts owner writes, hides base profiles, and adds limited public
profile views. Active story reads are public, as requested by the release
review; this replaces the earlier connections-only visibility rule. Car-image
uploads, overwrites, and deletes require the authenticated user's ID as the
first object-path segment. The bucket is limited to 5 MB and image MIME types.
Group voice notes remain in their existing private bucket.

The app paths after the corresponding Dart change are:

- Listings: `<user-id>/cars/<car-id>/<generated-filename>`
- Avatars: `<user-id>/profiles/<generated-filename>`
- Stories: `<user-id>/stories/<generated-filename>`

The social tables are not defined by repository SQL. The migration applies
their policies conditionally if present and assumes `user_connections` has
`requester_id`, `addressee_id`, `status`, `updated_at`, and `user_stories` has
`user_id`, `expires_at`. Confirm their actual columns in staging first. A
separate motorcycle table and favorites table were not found; motorcycles are
rows in `cars` with `category = 'motorcycle'`.

## Staging test checklist

Use two accounts and a disposable staging project:

1. Account A creates a listing; account B can read it. Mark it inactive; anon
   and B cannot read it.
2. As B, attempt to update or delete A's listing and insert a listing with
   `seller_id = A`; each request must fail.
3. As a non-participant, select a direct thread/message; the result must be
   denied/empty. A participant can mark only incoming messages read; changing
   message text or deleting another user's message must fail.
4. As B, attempt to overwrite A's avatar object path; Storage must reject it.
   Upload an image over 5 MB or a non-image MIME type; Storage must reject it.
5. Verify a user can update their own profile and that a public profile query
   has no phone/email. Confirm only the intended seller-contact view returns a
   seller phone.
6. Verify story reads are public only while active and story writes/deletes
   require the owner.

Do not run this SQL against production until the staging policy tests pass and
the external social-table definitions have been confirmed.
