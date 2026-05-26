alter table public.profil
add column if not exists birth_date date,
add column if not exists residence_city text,
add column if not exists residence_region text,
add column if not exists residence_country text default 'Россия';

create table if not exists public.profile_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profil(id) on delete cascade,
  image_url text not null,
  storage_path text not null,
  created_at timestamptz not null default now()
);

create index if not exists profile_photos_user_id_created_at_idx
on public.profile_photos(user_id, created_at desc);

create table if not exists public.profile_follows (
  follower_id uuid not null references public.profil(id) on delete cascade,
  following_id uuid not null references public.profil(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint profile_follows_no_self_follow check (follower_id <> following_id)
);

create index if not exists profile_follows_following_id_idx
on public.profile_follows(following_id);

create table if not exists public.profile_likes (
  id uuid primary key default gen_random_uuid(),
  target_user_id uuid not null references public.profil(id) on delete cascade,
  source_user_id uuid not null references public.profil(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (target_user_id, source_user_id),
  constraint profile_likes_no_self_like check (target_user_id <> source_user_id)
);

create index if not exists profile_likes_target_user_id_idx
on public.profile_likes(target_user_id);
