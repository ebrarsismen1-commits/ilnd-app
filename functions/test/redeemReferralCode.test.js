/**
 * Runs against the Firebase Emulator Suite (Firestore + Auth) — see
 * functions/package.json's `test` script. `firebase emulators:exec` sets
 * FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST before this file
 * loads, which is what makes `admin.initializeApp()` in index.js talk to
 * the emulators instead of production.
 *
 * Güvenlik denetimi H-4 (2026-09-13): kod gaspı, sınırsız premium uzatma,
 * sunucuda kod ayırma ve "önce davet kodu kullanan kendi kodunu alamıyor"
 * hatası için regresyonlar da burada.
 */
const admin = require("firebase-admin");
const httpMocks = require("node-mocks-http");
const {getIdTokenForUid, getAppCheckHeaderForTests} = require("./helpers");

const myFunctions = require("../index");
const {
  CODE_PATTERN,
  MAX_REWARDS_PER_WINDOW,
  MAX_REWARD_HORIZON_DAYS,
  ensureReferralCodeFor,
  redeemReferral,
} = require("../referrals");

const db = admin.firestore();
const DAY = 24 * 60 * 60 * 1000;

jest.setTimeout(30000);

/**
 * Invokes a handler directly with a mocked req/res pair.
 * @param {string} fn exported function name
 * @param {string|null} idToken Bearer token, or null to omit the header.
 * @param {object} body request JSON body.
 * @return {Promise<{statusCode: number, body: object}>}
 */
async function call(fn, idToken, body = {}) {
  const req = httpMocks.createRequest({
    method: "POST",
    headers: {
      ...(idToken ? {authorization: `Bearer ${idToken}`} : {}),
      ...(await getAppCheckHeaderForTests()),
    },
    body,
  });
  const res = httpMocks.createResponse({eventEmitter: require("events").EventEmitter});
  await myFunctions[fn](req, res);
  return {statusCode: res.statusCode, body: res._getJSONData()};
}

const callRedeem = (idToken, body) => call("redeemReferralCode", idToken, body);

/**
 * Sunucunun ayırdığı biçimde bir davet eden kurar: user_growth + eşleme.
 * @param {string} uid davet eden
 * @param {string} code kod
 * @param {object} [growth] user_growth ek alanları
 * @param {object} [mapping] referral_codes ek alanları
 */
async function seedReferrer(uid, code, growth = {}, mapping = {}) {
  await db.collection("user_growth").doc(uid).set({
    referral_code: code,
    founding_member: false,
    premium_access_until: null,
    referred_by_code: null,
    ...growth,
  });
  await db.collection("referral_codes").doc(code).set({uid, ...mapping});
}

const untilMs = async (uid) => {
  const d = (await db.collection("user_growth").doc(uid).get()).data();
  return d.premium_access_until ? d.premium_access_until.toMillis() : null;
};

describe("redeemReferralCode", () => {
  afterEach(async () => {
    for (const name of ["user_growth", "referrals", "referral_codes"]) {
      const snap = await db.collection(name).get();
      await Promise.all(snap.docs.map((d) => d.ref.delete()));
    }
  });

  test("rejects requests with no bearer token", async () => {
    const res = await callRedeem(null, {code: "ABCDEF"});
    expect(res.statusCode).toBe(401);
  });

  test("rejects a request missing a code", async () => {
    const idToken = await getIdTokenForUid("redeemer-1");
    const res = await callRedeem(idToken, {});
    expect(res.statusCode).toBe(400);
  });

  test.each([["çok kısa", "AB"], ["yol karakteri", "ABC/DEF"], ["çok uzun", "A".repeat(40)], ["nesne", {x: 1}]])(
      "biçimi bozuk kod (%s) 400 döner", async (_, code) => {
        const idToken = await getIdTokenForUid("redeemer-bad");
        const res = await callRedeem(idToken, {code});
        expect(res.statusCode).toBe(400);
      });

  test("rejects an invalid/unknown code", async () => {
    const idToken = await getIdTokenForUid("redeemer-2");
    const res = await callRedeem(idToken, {code: "NOTREAL"});
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({redeemed: false, reason: "invalid-code"});
  });

  test("rejects a user redeeming their own code (self-referral)", async () => {
    await seedReferrer("self-referrer", "SELF01");
    const idToken = await getIdTokenForUid("self-referrer");
    const res = await callRedeem(idToken, {code: "SELF01"});
    expect(res.body).toEqual({redeemed: false, reason: "self-referral"});
  });

  test("grants the referrer a 7-day premium reward on a valid redemption", async () => {
    await seedReferrer("referrer-1", "GIFT01");

    const idToken = await getIdTokenForUid("referee-1");
    const res = await callRedeem(idToken, {code: "gift01"}); // büyük/küçük harf duyarsız

    expect(res.body).toEqual({redeemed: true, referrerRewarded: true});

    const referrerDoc = await db.collection("user_growth").doc("referrer-1").get();
    expect(referrerDoc.data().founding_member).toBe(true);
    expect(referrerDoc.data().premium_access_until).not.toBeNull();

    const refereeDoc = await db.collection("user_growth").doc("referee-1").get();
    expect(refereeDoc.data().referred_by_code).toBe("GIFT01");

    const referrals = await db.collection("referrals").where("referred_id", "==", "referee-1").get();
    expect(referrals.size).toBe(1);
    expect(referrals.docs[0].data()).toMatchObject({referrer_id: "referrer-1", status: "completed", reward_claimed: true});
  });

  test("does not let the same user redeem twice (double-redemption guard)", async () => {
    await seedReferrer("referrer-2", "ONCE01");
    await db.collection("user_growth").doc("referee-2").set({referred_by_code: "ONCE01"});

    const idToken = await getIdTokenForUid("referee-2");
    const res = await callRedeem(idToken, {code: "ONCE01"});

    expect(res.body).toEqual({redeemed: false, reason: "already-redeemed"});
  });

  test("aynı kişinin eşzamanlı iki denemesinden yalnız biri sayılır", async () => {
    await seedReferrer("referrer-race", "RACE0001");
    const idToken = await getIdTokenForUid("referee-race");

    const results = await Promise.all([
      callRedeem(idToken, {code: "RACE0001"}),
      callRedeem(idToken, {code: "RACE0001"}),
    ]);

    expect(results.filter((r) => r.body.redeemed === true)).toHaveLength(1);
    const rows = await db.collection("referrals").where("referred_id", "==", "referee-race").get();
    expect(rows.size).toBe(1);
  });

  test("extends (does not overwrite) an already-active premium reward", async () => {
    const now = Date.now();
    await seedReferrer("referrer-3", "STACK01", {
      founding_member: true,
      premium_access_until: admin.firestore.Timestamp.fromMillis(now + 3 * DAY),
    });

    const idToken = await getIdTokenForUid("referee-3");
    await callRedeem(idToken, {code: "STACK01"});

    // 3 gün kalan + 7 gün ödül ≈ 10 gün.
    expect(await untilMs("referrer-3")).toBeGreaterThan(now + 9 * DAY);
  });

  test("is not exploitable by writing founding_member directly from a client-like call", async () => {
    await seedReferrer("referrer-4", "TRUST01");

    const idToken = await getIdTokenForUid("referee-4");
    await callRedeem(idToken, {
      code: "TRUST01",
      founding_member: true,
      premium_access_until: "2099-01-01",
    });

    const refereeDoc = await db.collection("user_growth").doc("referee-4").get();
    expect(refereeDoc.data().founding_member).toBeUndefined();
    expect(refereeDoc.data().premium_access_until).toBeUndefined();
  });

  // ── H-4: kod gaspı ───────────────────────────────────────────────────────
  describe("kod gaspı", () => {
    test("eşleme varsa aynı kodu kendi dokümanına yazmış gaspçı ödül alamaz", async () => {
      await seedReferrer("victim-1", "SHARED01");
      // Eski kuralların izin verdiği gasp: aynı kod başka bir dokümanda.
      await db.collection("user_growth").doc("aaa-squatter").set({referral_code: "SHARED01"});

      const idToken = await getIdTokenForUid("referee-squat-1");
      await callRedeem(idToken, {code: "SHARED01"});

      expect(await untilMs("victim-1")).not.toBeNull();
      const squatter = (await db.collection("user_growth").doc("aaa-squatter").get()).data();
      expect(squatter.premium_access_until).toBeUndefined();
    });

    test("eşlemesiz eski kodda EN ERKEN oluşturulan sahip ödüllendirilir ve eşleme kurulur", async () => {
      const {Timestamp} = admin.firestore;
      await db.collection("user_growth").doc("zzz-victim").set({
        referral_code: "LEGACY01", created_at: Timestamp.fromMillis(Date.now() - 10 * DAY),
      });
      await db.collection("user_growth").doc("aaa-squatter").set({
        referral_code: "LEGACY01", created_at: Timestamp.fromMillis(Date.now() - DAY),
      });

      const idToken = await getIdTokenForUid("referee-legacy");
      const res = await callRedeem(idToken, {code: "LEGACY01"});

      expect(res.body.redeemed).toBe(true);
      expect(await untilMs("zzz-victim")).not.toBeNull();
      expect((await db.collection("user_growth").doc("aaa-squatter").get()).data().premium_access_until).toBeUndefined();
      expect((await db.collection("referral_codes").doc("LEGACY01").get()).data().uid).toBe("zzz-victim");
    });

    test("sahibi belirlenemeyen eski kod kimseye ödül vermez", async () => {
      await db.collection("user_growth").doc("x1").set({referral_code: "AMBIG001"});
      await db.collection("user_growth").doc("x2").set({referral_code: "AMBIG001"});

      const idToken = await getIdTokenForUid("referee-ambig");
      const res = await callRedeem(idToken, {code: "AMBIG001"});

      expect(res.body).toEqual({redeemed: false, reason: "invalid-code"});
    });
  });

  // ── H-4: ödül tavanları ──────────────────────────────────────────────────
  describe("ödül tavanları", () => {
    test(`davet eden başına 30 günde en fazla ${MAX_REWARDS_PER_WINDOW} ödül; fazlası kaydedilir ama ödül vermez`, async () => {
      await seedReferrer("farmer", "FARM0001");

      const outcomes = [];
      for (let i = 0; i < 10; i++) {
        const idToken = await getIdTokenForUid(`sybil-${i}`);
        outcomes.push((await callRedeem(idToken, {code: "FARM0001"})).body);
      }

      expect(outcomes.every((b) => b.redeemed === true)).toBe(true);
      expect(outcomes.filter((b) => b.referrerRewarded).length).toBe(MAX_REWARDS_PER_WINDOW);
      const capped = await db.collection("referrals").where("status", "==", "capped").get();
      expect(capped.size).toBe(10 - MAX_REWARDS_PER_WINDOW);
      // Davet edilenlerin hepsi için kod "kullanıldı" (tekrar denenemez).
      const sybil9 = (await db.collection("user_growth").doc("sybil-9").get()).data();
      expect(sybil9.referred_by_code).toBe("FARM0001");
    });

    test("premium bitişi hiçbir zaman şimdi + 30 günü geçmez", async () => {
      const now = Date.now();
      await seedReferrer("near-cap", "HORIZON1", {
        premium_access_until: admin.firestore.Timestamp.fromMillis(now + 28 * DAY),
      });
      const idToken = await getIdTokenForUid("referee-horizon");
      await redeemReferral(db, "referee-horizon", "HORIZON1", {now});
      expect(await untilMs("near-cap")).toBe(now + MAX_REWARD_HORIZON_DAYS * DAY);
      expect(idToken).toBeTruthy();
    });

    test("tavan öncesinden kalan uzun süre kısaltılmaz", async () => {
      const now = Date.now();
      const farmedUntil = now + 200 * DAY;
      await seedReferrer("old-farmer", "OLDFARM1", {
        premium_access_until: admin.firestore.Timestamp.fromMillis(farmedUntil),
      });
      await redeemReferral(db, "referee-old", "OLDFARM1", {now});
      expect(await untilMs("old-farmer")).toBe(farmedUntil);
    });

    test("30 günlük pencere dolunca sayaç yeniden başlar", async () => {
      const now = Date.now();
      await seedReferrer("window", "WINDOW01", {}, {
        rewardWindowStartMs: now - 31 * DAY,
        rewardsInWindow: MAX_REWARDS_PER_WINDOW,
      });
      const {body} = await redeemReferral(db, "referee-window", "WINDOW01", {now});
      expect(body).toEqual({redeemed: true, referrerRewarded: true});
      const mapping = (await db.collection("referral_codes").doc("WINDOW01").get()).data();
      expect(mapping).toMatchObject({rewardWindowStartMs: now, rewardsInWindow: 1, uid: "window"});
    });
  });
});

describe("ensureReferralCode", () => {
  afterEach(async () => {
    for (const name of ["user_growth", "referrals", "referral_codes"]) {
      const snap = await db.collection(name).get();
      await Promise.all(snap.docs.map((d) => d.ref.delete()));
    }
  });

  test("yeni kullanıcıya benzersiz kod ayırır ve eşlemeyi kurar", async () => {
    const idToken = await getIdTokenForUid("new-user-1");
    const res = await call("ensureReferralCode", idToken);

    expect(res.statusCode).toBe(200);
    expect(res.body.code).toMatch(CODE_PATTERN);
    expect(res.body.code).toHaveLength(8);
    const growth = (await db.collection("user_growth").doc("new-user-1").get()).data();
    expect(growth).toMatchObject({referral_code: res.body.code, founding_member: false, premium_access_until: null, referred_by_code: null});
    expect((await db.collection("referral_codes").doc(res.body.code).get()).data().uid).toBe("new-user-1");
  });

  test("idempotent: ikinci çağrı aynı kodu döner", async () => {
    const first = await ensureReferralCodeFor(db, "new-user-2");
    const second = await ensureReferralCodeFor(db, "new-user-2");
    expect(second).toBe(first);
    const owned = await db.collection("referral_codes").where("uid", "==", "new-user-2").get();
    expect(owned.size).toBe(1);
  });

  test("dolu kod denk gelirse yeni kod dener", async () => {
    await db.collection("referral_codes").doc("TAKEN234").set({uid: "someone"});
    const codes = ["TAKEN234", "FREE2345"];
    const code = await ensureReferralCodeFor(db, "new-user-3", {randomCode: () => codes.shift()});
    expect(code).toBe("FREE2345");
  });

  test("eşlemesi olmayan eski kod korunur ve eşlemesi kurulur", async () => {
    await db.collection("user_growth").doc("legacy-user").set({referral_code: "OLD234", founding_member: true});
    const code = await ensureReferralCodeFor(db, "legacy-user");
    expect(code).toBe("OLD234");
    expect((await db.collection("referral_codes").doc("OLD234").get()).data().uid).toBe("legacy-user");
    expect((await db.collection("user_growth").doc("legacy-user").get()).data().founding_member).toBe(true);
  });

  test("başkasına ait kodu taşıyan gaspçıya yeni kod verilir, sahibin kodu değişmez", async () => {
    await seedReferrer("owner", "OWNED234");
    await db.collection("user_growth").doc("squatter").set({referral_code: "OWNED234"});

    const code = await ensureReferralCodeFor(db, "squatter");

    expect(code).not.toBe("OWNED234");
    expect((await db.collection("referral_codes").doc("OWNED234").get()).data().uid).toBe("owner");
  });

  test("önce davet kodu kullanan kişi sonradan kendi kodunu alabilir (kilitlenme hatası)", async () => {
    await seedReferrer("inviter", "INVITE23");
    await redeemReferral(db, "early-redeemer", "INVITE23");
    // redeem dokümanı yalnız referred_by_code ile yarattı.
    const code = await ensureReferralCodeFor(db, "early-redeemer");

    expect(code).toMatch(CODE_PATTERN);
    const growth = (await db.collection("user_growth").doc("early-redeemer").get()).data();
    expect(growth.referral_code).toBe(code);
    expect(growth.referred_by_code).toBe("INVITE23"); // ezilmedi
  });
});
