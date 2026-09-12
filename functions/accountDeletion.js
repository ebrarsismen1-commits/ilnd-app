/**
 * Hesap silme: eksiksiz, tekrar denenebilir, yanlış "başarılı" demeyen.
 *
 * Güvenlik denetimi H-3 (2026-09-13) eski sürümün üç kusurunu buldu:
 *   1. Eksik: habits, habit_completions, daily_checkins, island,
 *      ai_token_usage, RSVP'ler, davet eden taraftaki referrals ve Supabase
 *      profiles satırı hiç silinmiyordu.
 *   2. Kendini geri alan: Supabase silme yanıtı kontrol edilmiyordu (fetch
 *      4xx/5xx'te fırlatmaz). Başarısız olunca kullanıcı yeniden giriş yapıyor,
 *      köprü aynı uid ile Firebase kullanıcısını yeniden yaratıyor, geride
 *      kalan veri geri bağlanıyordu — ve istemciye {deleted: true} dönülüyordu.
 *   3. İdempotent değil: ikinci çağrı deleteUser'da user-not-found → 500.
 *
 * Tasarım:
 *   - İlk iş `deletion_requests/{uid}` mezar taşı (yalnız uid + durum +
 *     zaman). Mezar taşı olan uid için mintFirebaseToken yeni oturum AÇMAZ:
 *     Supabase adımı başarısız olsa bile kullanıcı yeniden giriş yapıp geride
 *     kalan veriye geri bağlanamaz.
 *   - Veri adımları birbirinden bağımsız çalışır, hepsi denenir; biri
 *     başarısız olursa Firebase kullanıcısı SİLİNMEZ, yanıt 500 + başarısız
 *     adımlar olur. Kullanıcı mevcut oturumuyla tekrar deneyebilir;
 *     retryPendingDeletions da 6 saatte bir yeniden dener.
 *   - Her adım idempotent: "zaten yok" başarı sayılır.
 */

const QUERY_BATCH = 300;

/**
 * Sorgunun eşleştirdiği tüm dokümanları partiler halinde siler.
 * @param {FirebaseFirestore.Query} query sorgu
 * @return {Promise<number>} silinen sayısı
 */
async function deleteQuery(query) {
  let total = 0;
  for (;;) {
    const snap = await query.limit(QUERY_BATCH).get();
    if (snap.empty) return total;
    const batch = query.firestore.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    total += snap.size;
  }
}

/**
 * @param {unknown} uid doğrulanmış token'dan gelen uid
 * @return {boolean} yol olarak güvenli mi
 */
function isSafeUid(uid) {
  return typeof uid === "string" && uid.length > 0 && uid.length <= 128 &&
    !uid.includes("/") && uid !== "." && uid !== "..";
}

/**
 * @param {object} err hata
 * @return {boolean} Firebase Auth "kullanıcı yok" hatası mı
 */
function isUserNotFound(err) {
  return Boolean(err && (err.code === "auth/user-not-found" ||
    /USER_NOT_FOUND|no user record/i.test(String(err.message))));
}

/**
 * @param {Response} res fetch yanıtı
 * @return {boolean} 2xx ya da 404 (zaten yok)
 */
function okOrGone(res) {
  return res.ok || res.status === 404;
}

/**
 * Tek bir kullanıcının tüm verisini siler.
 * @param {string} uid Firebase/Supabase uid
 * @param {{
 *   db: FirebaseFirestore.Firestore,
 *   auth: import("firebase-admin").auth.Auth,
 *   getBucket: function(): (object|null),
 *   supabase: {url: (string|undefined), serviceKey: (string|undefined)},
 *   revenueCatKey: (string|undefined),
 *   fetchImpl: typeof fetch,
 *   log?: {warn: function(...*): void, error: function(...*): void},
 * }} deps bağımlılıklar
 * @return {Promise<{complete: boolean, steps: Array<{name: string,
 *   ok: boolean, skipped?: string, error?: string}>}>} sonuç
 */
async function runAccountDeletion(uid, deps) {
  if (!isSafeUid(uid)) throw new Error("Refusing to delete: invalid uid");
  const {db, auth, getBucket, supabase, revenueCatKey, fetchImpl} = deps;
  const log = deps.log || console;
  const {FieldValue} = require("firebase-admin").firestore;
  const tombstone = db.collection("deletion_requests").doc(uid);

  await tombstone.set({
    uid,
    status: "in_progress",
    attempts: FieldValue.increment(1),
    lastAttemptAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  const steps = [];
  const step = async (name, fn) => {
    try {
      const result = await fn();
      steps.push({name, ok: true, ...(result && result.skipped ? {skipped: result.skipped} : {})});
    } catch (err) {
      log.error(`accountDeletion step "${name}" failed:`, err && err.message ? err.message : err);
      steps.push({name, ok: false, error: String((err && err.message) || err).slice(0, 200)});
    }
  };

  // 1. Yeniden giriş kilidi: yukarıda yazılan mezar taşı var olduğu sürece
  //    mintFirebaseToken bu uid için yeni oturum açmaz (hasDeletionRequest).
  //    Firebase kullanıcısı bilerek devre dışı bırakılmıyor / token'ları iptal
  //    edilmiyor: yarım kalan silmeyi kullanıcının mevcut oturumuyla tekrar
  //    deneyebilmesi gerekiyor.

  // 2. Supabase: profil satırı + kimlik. Yapılandırma yoksa BAŞARISIZ: sessizce
  //    atlamak, parasını ödemiş bir kullanıcıya "silindi" deyip kimliğini
  //    Supabase'te bırakmak olurdu.
  await step("supabase", async () => {
    if (!supabase.url || !supabase.serviceKey) {
      throw new Error("Supabase is not configured (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)");
    }
    const headers = {apikey: supabase.serviceKey, Authorization: `Bearer ${supabase.serviceKey}`};
    const id = encodeURIComponent(uid);
    const profile = await fetchImpl(`${supabase.url}/rest/v1/profiles?id=eq.${id}`, {
      method: "DELETE",
      headers: {...headers, Prefer: "return=minimal"},
      signal: AbortSignal.timeout(10000),
    });
    if (!okOrGone(profile)) throw new Error(`profiles delete HTTP ${profile.status}`);
    const user = await fetchImpl(`${supabase.url}/auth/v1/admin/users/${id}`, {
      method: "DELETE",
      headers,
      signal: AbortSignal.timeout(10000),
    });
    if (!okOrGone(user)) throw new Error(`auth user delete HTTP ${user.status}`);
  });

  // 3. Firestore: kullanıcının kendi ağacı + uid'e bağlı üst düzey kayıtlar.
  await step("firestore-user-tree", () => db.recursiveDelete(db.collection("users").doc(uid)));
  const byField = [
    ["habits", "userId"],
    ["habit_completions", "userId"],
    ["daily_checkins", "userId"],
    ["ai_usage", "uid"],
    ["ai_token_usage", "uid"],
    ["referrals", "referred_id"],
    ["referrals", "referrer_id"],
  ];
  for (const [col, field] of byField) {
    await step(`firestore-${col}-${field}`, () =>
      deleteQuery(db.collection(col).where(field, "==", uid)));
  }
  await step("firestore-rsvps", () =>
    deleteQuery(db.collectionGroup("rsvps").where("userId", "==", uid)));
  await step("firestore-island", () => db.collection("island").doc(uid).delete());
  await step("firestore-referral-code", async () => {
    const growth = await db.collection("user_growth").doc(uid).get();
    const code = growth.exists ? (growth.data() || {}).referral_code : null;
    if (typeof code === "string" && code) {
      const codeRef = db.collection("referral_codes").doc(code);
      const codeSnap = await codeRef.get();
      if (codeSnap.exists && (codeSnap.data() || {}).uid === uid) await codeRef.delete();
    }
    await db.collection("user_growth").doc(uid).delete();
  });

  // 4. Storage: uygulama bugün dosya yüklemiyor (avatar Firestore'da), ama
  //    kalıntı varsa silinir. Varsayılan bucket tanımlı değilse atlanır.
  await step("storage", async () => {
    let bucket;
    try {
      bucket = getBucket();
    } catch (err) {
      return {skipped: "no-default-bucket"};
    }
    if (!bucket) return {skipped: "no-default-bucket"};
    try {
      await bucket.deleteFiles({prefix: `users/${uid}/`});
    } catch (err) {
      if (err && (err.code === 404 || /not.?found|does not exist/i.test(String(err.message)))) {
        return {skipped: "bucket-not-found"};
      }
      throw err;
    }
    return null;
  });

  // 5. RevenueCat abone kaydı (anahtar varsa).
  await step("revenuecat", async () => {
    if (!revenueCatKey) return {skipped: "not-configured"};
    const res = await fetchImpl(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
        {method: "DELETE", headers: {Authorization: `Bearer ${revenueCatKey}`}, signal: AbortSignal.timeout(10000)},
    );
    if (!okOrGone(res)) throw new Error(`RevenueCat delete HTTP ${res.status}`);
    return null;
  });

  const failed = steps.filter((s) => !s.ok);

  // 6. Firebase kullanıcısı EN SON ve yalnız her şey tamamsa: aksi halde
  //    kullanıcı tekrar deneyecek oturumu kaybederdi.
  if (failed.length === 0) {
    await step("delete-auth-user", async () => {
      try {
        await auth.deleteUser(uid);
      } catch (err) {
        if (!isUserNotFound(err)) throw err;
      }
    });
  }

  const allFailed = steps.filter((s) => !s.ok);
  const complete = allFailed.length === 0;
  await tombstone.set({
    status: complete ? "done" : "failed",
    failedSteps: allFailed.map((s) => s.name),
    ...(complete ? {completedAt: FieldValue.serverTimestamp()} : {}),
  }, {merge: true});

  return {complete, steps};
}

/**
 * Yarım kalmış silmeleri yeniden dener (zamanlanmış görev).
 * @param {object} deps runAccountDeletion bağımlılıkları
 * @param {{limit?: number}} [opts] ayarlar
 * @return {Promise<{retried: number, completed: number}>} özet
 */
async function retryPendingDeletions(deps, {limit = 20} = {}) {
  const snap = await deps.db.collection("deletion_requests")
      .where("status", "in", ["failed", "in_progress"])
      .limit(limit)
      .get();
  let completed = 0;
  for (const doc of snap.docs) {
    const result = await runAccountDeletion(doc.id, deps);
    if (result.complete) completed++;
  }
  return {retried: snap.size, completed};
}

/**
 * Bu uid için silme istendi mi? mintFirebaseToken buna bakar: istenmişse yeni
 * oturum açılmaz. Okuma hatası fırlatılır (çağıran taraf reddeder).
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} uid uid
 * @return {Promise<boolean>} mezar taşı varsa true
 */
async function hasDeletionRequest(db, uid) {
  if (!isSafeUid(uid)) return false;
  const snap = await db.collection("deletion_requests").doc(uid).get();
  return snap.exists;
}

module.exports = {
  deleteQuery,
  hasDeletionRequest,
  isSafeUid,
  runAccountDeletion,
  retryPendingDeletions,
};
