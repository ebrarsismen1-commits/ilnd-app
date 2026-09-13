/**
 * Davet kodları ve ödülleri — tamamı sunucuda.
 *
 * Güvenlik denetimi H-4 (2026-09-13):
 *   1. Kod istemcide üretilip `user_growth/{uid}`'e istemcinin kendisi
 *      yazıyordu. Kurallar kodun biçimini/benzersizliğini denetleyemiyordu:
 *      biri başkasının herkese paylaştığı kodu kendi dokümanına yazabiliyor,
 *      redeem `where(referral_code == kod).limit(1)` ile rastgele birini
 *      seçtiği için ödülü çalabiliyordu.
 *   2. Her yeni hesap davet edenin premium süresine +7 gün ekliyordu, tavan
 *      yoktu: tek kullanımlık e-postalarla sınırsız premium üretilebiliyordu.
 *   3. Kodu henüz oluşmadan davet kodu kullanan kişinin dokümanını redeem
 *      yaratıyor, istemcinin sonraki yazması "update" sayılıp reddediliyordu:
 *      o kişi bir daha hiç kendi kodunu alamıyordu.
 *
 * Çözüm:
 *   - `referral_codes/{code}` → {uid} eşlemesi yalnız burada, transaction
 *     içinde yaratılır. Kod benzersizliği doküman kimliğiyle garanti.
 *   - İstemci user_growth ve referral_codes'a hiç yazamaz (firestore.rules).
 *   - Ödül tavanı: davet eden başına 30 günde en fazla 3 ödüllü davet ve
 *     premium bitiş tarihi hiçbir zaman "şimdi + 30 gün"ü geçmez. Tavandaki
 *     davet yine kaydedilir ve davet edilen kişi için kod "kullanıldı" olur;
 *     yalnız ödül verilmez.
 */

const crypto = require("crypto");
const admin = require("firebase-admin");

const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 0/O, 1/I/L yok
const CODE_LENGTH = 8;
// Eski istemci 6 karakterli kod üretiyordu; onlar geçerli kalır.
const CODE_PATTERN = /^[A-Z0-9]{6,12}$/;

const REFERRAL_REWARD_DAYS = 7;
const MAX_REWARDS_PER_WINDOW = 3;
const REWARD_WINDOW_DAYS = 30;
const MAX_REWARD_HORIZON_DAYS = 30;
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * @param {function(number): number} [randomInt] test için
 * @return {string} yeni kod
 */
function randomReferralCode(randomInt = crypto.randomInt) {
  let code = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  }
  return code;
}

/**
 * @param {unknown} raw istemciden gelen kod
 * @return {string|null} büyük harfe çevrilmiş geçerli kod ya da null
 */
function normalizeCode(raw) {
  if (typeof raw !== "string") return null;
  const code = raw.trim().toUpperCase();
  return CODE_PATTERN.test(code) ? code : null;
}

/**
 * Eşlemesi olmayan eski bir kodu birden fazla doküman taşıyorsa asıl sahibi
 * seçer: en ERKEN oluşturulan. Karar verilemiyorsa (zaman damgası eksik,
 * eşitlik) kimse seçilmez — yanlış kişiye ödül vermektense kod kullanılamaz.
 * @param {Array<FirebaseFirestore.QueryDocumentSnapshot>} docs adaylar
 * @return {FirebaseFirestore.QueryDocumentSnapshot|null} sahip
 */
function pickLegacyOwner(docs) {
  if (docs.length === 0) return null;
  if (docs.length === 1) return docs[0];
  const stamped = docs.map((d) => {
    const at = (d.data() || {}).created_at;
    return {doc: d, ms: at && typeof at.toMillis === "function" ? at.toMillis() : null};
  });
  if (stamped.some((s) => s.ms === null)) return null;
  stamped.sort((a, b) => a.ms - b.ms);
  if (stamped[0].ms === stamped[1].ms) return null;
  return stamped[0].doc;
}

/**
 * Kullanıcının davet kodunu döner; yoksa benzersiz bir kod ayırır. İdempotent.
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} uid doğrulanmış çağıran
 * @param {{randomCode?: function(): string, maxAttempts?: number}} [opts] test için
 * @return {Promise<string>} kod
 */
async function ensureReferralCodeFor(db, uid, opts = {}) {
  const randomCode = opts.randomCode || randomReferralCode;
  const maxAttempts = opts.maxAttempts || 6;
  const {FieldValue} = admin.firestore;
  const growthCol = db.collection("user_growth");
  const codesCol = db.collection("referral_codes");

  return db.runTransaction(async (tx) => {
    // Transaction'da TÜM okumalar yazmalardan önce gelir; yazmalar biriktirilir.
    const growthRef = growthCol.doc(uid);
    const growthSnap = await tx.get(growthRef);
    const growth = growthSnap.exists ? (growthSnap.data() || {}) : {};
    const pending = [];

    const current = normalizeCode(growth.referral_code);
    if (current) {
      const mapRef = codesCol.doc(current);
      const mapSnap = await tx.get(mapRef);
      if (mapSnap.exists) {
        if ((mapSnap.data() || {}).uid === uid) return current;
        // Kod başkasına ait (ya da kullanımdan kaldırılmış): yeni kod ver.
      } else {
        // Eski, eşlemesiz kod. Aynı kodu taşıyan başka doküman var mı?
        const dup = await tx.get(growthCol.where("referral_code", "==", current).limit(3));
        const owner = pickLegacyOwner(dup.docs);
        if (owner && owner.id === uid) {
          tx.set(mapRef, {uid, legacy: true, createdAt: FieldValue.serverTimestamp()});
          return current;
        }
        pending.push(() => tx.set(mapRef, owner ?
          {uid: owner.id, legacy: true, createdAt: FieldValue.serverTimestamp()} :
          {uid: null, retired: true, createdAt: FieldValue.serverTimestamp()}));
      }
    }

    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      const code = randomCode();
      const mapRef = codesCol.doc(code);
      const mapSnap = await tx.get(mapRef);
      if (mapSnap.exists) continue;

      pending.forEach((write) => write());
      tx.set(mapRef, {uid, createdAt: FieldValue.serverTimestamp()});
      const data = {referral_code: code};
      // Yalnız EKSİK alanlar varsayılanla doldurulur: redeem'in yazdığı
      // referred_by_code ya da kazanılmış ödül ezilmesin.
      if (growth.founding_member === undefined) data.founding_member = false;
      if (growth.premium_access_until === undefined) data.premium_access_until = null;
      if (growth.referred_by_code === undefined) data.referred_by_code = null;
      if (growth.created_at === undefined) data.created_at = FieldValue.serverTimestamp();
      tx.set(growthRef, data, {merge: true});
      return code;
    }
    throw new Error("Could not allocate a unique referral code");
  });
}

/**
 * Davet kodunu kullanır.
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} uid doğrulanmış çağıran (davet edilen)
 * @param {unknown} rawCode istemciden gelen kod
 * @param {{now?: number}} [opts] test için
 * @return {Promise<{status: number, body: object}>} HTTP yanıtı
 */
async function redeemReferral(db, uid, rawCode, opts = {}) {
  const code = normalizeCode(rawCode);
  if (!code) return {status: 400, body: {error: "Invalid code"}};

  const now = opts.now || Date.now();
  const {FieldValue, Timestamp} = admin.firestore;
  const growthCol = db.collection("user_growth");
  const mapRef = db.collection("referral_codes").doc(code);

  const body = await db.runTransaction(async (tx) => {
    const myRef = growthCol.doc(uid);
    const mySnap = await tx.get(myRef);
    if (mySnap.exists && (mySnap.data() || {}).referred_by_code) {
      return {redeemed: false, reason: "already-redeemed"};
    }

    const mapSnap = await tx.get(mapRef);
    let mapping = mapSnap.exists ? (mapSnap.data() || {}) : null;
    let createMapping = false;
    if (!mapping) {
      // Eşlemesi olmayan eski kod: sahibini güvenle belirleyebiliyorsak kullan.
      const legacy = await tx.get(growthCol.where("referral_code", "==", code).limit(3));
      const owner = pickLegacyOwner(legacy.docs);
      if (!owner) return {redeemed: false, reason: "invalid-code"};
      mapping = {uid: owner.id, legacy: true};
      createMapping = true;
    }
    if (!mapping.uid) return {redeemed: false, reason: "invalid-code"};

    const referrerId = mapping.uid;
    if (referrerId === uid) return {redeemed: false, reason: "self-referral"};

    const referrerRef = growthCol.doc(referrerId);
    const referrerSnap = await tx.get(referrerRef);
    const referrer = referrerSnap.exists ? (referrerSnap.data() || {}) : {};

    // ── Okumalar bitti, yazmalar ──
    const windowStart = Number(mapping.rewardWindowStartMs) || 0;
    const windowOpen = windowStart > 0 && now - windowStart < REWARD_WINDOW_DAYS * DAY_MS;
    const usedInWindow = windowOpen ? (Number(mapping.rewardsInWindow) || 0) : 0;
    const rewarded = usedInWindow < MAX_REWARDS_PER_WINDOW;

    tx.set(db.collection("referrals").doc(), {
      referrer_id: referrerId,
      referred_id: uid,
      referral_code: code,
      status: rewarded ? "completed" : "capped",
      reward_claimed: rewarded,
      created_at: FieldValue.serverTimestamp(),
    });
    tx.set(myRef, {referred_by_code: code}, {merge: true});

    const mappingWrite = createMapping ?
      {uid: referrerId, legacy: true, createdAt: FieldValue.serverTimestamp()} :
      {};
    if (rewarded) {
      const until = referrer.premium_access_until;
      const currentMs = until && typeof until.toMillis === "function" ? until.toMillis() : 0;
      const base = Math.max(currentMs, now);
      const capped = Math.min(base + REFERRAL_REWARD_DAYS * DAY_MS, now + MAX_REWARD_HORIZON_DAYS * DAY_MS);
      // Mevcut hak asla kısaltılmaz (tavan öncesinden kalma uzun süre dahil).
      const newUntilMs = Math.max(currentMs, capped);
      tx.set(referrerRef, {
        founding_member: true,
        premium_access_until: Timestamp.fromMillis(newUntilMs),
      }, {merge: true});
      mappingWrite.rewardWindowStartMs = windowOpen ? windowStart : now;
      mappingWrite.rewardsInWindow = usedInWindow + 1;
    }
    if (Object.keys(mappingWrite).length > 0) {
      tx.set(mapRef, mappingWrite, {merge: true});
    }

    return {redeemed: true, referrerRewarded: rewarded};
  });

  return {status: 200, body};
}

module.exports = {
  CODE_PATTERN,
  MAX_REWARDS_PER_WINDOW,
  MAX_REWARD_HORIZON_DAYS,
  REFERRAL_REWARD_DAYS,
  REWARD_WINDOW_DAYS,
  ensureReferralCodeFor,
  normalizeCode,
  pickLegacyOwner,
  randomReferralCode,
  redeemReferral,
};
