-- Layer — initial schema (song)
-- Captures the current remote state, built in the Supabase dashboard.
-- PostGIS lives in the `extensions` schema, so geography is qualified.

create extension if not exists postgis with schema extensions;

create table public.song (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  storage_path text,                                  -- set once uploads exist
  uploaded_by  text,                                  -- plain name for now → user FK later
  location     extensions.geography(Point, 4326) not null,
  radius_m     integer not null default 100,          -- grab distance, meters
  created_at   timestamptz not null default now(),
  expires_at   timestamptz,                           -- null = never expires
  misc         jsonb
);

create index song_location_idx on public.song using gist (location);