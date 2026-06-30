/**
 * Runs against the Firebase Emulator Suite (Firestore + Auth) — see
 * functions/package.json's `test` script. `firebase emulators:exec` sets
 * FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST before this file
 * loads, which is what makes `admin.initializeApp()` in index.js talk to
 * the emulators instead of production.
 */
const admin = require("firebase-admin");
const httpMocks = require("node-mocks-http");
const {getIdTokenForUid, getAppCheckHeaderForTests} = require("./helpers");

const myFunctions = require("../index");

const db = admin.firestore();

/**
 * Invokes the redeemReferralCode handler directly with a mocked
 * req/res pair and waits for the response to finish.
 * @param {string|null} idToken Bearer token, or null to omit the header.
 * @param {object} body request JSON body.
 * @return {Promise<{statusCode: number, body: object}>}
 */
async function callRedeem(idToken, body) {
  const req = httpMocks.createRequest({
    method: "POST",
    headers: {
      ...(idToken ? {authorization: `Bearer ${idToken}`} : {}),
      ...(await getAppCheckHeaderForTests()),
    },
    body,
  });
  const res = httpMocks.createResponse({eventEmitter: require("events").EventEmitter});

  await myFunctions.redeemReferralCode(req, res);
  return {statusCode: res.statusCode, body: res._getJSONData()};
}

describe("redeemReferralCode", () => {
  afterEach(async () => {
    // Clean slate between tests — both collections are tiny in tests.
    const collections = ["user_growth", "referrals"];
    for (const name of collections) {
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

  test("rejects an invalid/unknown code", async () => {
    const idToken = await getIdTokenForUid("redeemer-2");
    const res = await callRedeem(idToken, {code: "NOTREAL"});
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({redeemed: false, reason: "invalid-code"});
  });

  test("rejects a user redeeming their own code (self-referral)", async () => {
    await db.collection("user_growth").doc("self-referrer").set({
      referral_code: "SELF01",
      founding_member: false,
      premium_access_until: null,
      referred_by_code: null,
    });

    const idToken = await getIdTokenForUid("self-referrer");
    const res = await callRedeem(idToken, {code: "SELF01"});

    expect(res.body).toEqual({redeemed: false, reason: "self-referral"});
  });

  test("grants the referrer a 7-day premium reward on a valid redemption", async () => {
    await db.collection("user_growth").doc("referrer-1").set({
      referral_code: "GIFT01",
      founding_member: false,
      premium_access_until: null,
      referred_by_code: null,
    });

    const idToken = await getIdTokenForUid("referee-1");
    const res = await callRedeem(idToken, {code: "GIFT01"});

    expect(res.body).toEqual({redeemed: true});

    const referrerDoc = await db.collection("user_growth").doc("referrer-1").get();
    expect(referrerDoc.data().founding_member).toBe(true);
    expect(referrerDoc.data().premium_access_until).not.toBeNull();

    const refereeDoc = await db.collection("user_growth").doc("referee-1").get();
    expect(refereeDoc.data().referred_by_code).toBe("GIFT01");

    const referrals = await db
        .collection("referrals")
        .where("referred_id", "==", "referee-1")
        .get();
    expect(referrals.size).toBe(1);
    expect(referrals.docs[0].data().referrer_id).toBe("referrer-1");
  });

  test("does not let the same user redeem twice (double-redemption guard)", async () => {
    await db.collection("user_growth").doc("referrer-2").set({
      referral_code: "ONCE01",
      founding_member: false,
      premium_access_until: null,
      referred_by_code: null,
    });
    await db.collection("user_growth").doc("referee-2").set({
      referral_code: "REFEREE2CODE",
      founding_member: false,
      premium_access_until: null,
      referred_by_code: "ONCE01", // already redeemed something
    });

    const idToken = await getIdTokenForUid("referee-2");
    const res = await callRedeem(idToken, {code: "ONCE01"});

    expect(res.body).toEqual({redeemed: false, reason: "already-redeemed"});
  });

  test("extends (does not overwrite) an already-active premium reward", async () => {
    const future = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000); // 3 days out
    await db.collection("user_growth").doc("referrer-3").set({
      referral_code: "STACK01",
      founding_member: true,
      premium_access_until: admin.firestore.Timestamp.fromDate(future),
      referred_by_code: null,
    });

    const idToken = await getIdTokenForUid("referee-3");
    await callRedeem(idToken, {code: "STACK01"});

    const referrerDoc = await db.collection("user_growth").doc("referrer-3").get();
    const newUntil = referrerDoc.data().premium_access_until.toDate();
    // 3 days remaining + 7 day reward should land ~10 days out, not just 7.
    const expectedMinimum = new Date(Date.now() + 9 * 24 * 60 * 60 * 1000);
    expect(newUntil.getTime()).toBeGreaterThan(expectedMinimum.getTime());
  });

  test("is not exploitable by writing founding_member directly from a client-like call", async () => {
    // Regression guard for the original vulnerability this function fixed:
    // confirms the Firestore rules (not exercised by this Admin-SDK test
    // directly, but documented here) are the reason a client can't do this
    // — this test instead asserts the function's own behavior never trusts
    // client-supplied reward fields, only the resolved referrer from the code.
    await db.collection("user_growth").doc("referrer-4").set({
      referral_code: "TRUST01",
      founding_member: false,
      premium_access_until: null,
      referred_by_code: null,
    });

    const idToken = await getIdTokenForUid("referee-4");
    // Attempt to smuggle extra fields the function doesn't read.
    await callRedeem(idToken, {
      code: "TRUST01",
      founding_member: true,
      premium_access_until: "2099-01-01",
    });

    const refereeDoc = await db.collection("user_growth").doc("referee-4").get();
    // The redeemer's own doc must only ever gain referred_by_code — never
    // founding_member/premium_access_until, which are referrer-only rewards.
    expect(refereeDoc.data().founding_member).toBeUndefined();
  });
});
