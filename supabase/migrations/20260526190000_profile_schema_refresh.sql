alter table public.profil
add column if not exists birth_date date,
add column if not exists residence_city text,
add column if not exists residence_region text,
add column if not exists residence_country text default 'Россия';

alter table public.profil
alter column residence_country set default 'Россия';
