/**
 * Saf birim testi (emülatör ve Docker gerektirmez): CI'da her koşuda çalışır.
 *
 * Güvenlik denetimi H-8 (2026-09-13). Supabase RLS'in DAVRANIŞ testleri
 * supabase/tests/profiles_rls.test.sql'de (pgTAP, yerel Supabase yığını
 * ister). Bu dosya onların yerine geçmez; migration'ın koruyucu parçalarının
 * sessizce silinmesini ve service_role anahtarının istemciye sızmasını
 * yakalayan bir bekçidir.
 */
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..", "..");
const MIGRATION = path.join(ROOT, "supabase", "migrations", "20260913000000_profiles_rls.sql");

/** SQL yorum satırlarını atar, boşlukları tekler, küçük harfe çevirir. */
function normalizedSql(file) {
  return fs.readFileSync(file, "utf8")
      .split("\n")
      .map((line) => line.replace(/--.*$/, ""))
      .join(" ")
      .replace(/\s+/g, " ")
      .toLowerCase();
}

describe("profiles RLS migration", () => {
  const sql = normalizedSql(MIGRATION);

  test("RLS açılır", () => {
    expect(sql).toContain("alter table public.profiles enable row level security");
  });

  test("mevcut tüm politikalar kaldırılır (şablonun 'herkese açık' politikası kalmasın)", () => {
    expect(sql).toMatch(/for p in select policyname from pg_policies where schemaname = 'public' and tablename = 'profiles'/);
    expect(sql).toContain("drop policy %i on public.profiles");
  });

  test("select/insert/update yalnız sahibine", () => {
    expect(sql).toMatch(/create policy profiles_select_own on public\.profiles for select to authenticated using \(\(select auth\.uid\(\)\) = id\)/);
    expect(sql).toMatch(/create policy profiles_insert_own on public\.profiles for insert to authenticated with check \(\(select auth\.uid\(\)\) = id\)/);
    expect(sql).toMatch(/create policy profiles_update_own on public\.profiles for update to authenticated using \(\(select auth\.uid\(\)\) = id\) with check \(\(select auth\.uid\(\)\) = id\)/);
  });

  test("herkese açık ya da anon'a verilmiş politika yok", () => {
    expect(sql).not.toMatch(/using \(\s*true\s*\)/);
    expect(sql).not.toMatch(/with check \(\s*true\s*\)/);
    expect(sql).not.toMatch(/create policy [^;]* to (anon|public)\b/);
  });

  test("yetkiler önce geri alınır, authenticated'a TRUNCATE/DELETE verilmez", () => {
    const revokeAnon = sql.indexOf("revoke all on table public.profiles from anon");
    const revokeAuth = sql.indexOf("revoke all on table public.profiles from authenticated");
    const grant = sql.indexOf("grant select, insert, update on table public.profiles to authenticated");
    expect(revokeAnon).toBeGreaterThan(-1);
    expect(revokeAuth).toBeGreaterThan(-1);
    expect(grant).toBeGreaterThan(revokeAuth);
    expect(sql).not.toMatch(/grant [^;]*(all|truncate|delete)[^;]* to (anon|authenticated)\b/);
  });

  test("tek transaction içinde", () => {
    expect(sql.trim().startsWith("begin;")).toBe(true);
    expect(sql.trim().endsWith("commit;")).toBe(true);
  });
});

describe("service_role anahtarı istemciye sızmaz", () => {
  /** @return {string[]} klasördeki tüm dosyalar (özyinelemeli) */
  function walk(dir) {
    if (!fs.existsSync(dir)) return [];
    return fs.readdirSync(dir, {withFileTypes: true}).flatMap((e) => {
      const p = path.join(dir, e.name);
      return e.isDirectory() ? walk(p) : [p];
    });
  }

  test("lib/ ve web/ içinde service_role / SUPABASE_SERVICE_ROLE_KEY geçmez", () => {
    const offenders = [...walk(path.join(ROOT, "lib")), ...walk(path.join(ROOT, "web"))]
        .filter((f) => /\.(dart|js|html|json)$/.test(f))
        .filter((f) => /service_role|SUPABASE_SERVICE_ROLE_KEY/i.test(fs.readFileSync(f, "utf8")));
    expect(offenders).toEqual([]);
  });

  test("istemci .env şablonunda service_role anahtarı yok", () => {
    const example = fs.readFileSync(path.join(ROOT, ".env.example"), "utf8");
    expect(example).not.toMatch(/SERVICE_ROLE/i);
  });
});
