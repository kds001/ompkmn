-- OMP / idPKMN schema for Supabase PostgreSQL
-- Run with Supabase SQL editor or migrations.

create extension if not exists pgcrypto;

-- Regions/States integrated in OMP
create table if not exists public.omp_regions (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  iso_code text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Core trainer profile linked to auth.users
create table if not exists public.trainer_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  idpkmn_code text not null unique,
  display_name text not null,
  username text not null unique,
  bio text,
  home_region_id uuid references public.omp_regions(id),
  country text,
  city text,
  avatar_url text,
  visibility text not null default 'public' check (visibility in ('public', 'private')),
  is_pisa_accredited boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_trainer_profiles_region on public.trainer_profiles(home_region_id);

-- Official events (national, mundial, interregional)
create table if not exists public.official_events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  event_type text not null check (event_type in ('serie_mundial_coronacion', 'campeonato_nacional', 'interregional', 'investigacion', 'cultural')),
  region_id uuid references public.omp_regions(id),
  host_country text,
  host_city text,
  starts_at timestamptz,
  ends_at timestamptz,
  is_omp_recognized boolean not null default true,
  created_at timestamptz not null default now()
);

-- Achievements shown in instagram-like profile
create table if not exists public.trainer_achievements (
  id uuid primary key default gen_random_uuid(),
  trainer_id uuid not null references public.trainer_profiles(id) on delete cascade,
  event_id uuid references public.official_events(id) on delete set null,
  title text not null,
  description text,
  achievement_type text not null check (achievement_type in ('titulo', 'medalla', 'ranking', 'record', 'acreditacion')),
  placement integer,
  media_url text,
  achieved_at timestamptz,
  is_highlighted boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_achievements_trainer on public.trainer_achievements(trainer_id);
create index if not exists idx_achievements_event on public.trainer_achievements(event_id);

-- PISA eligibility and mobility status
create table if not exists public.pisa_authorizations (
  id uuid primary key default gen_random_uuid(),
  trainer_id uuid not null references public.trainer_profiles(id) on delete cascade,
  status text not null check (status in ('pending', 'active', 'suspended', 'expired')),
  priority_group text not null check (priority_group in ('entrenador_idpkmn', 'investigador', 'desarrollador_tecnologico', 'evento_oficial')),
  valid_from date not null,
  valid_until date,
  notes text,
  created_at timestamptz not null default now(),
  unique (trainer_id, priority_group)
);

-- optional content feed for profile posts
create table if not exists public.trainer_posts (
  id uuid primary key default gen_random_uuid(),
  trainer_id uuid not null references public.trainer_profiles(id) on delete cascade,
  caption text,
  media_url text not null,
  event_id uuid references public.official_events(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_posts_trainer_created on public.trainer_posts(trainer_id, created_at desc);

-- audit timestamp helper
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_trainer_profiles_updated on public.trainer_profiles;
create trigger trg_trainer_profiles_updated
before update on public.trainer_profiles
for each row execute procedure public.set_updated_at();

-- RLS
alter table public.trainer_profiles enable row level security;
alter table public.trainer_achievements enable row level security;
alter table public.trainer_posts enable row level security;
alter table public.pisa_authorizations enable row level security;

-- Public read for public profiles/achievements/posts
create policy "Public profiles are readable"
on public.trainer_profiles
for select
using (visibility = 'public');

create policy "Public achievements are readable"
on public.trainer_achievements
for select
using (
  exists (
    select 1 from public.trainer_profiles p
    where p.id = trainer_achievements.trainer_id and p.visibility = 'public'
  )
);

create policy "Public posts are readable"
on public.trainer_posts
for select
using (
  exists (
    select 1 from public.trainer_profiles p
    where p.id = trainer_posts.trainer_id and p.visibility = 'public'
  )
);

-- Authenticated trainers can manage own data
create policy "Owner can manage own profile"
on public.trainer_profiles
for all
using (auth.uid() = id)
with check (auth.uid() = id);

create policy "Owner can manage own achievements"
on public.trainer_achievements
for all
using (auth.uid() = trainer_id)
with check (auth.uid() = trainer_id);

create policy "Owner can manage own posts"
on public.trainer_posts
for all
using (auth.uid() = trainer_id)
with check (auth.uid() = trainer_id);

create policy "Owner can read own PISA status"
on public.pisa_authorizations
for select
using (auth.uid() = trainer_id);

-- Seed regions requested by OMP
insert into public.omp_regions (name, iso_code)
values
  ('Johto', 'JOH'),
  ('Hoemn', 'HOE'),
  ('Sinnoh', 'SIN'),
  ('Teselia', 'TES'),
  ('Kalos', 'KAL'),
  ('Alola', 'ALO'),
  ('Galar', 'GAL'),
  ('Paldea', 'PAL'),
  ('Gaia', 'GAI'),
  ('España', 'ESP')
on conflict (name) do nothing;
