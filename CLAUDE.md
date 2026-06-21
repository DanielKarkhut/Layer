# Layer

Location-based music discovery iOS app. Artists drop songs at geographic
coordinates; users within a song's radius can find and download it on a map.
Co-built MVP — keep changes small and surface tradeoffs rather than deciding
architecture unilaterally.

## Stack

* iOS: Swift / SwiftUI, MapKit for the map, CoreLocation for user position
* Local store: SwiftData (the "songs I've found" library on-device)
* Backend: Supabase — Postgres + PostGIS for geo queries, Supabase Storage
  (private `song` bucket) for audio blobs, Supabase Auth (later)
* No separate AWS/S3 — Supabase Storage covers blob storage

## Architecture at a glance

* `songs` is the core table. Location lives in a single `geography(Point, 4326)`
  column called `location` — not separate lat/lng. GiST index: `songs_location_idx`.
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

## Auth — not built yet

* No auth, profiles, RLS, or storage policies exist yet. Don't add them
  speculatively.
* `songs.uploaded_by` is plain `text` for now; it becomes a foreign key to
  `auth.users` when signup is built.
* When auth does land: use  **Supabase Auth** . Never store passwords ourselves.

## Schema source of truth

* Schema is currently built in the Supabase dashboard. Intended convention:
  `supabase db pull` it into `supabase/migrations/` so git becomes the source of
  truth. Once that's done, prefer editing migrations over clicking in the UI.

## Commands

<!-- TODO: fill in once the Xcode project and tooling exist, e.g.: -->

<!-- - Build:  xcodebuild -scheme Layer build -->

<!-- - Test:   xcodebuild test -scheme Layer -destination '...' -->

<!-- - Lint:   swiftlint -->

## Working style

* Make minimal, focused changes — don't refactor unrelated code.
* When two approaches are reasonable, lay out both and let us choose.
* Personal/local preferences go in `CLAUDE.local.md` (gitignored), not here.
