# Layer

Location-based music discovery iOS app. Artists drop songs at geographic
coordinates; users within a song's radius can find and download it on a map.
Co-built MVP — keep changes small and surface tradeoffs rather than deciding
architecture unilaterally.

## Stack

* iOS: Swift / SwiftUI, MapKit for the map, CoreLocation for user position
* Supabase client: `supabase-swift` via Swift Package Manager
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
* Signed-in users land in a three-tab shell: Map, Library, Upload.
* The map reads via `songs_near(user_lat, user_lng, search_radius_m)`, which
  returns pin coordinates (`lat`, `lng`), distance, and an `in_range` flag.
  The app currently asks for a very wide search radius so it can show all
  non-expired songs that have a location and storage path.
* The map uses satellite imagery with realistic elevation and a pitched camera
  centered on the user's current/cached CoreLocation coordinate.
* Audio files live in the private `song` Storage bucket; `song.storage_path`
  points at them.
* Playback/download goes through the `song-access` Edge Function. The function
  validates the user's Supabase Auth token, calls `get_song_access(...)` for a
  server-side PostGIS radius check, then returns a short-lived signed Storage
  URL. The iOS app never needs a broad Storage read policy.
* Downloaded songs are stored locally on-device with SwiftData
  `DownloadedSong` metadata plus an audio file under Application Support.
* Upload MVP is now built in the iOS app:
  * user signs up/signs in with Supabase Auth
  * user picks an audio file with `fileImporter`
  * app uploads to Storage path `{auth.uid()}/{uuid}.{ext}` in bucket `song`
  * app calls `public.create_song(...)` to create the `song` row
  * the drop location is the user's current CoreLocation coordinate

## Critical conventions — get these wrong and things break silently

* **PostGIS is longitude-first.** Always `st_makepoint(lng, lat)`. CoreLocation
  gives `.latitude` / `.longitude` — map them deliberately. Swapping them puts
  every pin in the wrong place with no error raised.
* **Two different radii — never conflate them:**
  * map *search radius* — wide; "what's around me to show as pins"
  * per-song `radius_m` — tight; "am I close enough to download THIS song"
* **Expiration is a filter, never a delete.** Query
  `where expires_at is null or expires_at > now()`. Nothing gets destroyed.
* **Upload path is user-scoped.** Client uploads should stay under
  `{auth.uid()}/...` in the private `song` bucket. The Storage insert policy
  and `create_song` RPC both enforce that convention.
* **The download/playback location gate is server-side.** The client-side
  `in_range` flag is only for UI hints. Security lives in the `song-access`
  Edge Function plus `public.get_song_access(...)`, which checks distance
  against each song's own `radius_m` before returning a signed URL.
* Do not add broad Storage select/update/delete policies speculatively. The
  current read path is signed URLs from the Edge Function.
* PostGIS is installed in the `extensions` schema, so `geography(...)` works
  unprefixed. Do not prefix with `gis.`.
* Geography columns and values can't be created or edited in the Table Editor
  grid — use SQL for those (the column, the index, geo inserts).

## Auth

* Supabase Auth is set up in the dashboard. Never store passwords ourselves.
* The iOS app uses a Supabase publishable/anon key in
  `Layer/Layer/SupabaseConfig.swift`. Never put a secret key or legacy
  `service_role` key in the iOS app.
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
* `public.song` has RLS enabled. The upload MVP avoids a broad client insert
  policy by using the `public.create_song(...)` RPC, which validates
  `auth.uid()`, `storage_path`, `radius_m`, and creates geography server-side.
* Storage now needs one narrow policy for MVP uploads: authenticated users can
  insert objects into bucket `song` only under their own user-id folder.
  Do not add broad Storage select/update/delete policies speculatively.

## Map, playback, and download setup

* Dashboard SQL for map/playback lives at
  `supabase/dashboard_sql/song_map_playback_setup.sql`.
* The same state is mirrored in
  `supabase/migrations/20260702010000_song_map_playback_setup.sql`.
* Run that SQL in the Supabase SQL Editor. It creates/updates:
  * `public.songs_near(user_lat, user_lng, search_radius_m)`
  * `public.get_song_access(song_id, lat, lng)`
* `songs_near` must keep returning pin coordinates as `lat` and `lng` for the
  iOS decoder, but its input parameters are `user_lat` and `user_lng` to avoid
  Postgres parameter/output-column name collisions.
* `get_song_access` must keep using `st_makepoint(lng, lat)` and must only
  return rows when the user's submitted point is within that song's `radius_m`.
* The Edge Function source lives at `supabase/functions/song-access/index.ts`.
  Deploy it in the Supabase Dashboard as an Edge Function named `song-access`.
* The Edge Function expects Supabase's default function secrets (`SUPABASE_URL`,
  publishable/anon key, and secret/service-role key). Secret keys belong only
  in Supabase server-side function secrets, never in the iOS app.
* The iOS app calls the function at
  `{LayerSupabase.urlString}/functions/v1/song-access` with the current auth
  session bearer token and `{ song_id, lat, lng }`.

## Upload setup

* Upload setup state is captured locally in
  `supabase/migrations/20260625010000_song_upload_setup.sql`.
* Run that SQL in the Supabase SQL Editor. It creates/updates:
  * private Storage bucket `song`
  * authenticated Storage insert policy for `{auth.uid()}/...`
  * `public.create_song(name, storage_path, lat, lng, radius_m, expires_at, misc)`
* `create_song` must keep using `st_makepoint(lng, lat)` and should return the
  inserted `song.id`.
* App config lives in `Layer/Layer/SupabaseConfig.swift`; use the Project URL
  and publishable key from Supabase Dashboard -> Connect or Settings -> API Keys.

## Schema source of truth

* Schema is currently built in the Supabase dashboard.
* Know that for now, we are making changes to the database exclusively in the supabase UI!
* SQL files under `supabase/dashboard_sql/` are paste-ready dashboard helpers.
  Mirror applied dashboard changes into `supabase/migrations/` so local git
  still captures the current state.
* Eventual intended convention: `supabase db pull` it into `supabase/migrations/` so git becomes the source of truth.

## Commands

- Build: `xcodebuild -project Layer/Layer.xcodeproj -scheme Layer -destination 'generic/platform=iOS' build`
- Test compile: `xcodebuild -project Layer/Layer.xcodeproj -scheme Layer -destination 'generic/platform=iOS' build-for-testing`

<!-- - Lint:   swiftlint -->

## Working style

* Make minimal, focused changes — don't refactor unrelated code.
* When two approaches are reasonable, lay out both and let us choose.
* Personal/local preferences go in `CLAUDE.local.md` (gitignored), not here.
