alter table public.profil
add column if not exists username text,
add column if not exists birth_date date,
add column if not exists residence_city text,
add column if not exists residence_region text,
add column if not exists residence_country text default 'Россия';

alter table public.profil
alter column residence_country set default 'Россия';

update public.profil
set residence_country = 'Россия'
where residence_country is null
   or residence_country = ''
   or residence_country = 'Р РѕСЃСЃРёСЏ';

update public.profil
set username = lower(
  regexp_replace(
    coalesce(nullif(username, ''), nullif(name, ''), 'user')
      || '_'
      || left(id::text, 8),
    '[^a-zA-Z0-9_]',
    '_',
    'g'
  )
)
where username is null or username = '';

alter table public.profil
alter column username set not null;

create unique index if not exists profil_username_unique_idx
on public.profil (lower(username));

create index if not exists profil_username_search_idx
on public.profil (lower(username));

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;
