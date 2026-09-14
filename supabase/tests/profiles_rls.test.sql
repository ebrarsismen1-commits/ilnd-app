-- pgTAP: public.profiles satır güvenliği, kullanıcı A ve kullanıcı B.
-- Güvenlik denetimi H-8 (2026-09-13).
--
-- YALNIZ YEREL Supabase yığınında çalışır: `supabase start && supabase test db`.
-- Her şey tek bir transaction içinde ve sonunda ROLLBACK: hiçbir veri kalmaz.
-- Asla prod veritabanına karşı çalıştırılmaz.

begin;

create extension if not exists pgtap with schema extensions;

select plan(14);

-- Kurulum (postgres rolüyle, RLS dışı).
insert into auth.users (id, email, aud, role)
values
  ('11111111-1111-1111-1111-111111111111', 'a@example.test', 'authenticated', 'authenticated'),
  ('22222222-2222-2222-2222-222222222222', 'b@example.test', 'authenticated', 'authenticated');

insert into public.profiles (id, name, weight, allergies)
values
  ('11111111-1111-1111-1111-111111111111', 'A', 70, '{gluten}'),
  ('22222222-2222-2222-2222-222222222222', 'B', 80, '{}');

select is(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  true,
  'RLS açık'
);

select is(
  (select count(*)::int from pg_policies
   where schemaname = 'public' and tablename = 'profiles' and qual = 'true'),
  0,
  'herkese açık (using true) politika yok'
);

-- ── Kullanıcı A olarak ────────────────────────────────────────────────────────
set local role authenticated;
set local request.jwt.claims to
  '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

select is(
  (select count(*)::int from public.profiles),
  1,
  'A yalnız kendi satırını görür'
);

select is(
  (select name from public.profiles where id = '22222222-2222-2222-2222-222222222222'),
  null,
  'A, B''nin satırını okuyamaz'
);

select is(
  (with t as (
     update public.profiles set weight = 1
     where id = '22222222-2222-2222-2222-222222222222'
     returning 1)
   select count(*)::int from t),
  0,
  'A, B''nin satırını güncelleyemez'
);

select throws_ok(
  $$ update public.profiles set id = '22222222-2222-2222-2222-222222222222'
     where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501',
  null,
  'A kendi satırının sahibini B''ye çeviremez (with check)'
);

select throws_ok(
  $$ insert into public.profiles (id, name)
     values ('33333333-3333-3333-3333-333333333333', 'sahte') $$,
  '42501',
  null,
  'A başka bir id ile satır ekleyemez'
);

select lives_ok(
  $$ update public.profiles set weight = 71
     where id = '11111111-1111-1111-1111-111111111111' $$,
  'A kendi satırını günceller'
);

select is(
  (with t as (
     delete from public.profiles
     where id = '22222222-2222-2222-2222-222222222222'
     returning 1)
   select count(*)::int from t),
  0,
  'A, B''nin satırını silemez'
);

select throws_ok(
  $$ truncate public.profiles $$,
  '42501',
  null,
  'authenticated rolü TRUNCATE yapamaz (RLS TRUNCATE''a uygulanmaz)'
);

select throws_ok(
  $$ update public.profiles set weight = 5000
     where id = '11111111-1111-1111-1111-111111111111' $$,
  '23514',
  null,
  'alan sınırları uygulanır'
);

-- ── Kimliksiz (anon) ──────────────────────────────────────────────────────────
reset role;
set local role anon;
set local request.jwt.claims to '{"role": "anon"}';

select throws_ok(
  $$ select * from public.profiles $$,
  '42501',
  null,
  'anon profilleri okuyamaz'
);

-- ── Hesap silme ──────────────────────────────────────────────────────────────
reset role;

select is(
  (select count(*)::int from public.profiles
   where id = '22222222-2222-2222-2222-222222222222'),
  1,
  'B''nin satırı A''nın denemelerinden sonra yerinde'
);

delete from auth.users where id = '22222222-2222-2222-2222-222222222222';

select is(
  (select count(*)::int from public.profiles
   where id = '22222222-2222-2222-2222-222222222222'),
  0,
  'Supabase kullanıcısı silinince profil de silinir (on delete cascade)'
);

select * from finish();

rollback;
