const {onRequest} = require("firebase-functions/v2/https");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {recomputeRsvpCount, recomputeWeeklyActive} = require("./counters");
const {setGlobalOptions} = require("firebase-functions/v2");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const {createRemoteJWKSet, jwtVerify} = require("jose");
const {
  createUsageCollector,
  buildUsageIncrements,
} = require("./tokenUsage");
const {parseAiRequest, METERED_KINDS} = require("./aiRequest");
const {getAiConfig} = require("./aiConfig");
const {appCheckMode, checkAppCheck} = require("./appCheck");
const {validateSupabaseClaims, isBridgedSession} = require("./supabaseClaims");

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
// olmadığını SUNUCUDAN doğrulamak için. SUPABASE_URL ile aynı yoldan gelir:
// functions/.env dosyasından, yani process.env üzerinden.
//
// NEDEN defineSecret DEĞİL (2026-09-02): anahtar henüz alınmadı ve
// `defineSecret` ile BİLDİRİLEN her secret, hiçbir fonksiyona bağlı olmasa
// bile deploy sırasında değer soruyor; boş geçilemiyor (Secret Manager boş
// payload'ı 400 ile reddediyor). Yani bildirim, anahtar gelene kadar tüm
// deploy'u kilitliyordu.
//
// İSTEĞE BAĞLI: değeri yoksa abonelik doğrulanamaz, yalnız sunucunun kendi
// yazdığı ödül-premium'u (referral) bilinir. Mağaza aboneliği canlıya
// alınmadan ÖNCE doldurulmalı, yoksa parasını ödemiş abone ücretsiz katman
// kotasına takılır ve hiçbir yerde hata görünmez.
//
// Anahtar alınınca iki yol var:
//   a) functions/.env içine REVENUECAT_SECRET_KEY=... yaz (en hızlısı,
//      değer depoda değil ama .env'i görebilen herkes okur),
//   b) `firebase functions:secrets:set REVENUECAT_SECRET_KEY` ile Secret
//      Manager'a koy, burayı defineSecret'a çevir ve anthropicProxy'nin
//      `secrets` listesine ekle (yönetimi daha güvenli olan yol).
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

  // Oturum açmanın ilk adımı: App Check burada ASLA reddetmez (bir
  // yapılandırma hatası kimseyi giriş yapamaz hale getirmesin), yalnız
  // izlenir. Asıl sınır Supabase JWT doğrulaması + aşağıdaki claim kontrolü.
  await checkAppCheck(req, {
    mode: appCheckMode() === "off" ? "off" : "monitor",
    verify: (token) => admin.appCheck().verifyToken(token),
    fn: "mintFirebaseToken",
  });

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

    // aud/role/anonim oturum kontrolü (denetim L-6).
    const claims = validateSupabaseClaims(payload);
    if (!claims.ok) {
      console.warn(JSON.stringify({event: "mint_rejected", reason: claims.reason}));
      res.status(401).json({error: "Invalid Supabase token"});
      return;
    }
    const uid = claims.uid;

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
  const decoded = await admin.auth().verifyIdToken(idToken);
  // Yalnız Supabase köprüsünün ürettiği oturum (denetim H-5).
  if (!isBridgedSession(decoded)) {
    throw new Error("Unsupported sign-in provider");
  }
  return decoded;
}

/**
 * Hassas her ucun ortak kapısı: App Check (moda göre) + kimlik. Başarısızsa
 * yanıtı kendisi yazar ve null döner. Dönen uid DOĞRULANMIŞ token'dan gelir;
 * istek gövdesindeki hiçbir kimlik alanına bakılmaz, yani her uç yalnız
 * çağıranın kendi verisine dokunur.
 * @param {import("firebase-functions/v2/https").Request} req istek
 * @param {import("express").Response} res yanıt
 * @return {Promise<string|null>} uid
 */
async function authorizeCaller(req, res) {
  const appCheck = await checkAppCheck(req, {
    mode: appCheckMode(),
    verify: (token) => admin.appCheck().verifyToken(token),
    fn: process.env.K_SERVICE || "unknown",
  });
  if (!appCheck.ok) {
    res.status(401).json({error: "App Check verification failed"});
    return null;
  }
  try {
    const decoded = await requireFirebaseAuth(req);
    return decoded.uid;
  } catch (err) {
    res.status(401).json({error: "Invalid or missing auth token"});
    return null;
  }
}

// ─── Token muhasebesi ───────────────────────────────────────────────────────

/**
 * Ic ice duz sayilari Firestore artislarina cevirir.
 * @param {object} node sayi ya da ic ice nesne
 * @return {object} FieldValue.increment agaci
 */
function toIncrements(node) {
  const out = {};
  for (const [key, value] of Object.entries(node)) {
    out[key] = typeof value === "number" ?
      admin.firestore.FieldValue.increment(value) :
      toIncrements(value);
  }
  return out;
}

/**
 * Bir cagrinin gercek token kullanimini gunluk dokumana ekler.
 *
 * ai_usage CAGRI sayar, burasi TOKEN sayar: 20 kelimelik bir mesajla 20 bin
 * karakterlik bir yapistirma orada ayni "1 mesaj", faturada 50 kat farkli.
 * Sinir koymadan once gercek dagilimi gormek icin toplaniyor (owner karari
 * 2026-09-01). Kayit hicbir kosulda istegi bozmaz: cagri zaten yanitlandi,
 * buradaki bir hata yalnizca loga duser.
 * @param {string} uid cagiran
 * @param {string} tier "quick" | "deep"
 * @param {string} kind "message" | "food" | "system"
 * @param {object} usage toplanmis token kaydi
 * @return {Promise<void>} yazma sozu
 */
async function recordTokenUsage(uid, tier, kind, usage) {
  if (!usage || (!usage.inputTokens && !usage.outputTokens)) return;
  const day = new Date().toISOString().slice(0, 10);
  try {
    await db.collection("ai_token_usage").doc(`${uid}_${day}`).set({
      uid,
      day,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...toIncrements(buildUsageIncrements({tier, kind, usage})),
    }, {merge: true});
  } catch (err) {
    console.error("recordTokenUsage failed:", err);
  }
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

// Kotadan düşen (kullanıcının bilerek başlattığı) eylem türleri aiRequest.js'te
// (METERED_KINDS). Bunun dışındaki her çağrı "system" sayılır: karşılama,
// günlük yanıtı, hafıza çıkarımı, öneri. Bunlar haftalık kotadan düşmez ama
// artık bedava da değil (denetim C-1, 2026-09-13): `kind` alanını göndermemek
// eskiden tek başına haftalık kotayı atlatıyordu. Üç tavan birlikte çalışır:
//   1. SYSTEM_DAILY_LIMIT: günlük "system" çağrı adedi,
//   2. aiRequest.js: "system" için dar metin bütçesi, görsel yasağı,
//   3. günlük tahmini dolar tavanı (tüm türler, ai_token_usage'dan).
const SYSTEM_DAILY_LIMIT = 80;

// Kullanıcı başı günlük tahmini harcama tavanı (USD). `config/ai.dailyUsdLimit`
// ile konsoldan değiştirilebilir. Yoğun bir premium kullanıcının gerçek
// harcaması bunun çok altında; tavan yalnız kötüye kullanımı keser.
const DEFAULT_DAILY_USD_LIMIT = Number(process.env.AI_DAILY_USD_LIMIT) > 0 ?
  Number(process.env.AI_DAILY_USD_LIMIT) :
  5;

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
    const systemUsed = dayCounts.system || 0;
    if (kind === "system" && systemUsed >= SYSTEM_DAILY_LIMIT) {
      return {allowed: false, reason: "daily-system-limit"};
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
    if (kind === "system") dayCounts.system = systemUsed + 1;
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
  const key = REVENUECAT_SECRET_KEY;
  if (!key) return false;
  try {
    const res = await fetch(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
        {
          headers: {
            "Authorization": `Bearer ${key}`,
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

// Girdi doğrulaması (boyut, blok izin listesi, görsel, metin bütçesi)
// aiRequest.js'te: saf fonksiyon, emülatörsüz test edilir.

/**
 * Kullanıcının bugünkü tahmini AI harcaması tavanı aştı mı?
 * ai_token_usage her çağrıdan SONRA yazılır, yani tavan en fazla bir çağrı
 * kadar aşılabilir; kötüye kullanımı kesmek için yeterli.
 * @param {string} uid Firebase uid
 * @param {number} limitUsd tavan
 * @return {Promise<boolean>} true ise çağrı reddedilmeli
 */
async function dailySpendExceeded(uid, limitUsd) {
  const day = new Date().toISOString().slice(0, 10);
  try {
    const snap = await db.collection("ai_token_usage").doc(`${uid}_${day}`).get();
    const spent = snap.exists ? Number((snap.data() || {}).estimatedUsd) || 0 : 0;
    return spent >= limitUsd;
  } catch (err) {
    console.warn("dailySpendExceeded read failed:", err.message || err);
    return false;
  }
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
    // RevenueCat anahtarı burada YOK: process.env üzerinden geliyor (bkz.
    // dosyanın başındaki not). Secret Manager'a taşınırsa bu listeye de
    // eklenmeli, çünkü resolvePremium ücretsiz katman kotasını bu
    // fonksiyonun içinde uyguluyor.
    {cors: true, secrets: [ANTHROPIC_API_KEY]},
    async (req, res) => {
      if (req.method !== "POST") {
        res.status(405).json({error: "Method Not Allowed"});
        return;
      }

      const uid = await authorizeCaller(req, res);
      if (!uid) return;

      // Girdi kapısı: yalnız bilinen alanlar ve blok türleri geçer; iletilen
      // gövde istemcinin nesnesinden değil bu temiz kopyadan kurulur. Model
      // ve max_tokens her zaman sunucudaki TIER_CONFIG'den gelir.
      const parsed = parseAiRequest(req.body, {
        rawBytes: req.rawBody ? req.rawBody.length : undefined,
        tiers: Object.keys(TIER_CONFIG),
      });
      if (!parsed.ok) {
        res.status(parsed.status).json({error: parsed.error});
        return;
      }
      const {tier, kind, system, messages} = parsed;
      const config = TIER_CONFIG[tier];

      // Acil durum anahtarı ve günlük dolar tavanı (config/ai).
      const aiConfig = await getAiConfig(db);
      if (aiConfig.enabled === false) {
        res.status(503).json({
          error: "AI is temporarily unavailable",
          reason: "ai-disabled",
        });
        return;
      }
      const usdLimit = Number(aiConfig.dailyUsdLimit) > 0 ?
        Number(aiConfig.dailyUsdLimit) :
        DEFAULT_DAILY_USD_LIMIT;
      if (await dailySpendExceeded(uid, usdLimit)) {
        res.status(429).json({
          error: "Daily AI usage limit reached",
          reason: "daily-cost-limit",
          kind,
        });
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

      // stream=true: yanit parca parca aksin. Akissiz cagrida kullanici
      // cevabin SONU gelene kadar bos balona bakiyor; Sonnet'te bu birkac
      // saniye. Akista ilk kelime saniyenin altinda ekranda oluyor ve model,
      // kalite, kota ayni kaliyor.
      const wantsStream = parsed.stream;
      const usageCollector = createUsageCollector();

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
            ...(wantsStream ? {stream: true} : {}),
          }),
        });

        // Hata govdesi JSON'dur (429 kota, 400 gecersiz istek): istemcinin
        // paywall ayrimi buna bakiyor, akisa cevirmeden aynen gecir.
        if (!wantsStream || upstream.status !== 200) {
          const data = await upstream.json();
          res.status(upstream.status).json(data);
          usageCollector.feedJson(data);
          await recordTokenUsage(uid, tier, kind, usageCollector.result());
          return;
        }

        // Akis: Anthropic'in SSE govdesi oldugu gibi istemciye tasinir.
        // Ara katman parse etmez; parse istemcide, tek yerde.
        res.status(200);
        res.setHeader("Content-Type", "text/event-stream; charset=utf-8");
        res.setHeader("Cache-Control", "no-cache, no-transform");
        res.setHeader("Connection", "keep-alive");
        if (typeof res.flushHeaders === "function") {
          res.flushHeaders();
        }

        const reader = upstream.body.getReader();
        const decoder = new TextDecoder();
        for (;;) {
          const {done, value} = await reader.read();
          if (done) break;
          // Once istemciye yaz, sonra muhasebe: olcum kullaniciyi
          // bekletmemeli.
          res.write(Buffer.from(value));
          usageCollector.feedSse(decoder.decode(value, {stream: true}));
        }
        res.end();
        await recordTokenUsage(uid, tier, kind, usageCollector.result());
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

  const uid = await authorizeCaller(req, res);
  if (!uid) return;

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

      const uid = await authorizeCaller(req, res);
      if (!uid) return;

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

// ─── Adan: ada öğeleri (ADR-0006) ───────────────────────────────────────────

/**
 * Öğe eşikleri — TEK KARAR YERİ. İstemcideki `adan_model.dart` kopyası
 * yalnız gösterim içindir ("nasıl kazanılır" satırı); kazanımı burası verir.
 *
 * `metric` alanları aşağıdaki `collectIslandMetrics` çıktısına karşılık gelir.
 * `serverVerifiable: false` olanlar listede kilitli görünür ama hiç
 * kazanılmaz — kaynakları henüz sunucudan okunamıyor (bkz. ADR-0006 §3).
 */
const ISLAND_ITEMS = [
  {id: "lantern", metric: "journalCount", threshold: 1, serverVerifiable: true},
  {id: "pine", metric: "streakDays", threshold: 3, serverVerifiable: true},
  {id: "oven", metric: "mealCount", threshold: 10, serverVerifiable: true},
  {id: "windrose", metric: "streakDays", threshold: 7, serverVerifiable: true},
  {id: "moonlight", metric: "nightRituals", threshold: 1,
    serverVerifiable: true},
  {id: "meetingStone", metric: "meetups", threshold: 1,
    serverVerifiable: true},
];

/** @return {string} bugünün YYYY-MM-DD karşılığı (UTC). */
function islandDateKey(date) {
  return date.toISOString().slice(0, 10);
}

/**
 * Kullanıcının kendi verisinden kazanım ölçütlerini toplar. Hepsi Admin SDK
 * ile okunur — istemcinin gönderdiği hiçbir sayıya güvenilmez.
 * @param {string} uid kullanıcı kimliği
 * @return {Promise<Object<string, number>>} ölçüt adı -> değer
 */
async function collectIslandMetrics(uid) {
  const userRef = db.collection("users").doc(uid);

  const [
    journalAgg, foodAgg, checkinSnap, ritualAgg, rsvpAgg,
    lastFoodSnap, lastRitualSnap,
  ] = await Promise.all([
    userRef.collection("journal_entries").count().get(),
    userRef.collection("food_entries").count().get(),
    // Seri hesabı için son 60 günün check-in'leri yeter: en uzun eşik 7 gün.
    db.collection("daily_checkins").where("userId", "==", uid).get(),
    // Gece ritüeli: gün başına tek doküman (istemci deterministik id yazar).
    userRef.collection("sleep_rituals").count().get(),
    // RSVP'ler events/{id}/rsvps/{uid} altında; collectionGroup + userId
    // alanı tek indeksle sayılabiliyor (firestore.indexes.json).
    db.collectionGroup("rsvps").where("userId", "==", uid).count().get(),
    // Son etkinlik için iki hafif okuma. Öğün ve gece ritüeli check-in
    // yazmıyor; yalnız check-in'e bakmak, yemeğini yazıp günlük tutmayan
    // kullanıcının suyunu haksız yere koyulaştırırdı.
    userRef.collection("food_entries")
        .orderBy("createdAt", "desc").limit(1).get(),
    userRef.collection("sleep_rituals")
        .orderBy("date", "desc").limit(1).get(),
  ]);

  const dates = new Set();
  checkinSnap.docs.forEach((d) => {
    const date = (d.data() || {}).date;
    if (typeof date === "string") dates.add(date);
  });

  // Bugünden geriye kesintisiz gün sayısı. Bugün yoksa dünden başlar —
  // gün ortasında seriyi sıfırlamak cezalandırmak olurdu (ses tonu §6).
  let streakDays = 0;
  const cursor = new Date();
  if (!dates.has(islandDateKey(cursor))) {
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  while (dates.has(islandDateKey(cursor)) && streakDays < 400) {
    streakDays += 1;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }

  // Son etkin gün: check-in'lerin en yenisi, son öğün ve son gece ritüeli
  // arasından en geç olan. YYYY-MM-DD dizeleri sözlük sırasıyla
  // karşılaştırılabildiği için ayrıca tarihe çevirmeye gerek yok.
  const activeDays = [...dates];
  const lastFood = lastFoodSnap.docs[0];
  if (lastFood) {
    const createdAt = (lastFood.data() || {}).createdAt;
    if (createdAt && typeof createdAt.toDate === "function") {
      activeDays.push(islandDateKey(createdAt.toDate()));
    }
  }
  const lastRitual = lastRitualSnap.docs[0];
  if (lastRitual) {
    const date = (lastRitual.data() || {}).date;
    if (typeof date === "string") activeDays.push(date);
  }
  activeDays.sort();

  return {
    journalCount: journalAgg.data().count || 0,
    mealCount: foodAgg.data().count || 0,
    streakDays,
    nightRituals: ritualAgg.data().count || 0,
    meetups: rsvpAgg.data().count || 0,
    lastActiveDate: activeDays.length > 0 ?
      activeDays[activeDays.length - 1] : null,
  };
}

/**
 * Adayı senkronize eder: kazanılmış öğeleri hesaplar, YENİ olanları yazar.
 *
 * İdempotent ve toplayıcıdır — kazanılmış bir öğe ASLA geri alınmaz
 * (handoff §7: sessiz geçen günler cezalandırmaz). Bu yüzden fonksiyon
 * yalnız ekler; eşiğin altına düşmek bir öğeyi silmez.
 *
 * İstek: POST, header "Authorization: Bearer <firebase_id_token>"
 */
exports.syncIslandItems = onRequest({cors: true}, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({error: "Method Not Allowed"});
    return;
  }

  const uid = await authorizeCaller(req, res);
  if (!uid) return;

  try {
    const metrics = await collectIslandMetrics(uid);
    const ref = db.collection("island").doc(uid);
    const snap = await ref.get();
    const existing = (snap.exists ? snap.data() : null) || {};
    const earned = Array.isArray(existing.earned) ? existing.earned : [];

    const nextEarned = earned.slice();
    for (const item of ISLAND_ITEMS) {
      if (!item.serverVerifiable) continue;
      if (nextEarned.includes(item.id)) continue;
      if ((metrics[item.metric] || 0) >= item.threshold) {
        nextEarned.push(item.id);
      }
    }

    const gained = nextEarned.filter((id) => !earned.includes(id));
    // Su, son etkin günden bu yana koyulaşır (handoff §7). Gün DİZESİ
    // yazılır, gün SAYISI değil: sayı iki senkron arasında bayatlar, dize
    // bayatlamaz — istemci farkı kendi alır.
    const lastActiveDate = metrics.lastActiveDate || null;
    const dateChanged = (existing.lastActiveDate || null) !== lastActiveDate;
    if (gained.length > 0 || dateChanged || !snap.exists) {
      await ref.set({
        uid,
        earned: nextEarned,
        lastActiveDate,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    res.json({earned: nextEarned, gained, metrics});
  } catch (err) {
    console.error("syncIslandItems failed:", err);
    res.status(500).json({error: "Internal error"});
  }
});

// ─── Toplu sayaçlar (denetim H-1/H-6) ───────────────────────────────────────

/**
 * RSVP eklenince/silinince etkinliğin katılımcı sayısını yeniden hesaplar.
 * RSVP listesi artık istemciye kapalı; sayı events/{id}.rsvpCount'ta.
 */
exports.onRsvpWritten = onDocumentWritten(
    "events/{eventId}/rsvps/{userId}",
    async (event) => {
      await recomputeRsvpCount(db, event.params.eventId);
    },
);

/**
 * Sosyal kanıt rozetinin "bu hafta N kişi" sayısı. daily_checkins artık
 * istemciye kapalı; saatte bir count() ile (1000 dizin girdisi başına 1
 * okuma) public_stats/weekly_active'e yazılır.
 */
exports.weeklyActiveStats = onSchedule(
    {schedule: "every 60 minutes", timeZone: "Etc/UTC"},
    async () => {
      await recomputeWeeklyActive(db);
    },
);
