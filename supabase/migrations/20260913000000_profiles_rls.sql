-- Güvenlik denetimi H-8 (2026-09-13): `profiles` satır güvenliği.
--
-- Neden: Supabase anon anahtarı istemci paketinde (kasıtlı olarak açık); tabloyu
-- koruyan TEK şey RLS. Politikalar depoda hiç yoktu — docs/db/profiles_onboarding.sql
-- içinde "projede yoksa açın" diye yorum satırıydı. Tablo yaş, boy, kilo,
-- alerji ve hedef tutuyor (sağlık verisi).
--
-- İki ek tuzak kapatılıyor:
--   1. Supabase'in kullanıcı yönetimi başlangıç şablonu `profiles` için
--      "Public profiles are viewable by everyone" (using true) politikası
--      oluşturur. PERMISSIVE politikalar OR'lanır: öyle bir politika tabloda
--      kaldığı sürece aşağıdaki sahiplik politikalarının hiçbir anlamı yoktur.
--      Bu yüzden MEVCUT TÜM politikalar kaldırılıp yalnız tanımlı olanlar kurulur.
--   2. Supabase public şemadaki tablolara anon ve authenticated rollerine
--      varsayılan olarak ALL (TRUNCATE dahil) verir. TRUNCATE RLS'e tabi
--      DEĞİLDİR. Yetkiler önce tamamen geri alınır, sonra yalnız gereken verilir.
--
-- İdempotent: tekrar çalıştırılabilir. Yeni kısıtlar NOT VALID eklenir, yani
-- mevcut satırlarda kural dışı veri varsa migration düşmez; yalnız yeni
-- yazmalar denetlenir.
--
-- Uygulama sırası (bkz. docs/tr/GUVENLIK.md → Manuel konsol listesi):
--   yerel:   supabase db reset && supabase test db
--   staging: supabase db push --linked   (staging projesine bağlıyken)
--   prod:    ancak staging doğrulandıktan sonra

begin;

-- Yerel/boş bir yığında tablo yoksa kur (prod'da zaten var, dokunmaz).
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text,
  updated_at timestamptz
);

-- Uygulamanın okuduğu/yazdığı kolonlar (ADR-0003). profiles_onboarding.sql ile aynı.
alter table public.profiles
  add column if not exists name             text,
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

alter table public.profiles enable row level security;

-- Tablodaki bütün mevcut politikaları kaldır (bkz. tuzak 1).
do $$
declare
  p record;
begin
  for p in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
  loop
    execute format('drop policy %I on public.profiles', p.policyname);
  end loop;
end
$$;

-- Yalnız kendi satırın. `(select auth.uid())` satır başına değil sorgu başına
-- bir kez değerlendirilir (Supabase performans önerisi).
create policy profiles_select_own on public.profiles
  for select to authenticated
  using ((select auth.uid()) = id);

create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check ((select auth.uid()) = id);

-- `with check` şart: yalnız `using` olsaydı kullanıcı kendi satırının id'sini
-- başkasının uid'ine çevirebilirdi.
create policy profiles_update_own on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- DELETE politikası bilerek YOK: istemci profil silmez. Hesap silme
-- deleteAccount fonksiyonunda service_role ile yapılır (RLS'i atlar).

-- Yetkiler (bkz. tuzak 2).
revoke all on table public.profiles from public;
revoke all on table public.profiles from anon;
revoke all on table public.profiles from authenticated;
grant select, insert, update on table public.profiles to authenticated;
grant all on table public.profiles to service_role;

-- Alan sınırları: bozuk/aşırı büyük veri hem arayüzü hem AI bağlamını bozar.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_field_bounds'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles add constraint profiles_field_bounds check (
      (name is null or char_length(name) <= 100)
      and (activity_level is null or char_length(activity_level) <= 40)
      and (diet is null or char_length(diet) <= 40)
      and (age is null or age between 0 and 130)
      and (height is null or height between 0 and 300)
      and (weight is null or weight between 0 and 700)
      and coalesce(array_length(goals, 1), 0) <= 50
      and coalesce(array_length(allergies, 1), 0) <= 50
    ) not valid;
  end if;
end
$$;

-- Supabase kullanıcısı silinince profil de gitsin. Mevcut bir yabancı anahtar
-- varsa DOKUNULMAZ (ON DELETE davranışı manuel doğrulanmalı); deleteAccount
-- profili zaten açıkça siliyor.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and contype = 'f'
      and confrelid = 'auth.users'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_id_auth_users_fkey
      foreign key (id) references auth.users (id) on delete cascade not valid;
  end if;
end
$$;

commit;
