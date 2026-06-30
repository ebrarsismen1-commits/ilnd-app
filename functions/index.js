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
    console.error("mintFirebaseToken failed:", err);
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

const TIER_CONFIG = {
  quick: {model: "claude-haiku-4-5", maxTokens: 512, dailyLimit: 300},
  deep: {model: "claude-sonnet-4-6", maxTokens: 1024, dailyLimit: 60},
};

/**
 * Checks and atomically increments the caller's daily AI usage counter for
 * [tier]. Storing the cap server-side (keyed on Firebase uid, not a client
 * value) is what makes this unbypassable by clearing local app storage.
 * @param {string} uid Firebase uid of the caller
 * @param {string} tier "quick" or "deep"
 * @return {Promise<boolean>} true if the call is allowed, false if capped
 */
async function checkAndIncrementUsage(uid, tier) {
  const day = new Date().toISOString().slice(0, 10);
  const ref = db.collection("ai_usage").doc(`${uid}_${day}`);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const counts = snap.exists ? (snap.data().counts || {}) : {};
    const used = counts[tier] || 0;
    if (used >= TIER_CONFIG[tier].dailyLimit) return false;
    counts[tier] = used + 1;
    tx.set(ref, {
      uid,
      day,
      counts,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
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
exports.anthropicProxy = onRequest(
    {cors: true, secrets: [ANTHROPIC_API_KEY], enforceAppCheck: true},
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

      let allowed;
      try {
        allowed = await checkAndIncrementUsage(uid, tier);
      } catch (err) {
        console.error("anthropicProxy usage check failed:", err);
        res.status(500).json({error: "Internal error"});
        return;
      }
      if (!allowed) {
        res.status(429).json({error: "Daily AI usage limit reached"});
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
            system: typeof system === "string" ? system : undefined,
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
exports.redeemReferralCode = onRequest(
    {cors: true, enforceAppCheck: true},
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
exports.deleteAccount = onRequest(
    {cors: true, secrets: [SUPABASE_SERVICE_ROLE_KEY], enforceAppCheck: true},
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
