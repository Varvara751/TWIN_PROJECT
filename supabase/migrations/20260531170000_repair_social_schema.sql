alter table public.profil
add column if not exists username text;

with normalized as (
  select
    id,
    lower(
      regexp_replace(
        coalesce(nullif(username, ''), nullif(name, ''), 'user'),
        '[^a-zA-Z0-9_]',
        '_',
        'g'
      )
    ) as base
  from public.profil
),
ranked as (
  select
    id,
    case
      when length(btrim(base, '_')) < 3 then 'user_' || left(id::text, 8)
      else left(btrim(base, '_'), 24)
    end as base,
    row_number() over (
      partition by case
        when length(btrim(base, '_')) < 3 then 'user_' || left(id::text, 8)
        else left(btrim(base, '_'), 24)
      end
      order by id
    ) as duplicate_index
  from normalized
)
update public.profil p
set username = case
  when ranked.duplicate_index = 1 then ranked.base
  else left(ranked.base, greatest(3, 15)) || '_' || left(p.id::text, 8)
end
from ranked
where p.id = ranked.id
  and (
    p.username is null
    or p.username = ''
    or p.username !~ '^[a-z0-9_]{3,24}$'
    or ranked.duplicate_index > 1
  );

alter table public.profil
alter column username set not null;

drop index if exists public.profil_username_unique_idx;
create unique index if not exists profil_username_unique_idx
on public.profil (lower(username));

create index if not exists profil_username_search_idx
on public.profil (lower(username));

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

create table if not exists public.profile_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profil(id) on delete cascade,
  image_url text not null,
  storage_path text not null,
  created_at timestamptz not null default now()
);

create index if not exists profile_photos_user_id_created_at_idx
on public.profile_photos(user_id, created_at desc);

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
  unique (user_low, user_high)
);

alter table public.chats
drop constraint if exists chats_two_users_check;

create index if not exists chats_user_low_idx on public.chats(user_low);
create index if not exists chats_user_high_idx on public.chats(user_high);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats(id) on delete cascade,
  sender_id uuid not null references public.profil(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  edited_at timestamptz
);

alter table public.messages
add column if not exists edited_at timestamptz;

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
  primary key (blocker_id, blocked_id)
);

alter table public.chat_blocks
drop constraint if exists chat_blocks_no_self_block;

alter table public.chat_blocks
add constraint chat_blocks_no_self_block check (blocker_id <> blocked_id);

create index if not exists chat_blocks_blocked_id_idx
on public.chat_blocks(blocked_id);
