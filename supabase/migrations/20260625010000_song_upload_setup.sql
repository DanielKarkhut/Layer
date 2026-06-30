-- Captures the current upload MVP backend state.
-- This mirrors supabase/dashboard_sql/song_upload_setup.sql, which is the
-- paste-ready dashboard helper while dashboard SQL remains the active workflow.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'song',
  'song',
  false,
  52428800,
  array[
    'audio/aac',
    'audio/flac',
    'audio/mp4',
    'audio/mpeg',
    'audio/ogg',
    'audio/wav',
    'audio/x-m4a',
    'audio/x-wav'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "song uploads in own folder" on storage.objects;

create policy "song uploads in own folder"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'song'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create or replace function public.create_song(
  name text,
  storage_path text,
  lat double precision,
  lng double precision,
  radius_m integer,
  expires_at timestamptz default null,
  misc jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  artist_name text;
  inserted_song_id uuid;
begin
  if caller_id is null then
    raise exception 'create_song requires an authenticated user'
      using errcode = '42501';
  end if;

  if create_song.name is null or length(trim(create_song.name)) = 0 then
    raise exception 'song name is required'
      using errcode = '22023';
  end if;

  if create_song.storage_path is null
    or create_song.storage_path not like caller_id::text || '/%'
    or length(create_song.storage_path) <= length(caller_id::text) + 1 then
    raise exception 'storage_path must be under the authenticated user folder'
      using errcode = '42501';
  end if;

  if create_song.radius_m is null or create_song.radius_m <= 0 then
    raise exception 'radius_m must be greater than 0'
      using errcode = '22023';
  end if;

  select coalesce(nullif(app_users.full_name, ''), app_users.email, 'Unknown artist')
  into artist_name
  from public.app_users
  where app_users.id = caller_id;

  insert into public.song (
    name,
    storage_path,
    uploaded_by,
    location,
    radius_m,
    expires_at,
    misc,
    user_id
  )
  values (
    trim(create_song.name),
    create_song.storage_path,
    coalesce(artist_name, 'Unknown artist'),
    extensions.st_setsrid(
      extensions.st_makepoint(create_song.lng, create_song.lat),
      4326
    )::extensions.geography,
    create_song.radius_m,
    create_song.expires_at,
    create_song.misc,
    caller_id
  )
  returning id into inserted_song_id;

  return inserted_song_id;
end;
$$;

revoke all on function public.create_song(
  text,
  text,
  double precision,
  double precision,
  integer,
  timestamptz,
  jsonb
) from public;

grant execute on function public.create_song(
  text,
  text,
  double precision,
  double precision,
  integer,
  timestamptz,
  jsonb
) to authenticated;
