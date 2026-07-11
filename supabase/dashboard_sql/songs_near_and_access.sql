-- Mirror of dashboard state, captured 2026-07-11. ALREADY APPLIED REMOTELY —
-- kept here so git records what the live database actually contains.
-- (Definitions pulled verbatim from pg_get_functiondef on the live project.)
--
-- Two read-side functions built in the dashboard after the upload MVP:
--   * songs_near      — powers the map: every (non-expired, has-audio) song
--                       around a point, with distance + in_range computed
--                       server-side. Default search radius 20,000 km ≈ the
--                       whole planet, i.e. "all songs".
--   * get_song_access — the server-side distance gate: hands back a song's
--                       storage_path ONLY if the caller's coords are within
--                       that song's radius_m.
--
-- Storage stays read-locked ON PURPOSE: the private `song` bucket has an
-- insert policy only, so clients can never read audio directly. Playback
-- goes through the `song-access` Edge Function (mirrored in
-- supabase/functions/song-access/song-access.ts), which calls
-- get_song_access and mints a 5-minute signed URL with the service-role
-- key. Do NOT add a select policy — it would bypass the distance gate.

create or replace function public.songs_near(
  user_lat double precision,
  user_lng double precision,
  search_radius_m double precision default 20000000
)
returns table (
  id uuid,
  name text,
  uploaded_by text,
  lat double precision,
  lng double precision,
  radius_m integer,
  distance_m double precision,
  in_range boolean,
  expires_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  viewer_location extensions.geography(Point, 4326);
begin
  viewer_location := extensions.st_setsrid(
    extensions.st_makepoint(songs_near.user_lng, songs_near.user_lat),
    4326
  )::extensions.geography;

  return query
  select
    song.id,
    song.name,
    song.uploaded_by,
    extensions.st_y(song.location::extensions.geometry)::double precision as lat,
    extensions.st_x(song.location::extensions.geometry)::double precision as lng,
    coalesce(song.radius_m, 0) as radius_m,
    extensions.st_distance(song.location, viewer_location)::double precision as distance_m,
    (
      song.radius_m is not null
      and song.radius_m > 0
      and extensions.st_dwithin(song.location, viewer_location, song.radius_m)
    ) as in_range,
    song.expires_at
  from public.song
  where song.location is not null
    and song.storage_path is not null
    and (song.expires_at is null or song.expires_at > now())
    and (
      songs_near.search_radius_m is null
      or songs_near.search_radius_m <= 0
      or extensions.st_dwithin(song.location, viewer_location, songs_near.search_radius_m)
    )
  order by distance_m asc;
end;
$$;

create or replace function public.get_song_access(
  song_id uuid,
  lat double precision,
  lng double precision
)
returns table (
  id uuid,
  name text,
  uploaded_by text,
  storage_path text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  viewer_location extensions.geography(Point, 4326);
begin
  viewer_location := extensions.st_setsrid(
    extensions.st_makepoint(get_song_access.lng, get_song_access.lat),
    4326
  )::extensions.geography;

  return query
  select
    song.id,
    song.name,
    song.uploaded_by,
    song.storage_path
  from public.song
  where song.id = get_song_access.song_id
    and song.location is not null
    and song.storage_path is not null
    and song.radius_m is not null
    and song.radius_m > 0
    and (song.expires_at is null or song.expires_at > now())
    and extensions.st_dwithin(song.location, viewer_location, song.radius_m)
  limit 1;
end;
$$;

-- Execute grants as they exist on the live project (Supabase defaults).
grant execute on function public.songs_near(double precision, double precision, double precision)
  to anon, authenticated, service_role;

grant execute on function public.get_song_access(uuid, double precision, double precision)
  to anon, authenticated, service_role;
