-- Captures the current remote auth/user ownership schema.

create table if not exists public.app_users (
  id uuid not null,
  email text,
  full_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint app_users_pkey primary key (id),
  constraint app_users_id_fkey foreign key (id)
    references auth.users(id) on delete cascade
);

alter table public.app_users owner to postgres;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.app_users (
    id,
    email,
    full_name
  )
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name'
  )
  on conflict (id) do update
  set
    email = excluded.email,
    full_name = excluded.full_name,
    updated_at = now();

  return new;
end;
$$;

alter function public.handle_new_auth_user() owner to postgres;

create or replace function public.handle_updated_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.app_users
  set
    email = new.email,
    full_name = new.raw_user_meta_data ->> 'full_name',
    updated_at = now()
  where id = new.id;

  return new;
end;
$$;

alter function public.handle_updated_auth_user() owner to postgres;

create or replace trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_auth_user();

create or replace trigger on_auth_user_updated
after update on auth.users
for each row
execute function public.handle_updated_auth_user();

alter table public.song
  alter column uploaded_by set not null,
  alter column location drop not null,
  alter column radius_m drop not null,
  alter column radius_m drop default;

alter table public.song
  add column if not exists user_id uuid;

alter table only public.song
  add constraint song_user_id_fkey foreign key (user_id)
    references public.app_users(id) on delete cascade;

comment on table public.song is 'The table that holds all the songs!';

alter table public.song enable row level security;

grant all on function public.handle_new_auth_user() to anon;
grant all on function public.handle_new_auth_user() to authenticated;
grant all on function public.handle_new_auth_user() to service_role;

grant all on function public.handle_updated_auth_user() to anon;
grant all on function public.handle_updated_auth_user() to authenticated;
grant all on function public.handle_updated_auth_user() to service_role;

grant all on table public.app_users to anon;
grant all on table public.app_users to authenticated;
grant all on table public.app_users to service_role;
