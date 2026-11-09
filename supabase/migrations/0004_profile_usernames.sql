-- Google profile onboarding: usernames are unique and normalized.
alter table public.profiles add column if not exists username text;
alter table public.profiles
  add constraint profiles_username_format
  check (username is null or username ~ '^[a-z0-9_]{3,20}$');
create unique index if not exists profiles_username_unique
  on public.profiles (lower(username))
  where username is not null;
grant update (username) on public.profiles to authenticated;
