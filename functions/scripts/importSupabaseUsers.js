#!/usr/bin/env node
/**
 * Tek seferlik: Supabase Auth kullanıcılarını Firebase Auth'a AYNI uid ile
 * taşır (ADR-0010). Şifre taşınmaz; kullanıcı ilk girişte şifresini sıfırlar.
 *
 * VARSAYILAN KURU ÇALIŞMA: hiçbir şey yazılmaz, yalnız özet ve listeler.
 * Yazmak için `--apply`; prod'da ayrıca `--confirm-prod` (scripts/lib/target.js).
 *
 * Sıra: bu script → migrateSupabaseProfiles.js (profil, kullanıcıyı Firebase
 * Auth'ta arar) → yeni uygulama sürümü.
 *
 * Kaynak (biri):
 *   --input=<dosya.json>  kullanıcı dizisi (SQL: select id, email,
 *                         email_confirmed_at, raw_user_meta_data,
 *                         raw_app_meta_data, is_anonymous from auth.users)
 *   SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY → GoTrue admin API
 *                         (anahtar yalnız ortamdan okunur, loglanmaz)
 *
 * Firebase kimliği: Application Default Credentials. Depoya kimlik dosyası
 * KOYMAYIN.
 *
 * Güvenlik:
 *   - Mevcut Firebase kullanıcısı silinmez/yeniden yaratılmaz; e-postasız
 *     (köprü) kaydına yalnız e-posta eklenir.
 *   - E-posta Firebase'te başka uid'deyse, uid'de başka e-posta varsa,
 *     kaynakta çift kayıt, anonim, e-postasız ya da Google/Apple kimliği
 *     varsa DOKUNULMAZ, listelenir.
 *   - Çıktıda e-posta yok; yalnız uid ve sayı.
 *
 * Kullanım:
 *   node scripts/importSupabaseUsers.js --project=<id> [--apply] [--report=r.json]
 *   node scripts/importSupabaseUsers.js --project=ilnd-app-8dcbd --apply --confirm-prod
 */
const fs = require("fs");
const admin = require("firebase-admin");
const {resolveTarget, describeTarget, readFlag} = require("./lib/target");
const {normalizeSupabaseUser, planUserImport, summarizeUserImport} = require("./lib/userImport");

const PER_PAGE = 1000;

/**
 * GoTrue admin API'den tüm kullanıcıları sayfa sayfa okur.
 * @param {object} p girdiler
 * @param {string} p.url Supabase proje URL'i
 * @param {string} p.key service_role anahtarı
 * @param {Function} [p.fetchImpl] test için
 * @return {Promise<object[]>} ham kullanıcılar
 */
async function fetchSupabaseUsers({url, key, fetchImpl = fetch}) {
  const users = [];
  for (let page = 1; ; page++) {
    const res = await fetchImpl(
        `${url.replace(/\/$/, "")}/auth/v1/admin/users?page=${page}&per_page=${PER_PAGE}`,
        {headers: {apikey: key, Authorization: `Bearer ${key}`}},
    );
    if (!res.ok) throw new Error(`Supabase users read failed: HTTP ${res.status}`);
    const body = await res.json();
    const batch = body && Array.isArray(body.users) ? body.users : null;
    if (!batch) throw new Error("Supabase users read: unexpected response shape");
    users.push(...batch);
    if (batch.length < PER_PAGE) return users;
  }
}

/**
 * @param {string[]} argv argümanlar
 * @param {object} env ortam
 * @return {Promise<object[]>} ham kullanıcılar
 */
async function loadUsers(argv, env) {
  const input = readFlag(argv, "input");
  if (input) {
    const rows = JSON.parse(fs.readFileSync(input, "utf8"));
    if (!Array.isArray(rows)) throw new Error("--input must be a JSON array of auth.users rows");
    return rows;
  }
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error("No source: pass --input=<file.json> or set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY");
  }
  return fetchSupabaseUsers({url: env.SUPABASE_URL, key: env.SUPABASE_SERVICE_ROLE_KEY});
}

/**
 * @template T
 * @param {T[]} arr dizi
 * @param {number} n parça boyu
 * @return {T[][]} parçalar
 */
function chunk(arr, n) {
  const out = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
}

/**
 * @param {admin.auth.Auth} auth Admin Auth
 * @param {object[]} users normalize kullanıcılar
 * @return {Promise<{firebaseByUid: Map, firebaseUidByEmail: Map}>} Firebase durumu
 */
async function firebaseState(auth, users) {
  const firebaseByUid = new Map();
  const firebaseUidByEmail = new Map();
  const uids = [...new Set(users.map((u) => u.id).filter((id) => typeof id === "string"))];
  const emails = [...new Set(users.map((u) => u.email).filter(Boolean))];
  for (const part of chunk(uids, 100)) {
    const res = await auth.getUsers(part.map((uid) => ({uid})));
    res.users.forEach((u) => firebaseByUid.set(u.uid, {email: u.email}));
  }
  for (const part of chunk(emails, 100)) {
    const res = await auth.getUsers(part.map((email) => ({email})));
    res.users.forEach((u) => u.email && firebaseUidByEmail.set(u.email.toLowerCase(), u.uid));
  }
  return {firebaseByUid, firebaseUidByEmail};
}

/**
 * @param {string[]} [argv] argümanlar
 * @param {object} [env] ortam
 * @return {Promise<object>} özet
 */
async function main(argv = process.argv.slice(2), env = process.env) {
  const apply = argv.includes("--apply");
  const target = resolveTarget({argv, env, writes: apply});
  console.log(describeTarget(target));
  console.log(apply ? "Mode: APPLY (writes enabled)" : "Mode: DRY RUN (nothing will be written; pass --apply to write)");

  const users = (await loadUsers(argv, env)).map(normalizeSupabaseUser);
  if (!admin.apps.length) admin.initializeApp({projectId: target.projectId});
  const auth = admin.auth();
  const plan = planUserImport({users, ...(await firebaseState(auth, users))});

  const created = [];
  const updated = [];
  const failed = [];
  if (apply) {
    for (const {uid, attrs} of plan.create) {
      try {
        await auth.createUser({uid, ...attrs});
        created.push(uid);
      } catch (err) {
        failed.push({uid, error: String(err.code || err.message || err)});
      }
    }
    for (const {uid, attrs} of plan.addEmail) {
      try {
        await auth.updateUser(uid, attrs);
        updated.push(uid);
      } catch (err) {
        failed.push({uid, error: String(err.code || err.message || err)});
      }
    }
  }

  const summary = summarizeUserImport({users, plan, apply, created, updated, failed});
  const {lists, ...counts} = summary;
  console.log(JSON.stringify(counts, null, 2));
  const report = readFlag(argv, "report");
  if (report) {
    fs.writeFileSync(report, JSON.stringify(summary, null, 2));
    console.log(`Full report (uids only) written to ${report}`);
  } else {
    console.log(JSON.stringify({lists}, null, 2));
  }
  if (summary.failed > 0) process.exitCode = 1;
  return summary;
}

if (require.main === module) {
  main().catch((err) => {
    console.error("importSupabaseUsers failed:", err.message || err);
    process.exitCode = 1;
  });
}

module.exports = {main, fetchSupabaseUsers};
