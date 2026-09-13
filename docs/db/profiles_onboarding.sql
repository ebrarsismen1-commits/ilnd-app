-- ESKİ — yerine: supabase/migrations/20260913000000_profiles_rls.sql
--
-- Bu dosya yalnız tarihçe için duruyor. Aşağıdaki "isteğe bağlı" RLS bloğu
-- güvenlik denetiminde (H-8, 2026-09-13) yetersiz bulundu: politikalar
-- depoda hiç tanımlı değildi, update politikasında `with check` yoktu (satırın
-- id'si başkasına çevrilebilir) ve Supabase'in varsayılan TRUNCATE yetkisi ile
-- başlangıç şablonunun "herkese açık" politikası hesaba katılmamıştı.
-- Kolonlar ve doğru politikalar migration dosyasında; bunu çalıştırmayın.
--
-- ADR-0003: profiles tablosuna onboarding + profil alanları.

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
