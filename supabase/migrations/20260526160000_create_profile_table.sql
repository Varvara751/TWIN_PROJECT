create table if not exists public.profil (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  username text,
  name text,
  surname text,
  avatar_url text,
  birth_date date,
  age int,
  city text,
  country text,
  residence_city text,
  residence_region text,
  residence_country text default 'Россия',
  bio text,
  interests jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

alter table public.profil
alter column residence_country set default 'Россия';
