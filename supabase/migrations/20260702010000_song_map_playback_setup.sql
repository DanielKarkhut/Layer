-- Mirrors supabase/dashboard_sql/song_map_playback_setup.sql while dashboard SQL
-- remains the active workflow.

drop function if exists public.songs_near(
  double precision,
  double precision,
  double precision
);

drop function if exists public.get_song_access(
  uuid,
  double precision,
  double precision
);

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

revoke all on function public.songs_near(
  double precision,
  double precision,
  double precision
) from public;

grant execute on function public.songs_near(
  double precision,
  double precision,
  double precision
) to authenticated;

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

revoke all on function public.get_song_access(
  uuid,
  double precision,
  double precision
) from public;

grant execute on function public.get_song_access(
  uuid,
  double precision,
  double precision
) to service_role;
