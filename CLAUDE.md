# Layer

Location-based music discovery iOS app. Artists drop songs at geographic
coordinates; users within a song's radius can find and download it on a map.
Co-built MVP — keep changes small and surface tradeoffs rather than deciding
architecture unilaterally.

## Stack

* iOS: Swift / SwiftUI, MapKit for the map, CoreLocation for user position
* Local store: SwiftData (the "songs I've found" library on-device)
* Backend: Supabase — Postgres + PostGIS for geo queries, Supabase Storage
  (private `song` bucket) for audio blobs, Supabase Auth
* No separate AWS/S3 — Supabase Storage covers blob storage

## Architecture at a glance

* `song` is the core table. Location lives in a single `geography(Point, 4326)`
  column called `location` — not separate lat/lng. GiST index: `songs_location_idx`.
* Auth uses Supabase Auth's `auth.users` table plus a public mirror table:
  `auth.users.id` -> `public.app_users.id` -> `public.song.user_id`.
  One app user can own many songs.
* The map reads via a `songs_near(lat, lng, search_radius_m)` RPC that returns
  pins + distance + an `in_range` flag.  *(planned — not built yet)*
* Audio files live in the private `song` Storage bucket; `song.storage_path`
  points at them.

## Critical conventions — get these wrong and things break silently

* **PostGIS is longitude-first.** Always `st_makepoint(lng, lat)`. CoreLocation
  gives `.latitude` / `.longitude` — map them deliberately. Swapping them puts
  every pin in the wrong place with no error raised.
* **Two different radii — never conflate them:**
  * map *search radius* — wide; "what's around me to show as pins"
  * per-song `radius_m` — tight; "am I close enough to download THIS song"
* **Expiration is a filter, never a delete.** Query
  `where expires_at is null or expires_at > now()`. Nothing gets destroyed.
* **The download location gate is server-side and NOT built yet.** Any current
  in-range check is client-side and advisory only — never treat it as security.
  The real gate (an Edge Function / RPC handing back a short-lived signed URL
  after a server-side distance check) is deferred.
* PostGIS is installed in the `extensions` schema, so `geography(...)` works
  unprefixed. Do not prefix with `gis.`.
* Geography columns and values can't be created or edited in the Table Editor
  grid — use SQL for those (the column, the index, geo inserts).

## Auth

* Supabase Auth is set up in the dashboard. Never store passwords ourselves.
* `public.app_users` is the app-facing user table. It has:
  * `id uuid primary key references auth.users(id) on delete cascade`
  * `email text`
  * `full_name text`
  * `created_at timestamptz`
  * `updated_at timestamptz`
* `public.app_users` is maintained from `auth.users` by database triggers:
  * insert trigger creates the matching app user row
  * update trigger syncs `email` and `full_name`
  * existing auth users were backfilled into `public.app_users`
* `public.song.user_id` is a nullable `uuid` foreign key to
  `public.app_users(id)` with `on delete cascade`.
* `song.user_id` should be populated for newly-created songs. Existing songs may
  still need manual ownership assignment before making the column `not null`.
* RLS policies are intentionally not configured yet. The current remote schema
  has RLS enabled on `public.song`, but no app-specific RLS policy work has been
  done. Do not add RLS or storage policies speculatively.

## Schema source of truth

* Schema is currently built in the Supabase dashboard.
* Know that for now, we are making changes to the database exclusively in the supabase UI!
* Eventual intended convention: `supabase db pull` it into `supabase/migrations/` so git becomes the source of truth.

## Commands

<!-- TODO: fill in once the Xcode project and tooling exist, e.g.: -->

<!-- - Build:  xcodebuild -scheme Layer build -->

<!-- - Test:   xcodebuild test -scheme Layer -destination '...' -->

<!-- - Lint:   swiftlint -->

## Working style

* Make minimal, focused changes — don't refactor unrelated code.
* When two approaches are reasonable, lay out both and let us choose.
* Personal/local preferences go in `CLAUDE.local.md` (gitignored), not here.
