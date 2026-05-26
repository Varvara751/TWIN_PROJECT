create unique index if not exists profil_email_unique_idx
on public.profil (lower(email))
where email is not null;
