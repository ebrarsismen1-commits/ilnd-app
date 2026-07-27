const {onRequest} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const {createRemoteJWKSet, jwtVerify} = require("jose");

admin.initializeApp();
setGlobalOptions({maxInstances: 10});

const db = admin.firestore();

// SUPABASE_URL gelir functions/.env dosyasından (deploy/emulator sırasında
// otomatik yüklenir) ya da `firebase functions:secrets:set` ile.
const SUPABASE_URL = process.env.SUPABASE_URL;
const JWKS = SUPABASE_URL ?
  createRemoteJWKSet(
      new URL(`${SUPABASE_URL}/auth/v1/.well-known/jwks.json`),
  ) :
  null;

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
const SUPABASE_SERVICE_ROLE_KEY = defineSecret("SUPABASE_SERVICE_ROLE_KEY");

// RevenueCat "secret" (v1) API anahtarı — hesabın gerçekten abone olup
// olmadığını SUNUCUDAN doğrulamak için. functions/.env üzerinden gelir
// (SUPABASE_URL ile aynı mekanizma) ve İSTEĞE BAĞLIDIR: yoksa abonelik
// doğrulanamaz, yalnız sunucunun kendi yazdığı ödül-premium'u (referral)
// bilinir. Mağaza aboneliği canlıya alınmadan ÖNCE bu anahtar girilmeli,
// yoksa gerçek aboneler ücretsiz katman sınırına takılır.
const REVENUECAT_SECRET_KEY = process.env.REVENUECAT_SECRET_KEY || "";
// lib/core/billing/revenue_cat_service.dart'taki _kEntitlement ile aynı.
const REVENUECAT_ENTITLEMENT = "premium";

/**
 * Supabase oturum JWT'sini doğrulayıp aynı user id (uid) ile bir Firebase
 * custom token üretir. ILND auth Supabase üzerinden yapılıyor ama Firestore
 * güvenlik kuralları Firebase'in kendi request.auth'una bakıyor — bu köprü
 * olmadan request.auth hep null kalır ve tüm Firestore okuma/yazmaları
 * permission-denied ile başarısız olur.
 *
 * İstek: POST, header "Authorization: Bearer <supabase_access_token>"
 * Yanıt: { "firebaseToken": "..." }
 *
 * Not: bilerek `enforceAppCheck` yok — bu, oturum açma akışının en başında
 * çağrılıyor (Firebase henüz Auth'lanmamış kullanıcı için), App Check
 * aktivasyonunda beklenmedik bir sorun çıkarsa kullanıcıyı giriş yapamaz
 * duruma düşürmemek için diğer üç endpoint'ten (anthropicProxy,
 * redeemReferralCode, deleteAccount — hepsi zaten bir Firebase oturumu
 * gerektiriyor) ayrı tutuldu. Asıl güvenlik sınırı zaten Supabase JWT
 * doğrulaması.
 */
exports.mintFirebaseToken = onRequest({cors: true}, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({error: "Method Not Allowed"});
    return;
  }

  const authHeader = req.headers.authorization || "";
  const supabaseToken = authHeader.startsWith("Bearer ") ?
    authHeader.slice(7) :
    null;

  if (!supabaseToken) {
    res.status(401).json({error: "Missing bearer token"});
    return;
  }

  if (!JWKS) {
    res.status(500).json({
      error: "SUPABASE_URL not configured on the function " +
        "(set functions/.env or use functions:secrets:set)",
    });
    return;
  }

  try {
    const {payload} = await jwtVerify(supabaseToken, JWKS, {
      issuer: `${SUPABASE_URL}/auth/v1`,
    });

    const uid = payload.sub;
    if (!uid) {
      res.status(401).json({error: "Token has no subject"});
      return;
    }

    const firebaseToken = await admin.auth().createCustomToken(uid, {
      provider: "supabase",
    });

    res.status(200).json({firebaseToken});
  } catch (err) {
    // Geçici: teşhis için hata mesajını ayrı alanla logla (Cloud Logging
    // CLI görüntüleyicisi bazen ham Error objesini boş gösteriyor).
    console.error("mintFirebaseToken failed:", err.message || err, err.name);
    res.status(401).json({error: "Invalid Supabase token"});
  }
});

/**
 * Verifies the Firebase ID token from the Authorization header and returns
 * the decoded token (with `.uid`). Throws on missing/invalid token — every
 * sensitive endpoint below calls this before doing anything else so a
 * request can never act on behalf of a uid it doesn't hold a valid token
 * for.
 * @param {import("firebase-functions/v2/https").Request} req incoming request
 * @return {Promise<admin.auth.DecodedIdToken>} decoded Firebase ID token
 */
async function requireFirebaseAuth(req) {
  const authHeader = req.headers.authorization || "";
  const idToken = authHeader.startsWith("Bearer ") ?
    authHeader.slice(7) :
    null;
  if (!idToken) throw new Error("Missing bearer token");
  return admin.auth().verifyIdToken(idToken);
}

// ─── AI proxy ───────────────────────────────────────────────────────────────

// quick eskiden claude-haiku-4-5 idi; Haiku'nun Türkçesi kullanıcıya "bozuk /
// anlamsız" gelecek kadar zayıftı (2026-07-08 owner geri bildirimi). Sonnet'in
// maliyeti ~3x ama sohbet ürünün kalbi — kalite burada ucuzlatılmaz.
const TIER_CONFIG = {
  quick: {model: "claude-sonnet-4-6", maxTokens: 512, dailyLimit: 300},
  deep: {model: "claude-sonnet-4-6", maxTokens: 1024, dailyLimit: 60},
};

// ─── Hesap bazlı ücretsiz katman kotası ─────────────────────────────────────

// Ücretsiz katmanın HAFTALIK sınırları. lib/core/billing/usage_meter.dart'taki
// kFreeWeeklyLimits ile birebir aynı olmalı: istemci bu değerleri yalnız
// paywall'ı ne zaman göstereceğini bilmek için kullanır, gerçek karar burada
// verilir.
const FREE_WEEKLY_LIMITS = {message: 20, food: 5};

// Kotadan düşen (kullanıcının bilerek başlattığı) eylem türleri. Bunun
// dışındaki her çağrı "system" sayılır: karşılama mesajı, hafıza çıkarımı,
// öneri üretimi gibi kullanıcının saymadığı yardımcı çağrılar — bunlar
// haftalık kotadan düşmez, yalnız aşağıdaki günlük kademe tavanına tabidir.
const METERED_KINDS = ["message", "food"];
const KNOWN_KINDS = ["system", ...METERED_KINDS];

// Doğrulanmış premium sonucu bu kadar süre önbelleklenir. Yalnız POZİTİF
// sonuç önbelleklenir: "premium değil" saklansaydı, aboneliği yeni satın
// alan kullanıcı saatlerce sınırda kalırdı.
const PREMIUM_CACHE_MS = 6 * 60 * 60 * 1000;

/**
 * UTC tabanlı, PAZARTESİ başlayan hafta kovası (ör. "W2951").
 *
 * lib/core/billing/usage_meter.dart'taki `usageWeekKey` ile BİREBİR aynı
 * formül: farklı olurlarsa istemci sunucunun yazdığından başka bir dokümanı
 * okur ve kalan hak yanlış görünür. Epoch günü 0 = 1 Ocak 1970 Perşembe,
 * bu yüzden +3 kaydırma kovaları pazartesiye hizalar. Yerel saat dilimi
 * bilerek kullanılmaz — kullanıcı uçakta saat dilimi değiştirince haftası
 * sıfırlanmamalı.
 * @param {number} [nowMs] epoch milisaniye (test için)
 * @return {string} hafta anahtarı
 */
function currentWeekKey(nowMs = Date.now()) {
  const days = Math.floor(nowMs / 86400000);
  return `W${Math.floor((days + 3) / 7)}`;
}

/**
 * Checks and atomically increments the caller's usage counters. Two caps are
 * enforced in one transaction:
 *   1. günlük kademe tavanı (kötüye kullanım/fatura koruması, her kullanıcı),
 *   2. haftalık ücretsiz katman kotası (yalnız [kind] ölçülen bir türse ve
 *      kullanıcı premium değilse).
 *
 * Her iki sayaç da Firebase uid'ine bağlıdır — cihaza değil. Kullanıcı web'e
 * geçse, uygulamayı silip kursa ya da yerel depolamayı temizlese de aynı
 * sayaç devam eder (bu, sayacın SharedPreferences'ta tutulduğu sürümde
 * yaşanan hataydı: her cihaz kendi kotasını sıfırdan başlatıyordu).
 * @param {string} uid Firebase uid of the caller
 * @param {string} tier "quick" or "deep"
 * @param {string} kind "message" | "food" | "system"
 * @param {boolean} freeQuotaApplies false = premium (haftalık kota atlanır)
 * @return {Promise<{allowed: boolean, reason?: string, used?: number,
 *   limit?: number}>} karar
 */
async function checkAndIncrementUsage(uid, tier, kind, freeQuotaApplies) {
  const day = new Date().toISOString().slice(0, 10);
  const week = currentWeekKey();
  const dayRef = db.collection("ai_usage").doc(`${uid}_${day}`);
  const weekRef = db.collection("ai_usage").doc(`${uid}_${week}`);
  const metered = freeQuotaApplies && METERED_KINDS.includes(kind);

  return db.runTransaction(async (tx) => {
    // Firestore transaction'ında TÜM okumalar yazmalardan önce gelmeli.
    const daySnap = await tx.get(dayRef);
    const weekSnap = metered ? await tx.get(weekRef) : null;

    const dayCounts = daySnap.exists ? (daySnap.data().counts || {}) : {};
    const dayUsed = dayCounts[tier] || 0;
    if (dayUsed >= TIER_CONFIG[tier].dailyLimit) {
      return {allowed: false, reason: "daily-tier-limit"};
    }

    if (metered) {
      const weekCounts = weekSnap.exists ? (weekSnap.data().counts || {}) : {};
      const used = weekCounts[kind] || 0;
      const limit = FREE_WEEKLY_LIMITS[kind];
      if (used >= limit) {
        return {allowed: false, reason: "free-weekly-limit", used, limit};
      }
      weekCounts[kind] = used + 1;
      tx.set(weekRef, {
        uid,
        period: week,
        counts: weekCounts,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    dayCounts[tier] = dayUsed + 1;
    tx.set(dayRef, {
      uid,
      day,
      counts: dayCounts,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return {allowed: true};
  });
}

/**
 * Whether the server can prove this account is premium. İki kaynak:
 *   1. user_growth.premium_access_until — referral ödülü, zaten yalnız
 *      redeemReferralCode (Admin SDK) yazabiliyor, dolayısıyla güvenilir.
 *   2. RevenueCat aboneliği — anahtar yapılandırıldıysa REST ile doğrulanır.
 *
 * İstemcinin "ben premium'um" beyanına BİLEREK bakılmaz: bakılsaydı sayacı
 * sunucuya taşımanın anlamı kalmazdı, herkes o bayrağı gönderebilirdi.
 * @param {string} uid Firebase uid
 * @return {Promise<boolean>} true if premium
 */
async function resolvePremium(uid) {
  const cacheRef = db.collection("ai_usage").doc(`${uid}_premium`);
  try {
    const snap = await cacheRef.get();
    const data = snap.exists ? (snap.data() || {}) : {};
    if (data.premium === true &&
        typeof data.checkedAt === "number" &&
        Date.now() - data.checkedAt < PREMIUM_CACHE_MS) {
      return true;
    }
  } catch (err) {
    console.warn("resolvePremium cache read failed:", err.message || err);
  }

  const premium =
    (await hasReferralPremium(uid)) || (await hasRevenueCatPremium(uid));

  if (premium) {
    try {
      await cacheRef.set({
        uid,
        premium: true,
        checkedAt: Date.now(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    } catch (err) {
      console.warn("resolvePremium cache write failed:", err.message || err);
    }
  }
  return premium;
}

/**
 * Referral ödülüyle gelen süreli premium (redeemReferralCode yazar).
 * @param {string} uid Firebase uid
 * @return {Promise<boolean>} true if the reward window is still open
 */
async function hasReferralPremium(uid) {
  try {
    const snap = await db.collection("user_growth").doc(uid).get();
    const data = snap.exists ? (snap.data() || {}) : {};
    const until = data.premium_access_until;
    return Boolean(until && typeof until.toMillis === "function" &&
      until.toMillis() > Date.now());
  } catch (err) {
    console.error("hasReferralPremium failed:", err.message || err);
    return false;
  }
}

/**
 * RevenueCat aboneliğini sunucudan doğrular. Bunun çalışması için istemcinin
 * `Purchases.logIn(uid)` çağırmış olması şart (bkz. RevenueCatService.identify)
 * — aksi halde abonelik anonim bir app_user_id'ye bağlanır ve uid ile
 * bulunamaz. Anahtar yoksa sessizce false döner.
 * @param {string} uid Firebase uid (= RevenueCat app_user_id)
 * @return {Promise<boolean>} true if an active premium entitlement exists
 */
async function hasRevenueCatPremium(uid) {
  if (!REVENUECAT_SECRET_KEY) return false;
  try {
    const res = await fetch(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
        {
          headers: {
            "Authorization": `Bearer ${REVENUECAT_SECRET_KEY}`,
            "content-type": "application/json",
          },
          signal: AbortSignal.timeout(10000),
        },
    );
    if (!res.ok) return false;
    const data = await res.json();
    const subscriber = data.subscriber || {};
    const ent = (subscriber.entitlements || {})[REVENUECAT_ENTITLEMENT];
    if (!ent) return false;
    // expires_date null = süresiz (lifetime) hak.
    if (!ent.expires_date) return true;
    return new Date(ent.expires_date).getTime() > Date.now();
  } catch (err) {
    console.warn("hasRevenueCatPremium failed:", err.message || err);
    return false;
  }
}

// Girdi tavanları. Metin ve görsel AYRI sınırlanır çünkü maliyetleri çok
// farklı: 1MB metin ~250k token (pahalı), 1MB görsel ~1.6k token (ucuz).
// Tek bir "gövde boyutu" sınırı ya fotoğrafı bloklar ya metni serbest bırakır.
const MAX_BODY_BYTES = 8 * 1024 * 1024; // fotoğraf (istemci 4MB'a kırpar) + pay
const MAX_MESSAGES = 30; // sohbet penceresi 8 tur; 30 fazlasıyla yeterli
const MAX_TEXT_CHARS = 100000; // ~25k token → çağrı başı girdi maliyeti sınırlı
const MAX_IMAGES = 2;

/**
 * Rejects oversized payloads before they reach Anthropic. Returns null when
 * the request is fine, or `{status, error}` describing the violation.
 * @param {import("firebase-functions/v2/https").Request} req incoming request
 * @param {unknown} system system prompt from the body (may be absent)
 * @param {Array<unknown>} messages the messages array from the body
 * @return {{status: number, error: string}|null} violation, or null if OK
 */
function validateInputSize(req, system, messages) {
  const bytes = req.rawBody ?
    req.rawBody.length :
    Buffer.byteLength(JSON.stringify(req.body || {}));
  if (bytes > MAX_BODY_BYTES) {
    return {status: 413, error: "Payload too large"};
  }
  if (messages.length > MAX_MESSAGES) {
    return {status: 400, error: "Too many messages"};
  }

  let textChars = typeof system === "string" ? system.length : 0;
  let images = 0;
  for (const msg of messages) {
    const content = msg && msg.content;
    if (typeof content === "string") {
      textChars += content.length;
      continue;
    }
    if (!Array.isArray(content)) continue;
    for (const block of content) {
      if (!block || typeof block !== "object") continue;
      if (block.type === "image") images++;
      if (typeof block.text === "string") textChars += block.text.length;
    }
  }
  if (textChars > MAX_TEXT_CHARS) {
    return {status: 400, error: "Input text too long"};
  }
  if (images > MAX_IMAGES) {
    return {status: 400, error: "Too many images"};
  }
  return null;
}

/**
 * Server-side proxy for Anthropic's Messages API. Holds the API key,
 * authenticates the caller via Firebase ID token, and enforces a daily
 * per-tier usage cap — the client never sees the key and can never exceed
 * the cap by tampering with local storage, since the counter lives here.
 *
 * İstek: POST, header "Authorization: Bearer <firebase_id_token>"
 * Body: { "tier": "quick"|"deep", "system": "...", "messages": [...] }
 */
// GEÇİCİ: enforceAppCheck kapalı — debug cihazının App Check token'ı
// Firebase Console'a kayıtlı değil. Production'a çıkmadan ÖNCE debug
// token'ı kaydedip enforceAppCheck: true'ya geri dön (bkz. 2026-07-07
// decisions.md notu).
exports.anthropicProxy = onRequest(
    {cors: true, secrets: [ANTHROPIC_API_KEY]},
    async (req, res) => {
      if (req.method !== "POST") {
        res.status(405).json({error: "Method Not Allowed"});
        return;
      }

      let uid;
      try {
        const decoded = await requireFirebaseAuth(req);
        uid = decoded.uid;
      } catch (err) {
        res.status(401).json({error: "Invalid or missing auth token"});
        return;
      }

      const {tier, system, messages} = req.body || {};
      const config = TIER_CONFIG[tier];
      if (!config || !Array.isArray(messages) || messages.length === 0) {
        res.status(400).json({error: "Invalid request body"});
        return;
      }

      // kind = ücretsiz katman kotasından düşecek eylem türü. Belirtilmezse
      // "system" (yardımcı çağrı) sayılır — kotadan düşmez.
      const kind = typeof (req.body || {}).kind === "string" ?
        req.body.kind :
        "system";
      if (!KNOWN_KINDS.includes(kind)) {
        res.status(400).json({error: "Invalid usage kind"});
        return;
      }

      // Girdi sınırları — max_tokens yalnız ÇIKTIYI sınırlar. Bu olmadan
      // geçerli bir hesap günlük çağrı hakkını devasa bağlamlarla harcayıp
      // ciddi fatura çıkarabilir (denetim bulgusu, 2026-07-24).
      const sizeErr = validateInputSize(req, system, messages);
      if (sizeErr) {
        res.status(sizeErr.status).json({error: sizeErr.error});
        return;
      }

      let quota;
      try {
        quota = await checkAndIncrementUsage(uid, tier, kind, true);
        // Haftalık ücretsiz kota doldu — premium hesaplar bundan muaf. Bu
        // kontrol bilerek sona bırakıldı: premium doğrulaması (Firestore +
        // RevenueCat) yalnız sınıra DAYANAN çağrıda çalışır, her mesajda
        // değil.
        if (!quota.allowed && quota.reason === "free-weekly-limit") {
          if (await resolvePremium(uid)) {
            quota = await checkAndIncrementUsage(uid, tier, kind, false);
          }
        }
      } catch (err) {
        console.error("anthropicProxy usage check failed:", err);
        res.status(500).json({error: "Internal error"});
        return;
      }
      if (!quota.allowed) {
        res.status(429).json({
          error: quota.reason === "free-weekly-limit" ?
            "Free weekly usage limit reached" :
            "Daily AI usage limit reached",
          // İstemci bu alana bakıp paywall mı yoksa "yarın tekrar dene"
          // mesajı mı göstereceğine karar verir.
          reason: quota.reason,
          kind,
          used: quota.used,
          limit: quota.limit,
        });
        return;
      }

      try {
        const upstream = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "x-api-key": ANTHROPIC_API_KEY.value(),
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
          },
          body: JSON.stringify({
            model: config.model,
            max_tokens: config.maxTokens,
            // Çok turlu konuşmalarda (sohbet) system prompt'u (kişilik +
            // hafıza, ~600-800 token) her mesajda tam fiyattan gitmesin:
            // prompt caching ile takip mesajlarında %90 indirimli okunur.
            // Tek atımlık çağrılarda (ritüel, öneri) cache yazma primi
            // (%25) boşa gider — o yüzden yalnız messages.length > 1 iken.
            system: typeof system === "string" ?
              (Array.isArray(messages) && messages.length > 1 ?
                [{
                  type: "text",
                  text: system,
                  cache_control: {type: "ephemeral"},
                }] :
                system) :
              undefined,
            messages,
          }),
        });

        const data = await upstream.json();
        res.status(upstream.status).json(data);
      } catch (err) {
        console.error("anthropicProxy upstream failed:", err);
        res.status(502).json({error: "Upstream AI request failed"});
      }
    },
);

// ─── Referral redemption ────────────────────────────────────────────────────

const REFERRAL_REWARD_DAYS = 7;

/**
 * Atomically redeems a referral code. Runs entirely server-side inside a
 * single transaction: validates the code, blocks self-referral and
 * double-redemption, writes the `referrals` record, and grants the
 * referrer's reward. firestore.rules denies clients write access to
 * `founding_member`/`premium_access_until`/`referred_by_code` after
 * creation — this function (Admin SDK) is the only path that can set them.
 *
 * İstek: POST, header "Authorization: Bearer <firebase_id_token>"
 * Body: { "code": "ABC123" }
 */
// GEÇİCİ: enforceAppCheck kapalı — bkz. anthropicProxy üstündeki not.
exports.redeemReferralCode = onRequest(
    {cors: true},
    async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({error: "Method Not Allowed"});
    return;
  }

  let uid;
  try {
    const decoded = await requireFirebaseAuth(req);
    uid = decoded.uid;
  } catch (err) {
    res.status(401).json({error: "Invalid or missing auth token"});
    return;
  }

  const code = String((req.body || {}).code || "").trim().toUpperCase();
  if (!code) {
    res.status(400).json({error: "Missing code"});
    return;
  }

  const userGrowthCol = db.collection("user_growth");
  const referralsCol = db.collection("referrals");

  try {
    const result = await db.runTransaction(async (tx) => {
      const myRef = userGrowthCol.doc(uid);
      const mySnap = await tx.get(myRef);
      if (mySnap.exists && mySnap.data().referred_by_code) {
        return {redeemed: false, reason: "already-redeemed"};
      }

      const matchSnap = await tx.get(
          userGrowthCol.where("referral_code", "==", code).limit(1),
      );
      if (matchSnap.empty) {
        return {redeemed: false, reason: "invalid-code"};
      }

      const referrerDoc = matchSnap.docs[0];
      const referrerId = referrerDoc.id;
      if (referrerId === uid) {
        return {redeemed: false, reason: "self-referral"};
      }

      const referralRef = referralsCol.doc();
      tx.set(referralRef, {
        referrer_id: referrerId,
        referred_id: uid,
        referral_code: code,
        status: "completed",
        reward_claimed: true,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(myRef, {referred_by_code: code}, {merge: true});

      const currentUntil = referrerDoc.data().premium_access_until;
      const now = Date.now();
      const base = currentUntil && currentUntil.toMillis() > now ?
        currentUntil.toMillis() :
        now;
      const newUntil = new Date(
          base + REFERRAL_REWARD_DAYS * 24 * 60 * 60 * 1000,
      );
      tx.set(referrerDoc.ref, {
        founding_member: true,
        premium_access_until: admin.firestore.Timestamp.fromDate(newUntil),
      }, {merge: true});

      return {redeemed: true};
    });

    res.status(200).json(result);
  } catch (err) {
    console.error("redeemReferralCode failed:", err);
    res.status(500).json({error: "Internal error"});
  }
});

// ─── Account deletion ───────────────────────────────────────────────────────

/**
 * Recursively deletes a document and every subcollection beneath it, in
 * batches of 200 to stay well under Firestore's per-batch write limit.
 * @param {admin.firestore.DocumentReference} docRef root document to wipe
 * @return {Promise<void>}
 */
async function deleteFirestoreSubtree(docRef) {
  const collections = await docRef.listCollections();
  for (const col of collections) {
    let snap = await col.limit(200).get();
    while (!snap.empty) {
      const batch = db.batch();
      snap.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
      snap = await col.limit(200).get();
    }
  }
  await docRef.delete();
}

/**
 * Permanently and irreversibly deletes a user's account: their Firestore
 * `users/{uid}` subtree, `user_growth` doc, any `referrals` rows where they
 * are the referred party, Storage files under `users/{uid}/`, their
 * Supabase auth identity (best-effort), and finally the Firebase Auth user
 * itself. The client only reaches this after an explicit in-app
 * confirmation step.
 *
 * İstek: POST, header "Authorization: Bearer <firebase_id_token>"
 */
// GEÇİCİ: enforceAppCheck kapalı — bkz. anthropicProxy üstündeki not.
exports.deleteAccount = onRequest(
    {cors: true, secrets: [SUPABASE_SERVICE_ROLE_KEY]},
    async (req, res) => {
      if (req.method !== "POST") {
        res.status(405).json({error: "Method Not Allowed"});
        return;
      }

      let uid;
      try {
        const decoded = await requireFirebaseAuth(req);
        uid = decoded.uid;
      } catch (err) {
        res.status(401).json({error: "Invalid or missing auth token"});
        return;
      }

      try {
        await deleteFirestoreSubtree(db.collection("users").doc(uid));
        await db.collection("user_growth").doc(uid).delete().catch(() => {});

        const referredSnap = await db.collection("referrals")
            .where("referred_id", "==", uid).get();
        await Promise.all(referredSnap.docs.map((d) => d.ref.delete()));

        // Kullanım sayaçları da hesaba bağlı kişisel veridir — hesapla
        // birlikte gider (gün/hafta dokümanları + premium önbelleği).
        const usageSnap = await db.collection("ai_usage")
            .where("uid", "==", uid).get();
        await Promise.all(usageSnap.docs.map((d) => d.ref.delete()));

        try {
          const bucket = admin.storage().bucket();
          await bucket.deleteFiles({prefix: `users/${uid}/`});
        } catch (err) {
          console.warn("deleteAccount: storage cleanup failed:", err);
        }

        const serviceKey = SUPABASE_SERVICE_ROLE_KEY.value();
        if (SUPABASE_URL && serviceKey) {
          try {
            await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${uid}`, {
              method: "DELETE",
              headers: {
                apikey: serviceKey,
                Authorization: `Bearer ${serviceKey}`,
              },
            });
          } catch (err) {
            console.warn("deleteAccount: supabase user deletion failed:", err);
          }
        }

        await admin.auth().deleteUser(uid);

        res.status(200).json({deleted: true});
      } catch (err) {
        console.error("deleteAccount failed:", err);
        res.status(500).json({error: "Account deletion failed"});
      }
    },
);
