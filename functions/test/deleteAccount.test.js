const admin = require("firebase-admin");
const httpMocks = require("node-mocks-http");
const {getIdTokenForUid, getAppCheckHeaderForTests} = require("./helpers");

const myFunctions = require("../index");

const db = admin.firestore();

/**
 * @param {string|null} idToken Bearer token, or null to omit the header.
 * @return {Promise<{statusCode: number, body: object}>}
 */
async function callDelete(idToken) {
  const req = httpMocks.createRequest({
    method: "POST",
    headers: {
      ...(idToken ? {authorization: `Bearer ${idToken}`} : {}),
      ...(await getAppCheckHeaderForTests()),
    },
  });
  const res = httpMocks.createResponse({eventEmitter: require("events").EventEmitter});

  await myFunctions.deleteAccount(req, res);
  return {statusCode: res.statusCode, body: res._getJSONData()};
}

describe("deleteAccount", () => {
  test("rejects requests with no bearer token", async () => {
    const res = await callDelete(null);
    expect(res.statusCode).toBe(401);
  });

  test("wipes the user's Firestore subtree, user_growth doc, and Auth user", async () => {
    const uid = "to-delete-1";
    await admin.auth().createUser({uid, email: `${uid}@example.com`});

    await db.collection("users").doc(uid).set({name: "Test User"});
    await db
        .collection("users")
        .doc(uid)
        .collection("journal_entries")
        .doc("entry-1")
        .set({text: "hello"});
    await db.collection("user_growth").doc(uid).set({
      referral_code: "DELME01",
      founding_member: false,
      premium_access_until: null,
      referred_by_code: null,
    });

    const idToken = await getIdTokenForUid(uid);
    const res = await callDelete(idToken);

    expect(res.body).toEqual({deleted: true});

    const userDoc = await db.collection("users").doc(uid).get();
    expect(userDoc.exists).toBe(false);

    const entries = await db
        .collection("users")
        .doc(uid)
        .collection("journal_entries")
        .get();
    expect(entries.empty).toBe(true);

    const growthDoc = await db.collection("user_growth").doc(uid).get();
    expect(growthDoc.exists).toBe(false);

    await expect(admin.auth().getUser(uid)).rejects.toThrow();
  });

  test("removes referrals where the deleted user was the referred party", async () => {
    const uid = "to-delete-2";
    await admin.auth().createUser({uid, email: `${uid}@example.com`});
    await db.collection("referrals").add({
      referrer_id: "someone-else",
      referred_id: uid,
      referral_code: "X",
      status: "completed",
    });

    const idToken = await getIdTokenForUid(uid);
    await callDelete(idToken);

    const remaining = await db
        .collection("referrals")
        .where("referred_id", "==", uid)
        .get();
    expect(remaining.empty).toBe(true);
  });

  test("only deletes the caller's own data, never another uid's", async () => {
    const victim = "innocent-bystander";
    const attacker = "to-delete-3";
    await admin.auth().createUser({uid: victim, email: `${victim}@example.com`});
    await admin.auth().createUser({uid: attacker, email: `${attacker}@example.com`});
    await db.collection("users").doc(victim).set({name: "Should survive"});

    const idToken = await getIdTokenForUid(attacker);
    await callDelete(idToken);

    const victimDoc = await db.collection("users").doc(victim).get();
    expect(victimDoc.exists).toBe(true);
    await expect(admin.auth().getUser(victim)).resolves.toBeDefined();
  });
});
