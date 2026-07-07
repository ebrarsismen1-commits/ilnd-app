-- ADR-0003: profiles tablosuna onboarding + profil alanları.
-- Supabase SQL Editor'de bir kez çalıştırılır. Idempotent (if not exists).
--
-- RLS: satır-bazlı mevcut politikalar (kullanıcı kendi id'sini okur/yazar) yeni
-- kolonları da kapsar; ek politika gerekmez. Politikalar yoksa aşağıdaki blok
-- açar (yorumlu — projede zaten varsa tekrar açmayın).

alter table public.profiles
  add column if not exists onboarding_done  boolean not null default false,
  add column if not exists first_entry_done boolean not null default false,
  add column if not exists goals            text[]  not null default '{}',
  add column if not exists activity_level   text,
  add column if not exists diet             text,
  add column if not exists allergies        text[]  not null default '{}',
  add column if not exists age              integer,
  add column if not exists height           integer,
  add column if not exists weight           integer,
  add column if not exists updated_at       timestamptz;

-- İsteğe bağlı — RLS politikaları henüz yoksa:
-- alter table public.profiles enable row level security;
-- create policy "profiles_select_own" on public.profiles
--   for select using (auth.uid() = id);
-- create policy "profiles_upsert_own" on public.profiles
--   for insert with check (auth.uid() = id);
-- create policy "profiles_update_own" on public.profiles
--   for update using (auth.uid() = id);
