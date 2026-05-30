alter table public.profil
add column if not exists username text;

update public.profil
set username = lower(regexp_replace(coalesce(nullif(name, ''), 'user') || '_' || left(id::text, 8), '[^a-zA-Z0-9_]', '_', 'g'))
where username is null or username = '';

alter table public.profil
alter column username set not null;

create unique index if not exists profil_username_unique_idx
on public.profil (lower(username));

create index if not exists profil_username_search_idx
on public.profil (lower(username));

create table if not exists public.profile_photo_likes (
  photo_id uuid not null references public.profile_photos(id) on delete cascade,
  source_user_id uuid not null references public.profil(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (photo_id, source_user_id)
);

create index if not exists profile_photo_likes_source_user_id_idx
on public.profile_photo_likes(source_user_id);

create table if not exists public.chats (
  id uuid primary key default gen_random_uuid(),
  user_low uuid not null references public.profil(id) on delete cascade,
  user_high uuid not null references public.profil(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chats_two_users_check check (user_low <> user_high),
  unique (user_low, user_high)
);

create index if not exists chats_user_low_idx on public.chats(user_low);
create index if not exists chats_user_high_idx on public.chats(user_high);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats(id) on delete cascade,
  sender_id uuid not null references public.profil(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists messages_chat_id_created_at_idx
on public.messages(chat_id, created_at desc);

create table if not exists public.message_deletions (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.profil(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create table if not exists public.chat_deletions (
  chat_id uuid not null references public.chats(id) on delete cascade,
  user_id uuid not null references public.profil(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (chat_id, user_id)
);

create table if not exists public.chat_blocks (
  blocker_id uuid not null references public.profil(id) on delete cascade,
  blocked_id uuid not null references public.profil(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint chat_blocks_no_self_block check (blocker_id <> blocked_id)
);

create index if not exists chat_blocks_blocked_id_idx
on public.chat_blocks(blocked_id);
