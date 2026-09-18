/**
 * Supabase `profiles` → Firestore `users/{uid}` taşımasının saf mantığı.
 * Ağ ve Admin SDK yok; migrateSupabaseProfiles.js bunları sağlar.
 *
 * Kimlik eşleşmesi: Firebase uid'i, köprünün (mintFirebaseToken) Supabase
 * JWT `sub`'ından aynen kopyaladığı değer. Yani `profiles.id` === Firebase
 * uid; e-posta eşlemesine gerek yok ve yapılmıyor.
 *
 * Alan adları lib/core/repositories/profile_repository.dart `ProfileFields`
 * ile, sınırlar firestore.rules `validProfile` ile aynı. Sınır dışı bir değer
 * yazılsaydı kurallar dokümanın tamamını doğruladığı için kullanıcının sonraki
 * her profil güncellemesi reddedilirdi; bu yüzden yazılmaz, raporlanır.
 */

/** Supabase kolonu → Firestore alanı ve doğrulayıcı. */
const FIELD_MAP = [
  {from: "name", to: "name", check: (v) => str(v, 100)},
  {from: "onboarding_done", to: "onboardingDone", check: (v) => typeof v === "boolean"},
  {from: "first_entry_done", to: "firstEntryDone", check: (v) => typeof v === "boolean"},
  {from: "goals", to: "goals", check: list},
  {from: "activity_level", to: "activityLevel", check: (v) => str(v, 40)},
  {from: "diet", to: "diet", check: (v) => str(v, 40)},
  {from: "allergies", to: "allergies", check: list},
  {from: "age", to: "age", check: (v) => int(v, 0, 130)},
  {from: "height", to: "heightCm", check: (v) => int(v, 0, 300)},
  {from: "weight", to: "weightKg", check: (v) => int(v, 0, 700)},
];

/** Firestore'da istemcinin profil yazdığını gösteren damga (bkz. kurallar). */
const CLIENT_STAMP = "profileUpdatedAt";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * @param {*} v değer
 * @param {number} max üst sınır
 * @return {boolean} boş olmayan, sınır içi string mi
 */
function str(v, max) {
  return typeof v === "string" && v.length > 0 && v.length <= max;
}

/**
 * @param {*} v değer
 * @return {boolean} en çok 50 string'lik liste mi
 */
function list(v) {
  return Array.isArray(v) && v.length <= 50 && v.every((e) => typeof e === "string");
}

/**
 * @param {*} v değer
 * @param {number} lo alt sınır
 * @param {number} hi üst sınır
 * @return {boolean} sınır içi tam sayı mı
 */
function int(v, lo, hi) {
  return Number.isInteger(v) && v >= lo && v <= hi;
}

/**
 * Tek bir Supabase satırını Firestore alanlarına çevirir.
 * null / boş değerler yazılmaz (mevcut değeri ezmesin); geçersizler
 * `dropped`'a girer.
 * @param {object} row Supabase satırı
 * @return {{fields: object, dropped: string[]}} yazılacak alanlar
 */
function mapProfileRow(row) {
  const fields = {};
  const dropped = [];
  for (const {from, to, check} of FIELD_MAP) {
    const v = row[from];
    if (v === null || v === undefined || v === "") continue;
    if (check(v)) {
      fields[to] = v;
    } else {
      dropped.push(from);
    }
  }
  return {fields, dropped};
}

/**
 * Her satır için karar verir. Hiçbir yan etkisi yok.
 * @param {object} p girdiler
 * @param {object[]} p.rows Supabase profiles satırları
 * @param {Set<string>} p.authUids Firebase Auth'ta var olan uid'ler
 * @param {Map<string, (object|null)>} p.existing users/{uid} verisi (yoksa null)
 * @return {object} plan
 */
function planMigration({rows, authUids, existing}) {
  const counts = new Map();
  for (const r of rows) counts.set(r && r.id, (counts.get(r && r.id) || 0) + 1);

  const plan = {
    toMigrate: [],
    invalidIds: [],
    duplicates: [],
    missingUsers: [],
    alreadyOnFirestore: [],
    sanitized: [],
  };
  const seenDuplicate = new Set();
  for (const row of rows) {
    const id = row && row.id;
    if (typeof id !== "string" || !UUID_RE.test(id)) {
      plan.invalidIds.push(String(id));
      continue;
    }
    // Birincil anahtar olduğu için olmamalı; olursa hangisinin doğru olduğunu
    // tahmin etmiyoruz: hiçbiri yazılmaz, listelenir.
    if (counts.get(id) > 1) {
      if (!seenDuplicate.has(id)) plan.duplicates.push(id);
      seenDuplicate.add(id);
      continue;
    }
    if (!authUids.has(id)) {
      plan.missingUsers.push(id);
      continue;
    }
    const doc = existing.get(id);
    if (doc && doc[CLIENT_STAMP] != null) {
      plan.alreadyOnFirestore.push(id);
      continue;
    }
    const {fields, dropped} = mapProfileRow(row);
    if (dropped.length) plan.sanitized.push({uid: id, fields: dropped});
    plan.toMigrate.push({uid: id, fields});
  }
  return plan;
}

/**
 * @param {object} p girdiler
 * @param {object[]} p.rows kaynak satırlar
 * @param {object} p.plan planMigration çıktısı
 * @param {boolean} p.apply gerçekten yazıldı mı
 * @param {string[]} p.migrated yazılan uid'ler
 * @param {string[]} p.raced işlem sırasında istemcinin yazdığı için atlananlar
 * @param {{uid: string, error: string}[]} p.failed başarısızlar
 * @return {object} özet (yalnız uid ve sayı; kişisel veri yok)
 */
function summarize({rows, plan, apply, migrated = [], raced = [], failed = []}) {
  const matched = plan.toMigrate.length + plan.alreadyOnFirestore.length;
  return {
    mode: apply ? "apply" : "dry-run",
    totalProfiles: rows.length,
    matchedUsers: matched,
    migrated: apply ? migrated.length : 0,
    wouldMigrate: apply ? undefined : plan.toMigrate.length,
    skipped: plan.alreadyOnFirestore.length + raced.length,
    missingUsers: plan.missingUsers.length,
    duplicates: plan.duplicates.length,
    invalidIds: plan.invalidIds.length,
    sanitizedProfiles: plan.sanitized.length,
    failed: failed.length,
    lists: {
      missingUsers: plan.missingUsers,
      duplicates: plan.duplicates,
      invalidIds: plan.invalidIds,
      alreadyOnFirestore: plan.alreadyOnFirestore.concat(raced),
      sanitized: plan.sanitized,
      failed,
    },
  };
}

module.exports = {FIELD_MAP, CLIENT_STAMP, mapProfileRow, planMigration, summarize};
