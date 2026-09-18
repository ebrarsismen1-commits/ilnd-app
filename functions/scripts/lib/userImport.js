/**
 * Supabase auth.users → Firebase Auth taşımasının saf mantığı (ADR-0010).
 * Ağ ve Admin SDK yok; importSupabaseUsers.js bunları sağlar.
 *
 * Şifre TAŞINMAZ (owner kararı): e-posta/şifre kullanıcıları ilk girişte
 * "şifremi unuttum" ile yeni şifre belirler. Taşınan: aynı uid, e-posta,
 * e-posta doğrulama durumu, görünen ad.
 *
 * Köprüden geçmiş her kullanıcının Firebase'te zaten AYNI uid ile e-postasız
 * bir kaydı var (custom token). O kayıt silinmez; yalnız e-posta eklenir.
 */

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Supabase admin API / SQL dışa aktarımındaki bir kullanıcıyı sadeleştirir.
 * @param {object} u Supabase kullanıcısı
 * @return {{id: *, email: (string|null), emailVerified: boolean,
 *   displayName: (string|null), providers: string[], anonymous: boolean}} kullanıcı
 */
function normalizeSupabaseUser(u) {
  const meta = (u && (u.user_metadata || u.raw_user_meta_data)) || {};
  const app = (u && (u.app_metadata || u.raw_app_meta_data)) || {};
  const providers = Array.isArray(app.providers) ? app.providers :
    (app.provider ? [app.provider] : []);
  const name = typeof meta.name === "string" ? meta.name.trim() : "";
  return {
    id: u && u.id,
    email: u && typeof u.email === "string" && u.email ? u.email.trim().toLowerCase() : null,
    emailVerified: Boolean(u && (u.email_confirmed_at || u.confirmed_at)),
    displayName: name && name.length <= 100 ? name : null,
    providers,
    anonymous: Boolean(u && u.is_anonymous),
  };
}

/**
 * Her kullanıcı için karar verir. Yan etki yok.
 * @param {object} p girdiler
 * @param {object[]} p.users normalizeSupabaseUser çıktıları
 * @param {Map<string, {email: (string|undefined)}>} p.firebaseByUid Firebase'te
 *   bu uid'lerle var olan kullanıcılar
 * @param {Map<string, string>} p.firebaseUidByEmail Firebase'te bu e-postaları
 *   taşıyan kullanıcıların uid'leri
 * @return {object} plan
 */
function planUserImport({users, firebaseByUid, firebaseUidByEmail}) {
  const counts = new Map();
  for (const u of users) counts.set(u.id, (counts.get(u.id) || 0) + 1);
  const emailCounts = new Map();
  for (const u of users) if (u.email) emailCounts.set(u.email, (emailCounts.get(u.email) || 0) + 1);

  const plan = {
    create: [],
    addEmail: [],
    alreadyImported: [],
    invalid: [],
    duplicates: [],
    anonymous: [],
    noEmail: [],
    unsupportedProvider: [],
    conflicts: [],
  };
  const seenDup = new Set();
  for (const u of users) {
    if (typeof u.id !== "string" || !UUID_RE.test(u.id)) {
      plan.invalid.push(String(u.id));
      continue;
    }
    if (counts.get(u.id) > 1 || (u.email && emailCounts.get(u.email) > 1)) {
      if (!seenDup.has(u.id)) plan.duplicates.push(u.id);
      seenDup.add(u.id);
      continue;
    }
    if (u.anonymous) {
      plan.anonymous.push(u.id);
      continue;
    }
    // Google/Apple kimliklerini bağlamak sağlayıcı uid'i ister; prod'da yok
    // (2026-09-18 yalnız "email"). Çıkarsa tahmin edilmez, listelenir.
    const other = u.providers.filter((p) => p !== "email");
    if (other.length) {
      plan.unsupportedProvider.push({uid: u.id, providers: other});
      continue;
    }
    if (!u.email || !EMAIL_RE.test(u.email)) {
      plan.noEmail.push(u.id);
      continue;
    }
    const emailOwner = firebaseUidByEmail.get(u.email);
    if (emailOwner && emailOwner !== u.id) {
      // Aynı e-posta Firebase'te BAŞKA bir hesapta: birleştirmek ya da
      // ezmek veri kaybettirebilir; owner karar verir.
      plan.conflicts.push({uid: u.id, reason: "email-used-by-other-uid"});
      continue;
    }
    const existing = firebaseByUid.get(u.id);
    const attrs = {
      email: u.email,
      emailVerified: u.emailVerified,
      ...(u.displayName ? {displayName: u.displayName} : {}),
    };
    if (!existing) {
      plan.create.push({uid: u.id, attrs});
    } else if (!existing.email) {
      plan.addEmail.push({uid: u.id, attrs});
    } else if (existing.email.toLowerCase() === u.email) {
      plan.alreadyImported.push(u.id);
    } else {
      plan.conflicts.push({uid: u.id, reason: "uid-has-different-email"});
    }
  }
  return plan;
}

/**
 * @param {object} p girdiler
 * @param {object[]} p.users kaynak kullanıcılar
 * @param {object} p.plan planUserImport çıktısı
 * @param {boolean} p.apply yazıldı mı
 * @param {string[]} [p.created] yaratılanlar
 * @param {string[]} [p.updated] e-postası eklenenler
 * @param {{uid: string, error: string}[]} [p.failed] başarısızlar
 * @return {object} özet (yalnız uid ve sayı; e-posta yok)
 */
function summarizeUserImport({users, plan, apply, created = [], updated = [], failed = []}) {
  return {
    mode: apply ? "apply" : "dry-run",
    totalUsers: users.length,
    created: apply ? created.length : 0,
    emailAdded: apply ? updated.length : 0,
    wouldCreate: apply ? undefined : plan.create.length,
    wouldAddEmail: apply ? undefined : plan.addEmail.length,
    alreadyImported: plan.alreadyImported.length,
    conflicts: plan.conflicts.length,
    duplicates: plan.duplicates.length,
    invalid: plan.invalid.length,
    anonymous: plan.anonymous.length,
    noEmail: plan.noEmail.length,
    unsupportedProvider: plan.unsupportedProvider.length,
    failed: failed.length,
    lists: {
      // Geri alma için: apply'da yaratılan ve e-posta eklenen uid'ler. Kuru
      // çalışmada "yaratılacak / eklenecek" listesi.
      created: apply ? created : plan.create.map((p) => p.uid),
      emailAdded: apply ? updated : plan.addEmail.map((p) => p.uid),
      conflicts: plan.conflicts,
      duplicates: plan.duplicates,
      invalid: plan.invalid,
      anonymous: plan.anonymous,
      noEmail: plan.noEmail,
      unsupportedProvider: plan.unsupportedProvider,
      failed,
    },
  };
}

module.exports = {normalizeSupabaseUser, planUserImport, summarizeUserImport};
