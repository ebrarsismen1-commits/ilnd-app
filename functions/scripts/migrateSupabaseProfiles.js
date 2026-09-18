#!/usr/bin/env node
/**
 * Tek seferlik: Supabase `profiles` satırlarını Firestore `users/{uid}`
 * dokümanlarına taşır (merge; mevcut alanlar silinmez, fotoğraf korunur).
 *
 * VARSAYILAN KURU ÇALIŞMA: hiçbir şey yazılmaz, yalnız özet ve listeler.
 * Yazmak için `--apply`; prod'da ayrıca `--confirm-prod` (scripts/lib/target.js).
 *
 * Kaynak (biri):
 *   --input=<dosya.json>   profiles satırları JSON dizisi (SQL editöründen
 *                          dışa aktarım ya da PostgREST yanıtı)
 *   SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY ortam değişkenleri → PostgREST
 *                          (RLS'i atlamak için service_role gerekir; anahtar
 *                          yalnız ortamdan okunur, hiçbir yere yazılmaz/loglanmaz)
 *
 * Firebase kimliği: Application Default Credentials
 * (`gcloud auth application-default login`). Depoya kimlik dosyası KOYMAYIN.
 *
 * Kurallar (bkz. scripts/lib/profileMigration.js):
 *   - profiles.id === Firebase uid (köprü aynı uid'i kullanıyor). Firebase
 *     Auth'ta olmayan uid yazılmaz → missingUsers.
 *   - users/{uid}.profileUpdatedAt varsa istemci profili zaten Firestore'a
 *     yazmış demektir; Supabase'teki eskidir → atlanır. Kontrol yazımla aynı
 *     transaction'da yapılır (arada uygulama yazarsa ezilmez).
 *   - Yazılan dokümana profileMigratedAt / profileMigratedFrom eklenir;
 *     profileUpdatedAt KONMAZ, yani tekrar çalıştırmak (eski uygulama
 *     sürümlerinin Supabase'e yazdıklarını almak için) güvenlidir.
 *   - Supabase `updated_at` taşınmaz: uygulama onu yalnız kayıtta yazıyordu.
 *
 * Kullanım:
 *   FIRESTORE_EMULATOR_HOST=… FIREBASE_AUTH_EMULATOR_HOST=… \
 *     node scripts/migrateSupabaseProfiles.js --input=profiles.json [--apply]
 *   node scripts/migrateSupabaseProfiles.js --project=ilnd-staging-2026 [--apply]
 *   node scripts/migrateSupabaseProfiles.js --project=ilnd-app-8dcbd \
 *     [--apply --confirm-prod] [--report=rapor.json]
 *
 * Çıkış kodu: 0 başarı, 1 kaynak okunamadı / hedef reddedildi / en az bir
 * yazım başarısız.
 */
const fs = require("fs");
const admin = require("firebase-admin");
const {resolveTarget, describeTarget, readFlag} = require("./lib/target");
const {planMigration, summarize, CLIENT_STAMP} = require("./lib/profileMigration");

const COLUMNS = [
  "id", "name", "onboarding_done", "first_entry_done", "goals",
  "activity_level", "diet", "allergies", "age", "height", "weight",
].join(",");
const PAGE = 1000;

/**
 * Yönetici isteği başlıkları. Legacy service_role anahtarı bir JWT'dir ve
 * Authorization'da da gönderilir. Yeni `sb_secret_…` anahtarı JWT DEĞİLDİR:
 * Authorization: Bearer'da gönderilirse platform onu JWT sanıp 401 döner;
 * yalnız `apikey` başlığında gider.
 * @param {string} key service_role ya da sb_secret anahtarı
 * @return {Object<string, string>} başlıklar
 */
function supabaseAdminHeaders(key) {
  const k = String(key).trim();
  return k.startsWith("eyJ") ? {apikey: k, Authorization: `Bearer ${k}`} : {apikey: k};
}

/**
 * PostgREST'ten tüm satırları sayfa sayfa okur.
 * @param {object} p girdiler
 * @param {string} p.url Supabase proje URL'i
 * @param {string} p.key service_role anahtarı
 * @param {Function} [p.fetchImpl] test için
 * @return {Promise<object[]>} satırlar
 */
async function fetchSupabaseProfiles({url, key, fetchImpl = fetch}) {
  const rows = [];
  for (let offset = 0; ; offset += PAGE) {
    const res = await fetchImpl(
        `${url.replace(/\/$/, "")}/rest/v1/profiles?select=${COLUMNS}&order=id.asc` +
        `&limit=${PAGE}&offset=${offset}`,
        {headers: supabaseAdminHeaders(key)},
    );
    // Yanıt gövdesi loglanmaz: hata mesajı isteği yansıtabilir.
    if (!res.ok) throw new Error(`Supabase profiles read failed: HTTP ${res.status}`);
    const page = await res.json();
    if (!Array.isArray(page)) throw new Error("Supabase profiles read: unexpected response shape");
    rows.push(...page);
    if (page.length < PAGE) return rows;
  }
}

/**
 * @param {string[]} argv argümanlar
 * @param {object} env ortam
 * @return {Promise<object[]>} satırlar
 */
async function loadRows(argv, env) {
  const input = readFlag(argv, "input");
  if (input) {
    const rows = JSON.parse(fs.readFileSync(input, "utf8"));
    if (!Array.isArray(rows)) throw new Error("--input must be a JSON array of profiles rows");
    return rows;
  }
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error("No source: pass --input=<file.json> or set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY");
  }
  return fetchSupabaseProfiles({url: env.SUPABASE_URL, key: env.SUPABASE_SERVICE_ROLE_KEY});
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
 * @param {string[]} uids aday uid'ler
 * @return {Promise<Set<string>>} Firebase Auth'ta var olanlar
 */
async function existingAuthUids(auth, uids) {
  const found = new Set();
  for (const part of chunk(uids, 100)) {
    const res = await auth.getUsers(part.map((uid) => ({uid})));
    res.users.forEach((u) => found.add(u.uid));
  }
  return found;
}

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string[]} uids uid'ler
 * @return {Promise<Map<string, (object|null)>>} mevcut users/{uid} verisi
 */
async function existingDocs(db, uids) {
  const map = new Map();
  for (const part of chunk(uids, 300)) {
    if (!part.length) continue;
    const snaps = await db.getAll(...part.map((uid) => db.collection("users").doc(uid)));
    snaps.forEach((s) => map.set(s.id, s.exists ? s.data() : null));
  }
  return map;
}

/**
 * Planı uygular; her kullanıcı kendi transaction'ında.
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {{uid: string, fields: object}[]} items yazılacaklar
 * @return {Promise<{migrated: string[], raced: string[], failed: object[]}>} sonuç
 */
async function applyPlan(db, items) {
  const migrated = [];
  const raced = [];
  const failed = [];
  for (const part of chunk(items, 10)) {
    await Promise.all(part.map(async ({uid, fields}) => {
      const ref = db.collection("users").doc(uid);
      try {
        const wrote = await db.runTransaction(async (tx) => {
          const snap = await tx.get(ref);
          if (snap.exists && snap.get(CLIENT_STAMP) != null) return false;
          tx.set(ref, {
            ...fields,
            profileMigratedAt: admin.firestore.FieldValue.serverTimestamp(),
            profileMigratedFrom: "supabase",
          }, {merge: true});
          return true;
        });
        (wrote ? migrated : raced).push(uid);
      } catch (err) {
        failed.push({uid, error: String(err.code || err.message || err)});
      }
    }));
  }
  return {migrated, raced, failed};
}

/**
 * @param {string[]} [argv] argümanlar
 * @param {object} [env] ortam
 * @return {Promise<object>} özet
 */
async function main(argv = process.argv.slice(2), env = process.env) {
  const apply = argv.includes("--apply");
  // Kuru çalışma prod onayı istemez (yalnız okur); --apply ister.
  const target = resolveTarget({argv, env, writes: apply});
  console.log(describeTarget(target));
  console.log(apply ? "Mode: APPLY (writes enabled)" : "Mode: DRY RUN (nothing will be written; pass --apply to write)");

  const rows = await loadRows(argv, env);
  if (!admin.apps.length) admin.initializeApp({projectId: target.projectId});
  const db = admin.firestore();

  const ids = [...new Set(rows.map((r) => r && r.id).filter((id) => typeof id === "string"))];
  const authUids = await existingAuthUids(admin.auth(), ids);
  const existing = await existingDocs(db, ids.filter((id) => authUids.has(id)));
  const plan = planMigration({rows, authUids, existing});

  const result = apply ? await applyPlan(db, plan.toMigrate) : {};
  const summary = summarize({rows, plan, apply, ...result});

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
    // Yalnız mesaj: yığın izine ortam/istek ayrıntısı karışmasın.
    console.error("migrateSupabaseProfiles failed:", err.message || err);
    process.exitCode = 1;
  });
}

module.exports = {main, fetchSupabaseProfiles, supabaseAdminHeaders};
