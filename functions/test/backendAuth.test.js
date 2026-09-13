/**
 * Emülatörde çalışır. Denetim H-5: her hassas uç yalnız Supabase köprüsünün
 * ürettiği oturumu kabul eder; App Check enforce modunda tokensız istek
 * reddedilir. Hiçbir test 401 dışındaki bir yola (silme, AI çağrısı) inmez.
 */
const admin = require("firebase-admin");
const httpMocks = require("node-mocks-http");
const {getIdTokenForUid, getAnonymousIdToken} = require("./helpers");

const fns = require("../index");

const db = admin.firestore();

async function call(fn, {idToken, headers = {}, body = {}} = {}) {
  const req = httpMocks.createRequest({
    method: "POST",
    headers: {...(idToken ? {authorization: `Bearer ${idToken}`} : {}), ...headers},
    body,
  });
  const res = httpMocks.createResponse({eventEmitter: require("events").EventEmitter});
  await fns[fn](req, res);
  return {statusCode: res.statusCode, body: res._isJSON() ? res._getJSONData() : res._getData()};
}

const ENDPOINTS = [
  ["anthropicProxy", {tier: "quick", messages: [{role: "user", content: "hi"}]}],
  ["redeemReferralCode", {code: "ABCDEFGH"}],
  ["deleteAccount", {}],
  ["syncIslandItems", {}],
  ["ensureReferralCode", {}],
];

describe("backend kimlik kapısı", () => {
  const savedMode = process.env.APP_CHECK_MODE;
  afterEach(() => {
    if (savedMode === undefined) delete process.env.APP_CHECK_MODE;
    else process.env.APP_CHECK_MODE = savedMode;
  });

  test.each(ENDPOINTS)("%s anonim Firebase oturumunu reddeder", async (fn, body) => {
    const idToken = await getAnonymousIdToken();
    const res = await call(fn, {idToken, body});
    expect(res.statusCode).toBe(401);
  });

  test.each(ENDPOINTS)("%s köprü claim'i olmayan custom token'ı reddeder", async (fn, body) => {
    const idToken = await getIdTokenForUid(`no-claim-${fn}`, {});
    const res = await call(fn, {idToken, body});
    expect(res.statusCode).toBe(401);
  });

  test.each(ENDPOINTS)("%s token'sız isteği reddeder", async (fn, body) => {
    const res = await call(fn, {body});
    expect(res.statusCode).toBe(401);
  });

  test.each(ENDPOINTS)("%s enforce modunda App Check token'ı yoksa reddeder", async (fn, body) => {
    process.env.APP_CHECK_MODE = "enforce";
    const idToken = await getIdTokenForUid(`enforce-missing-${fn}`);
    const res = await call(fn, {idToken, body});
    expect(res.statusCode).toBe(401);
    expect(res.body.error).toBe("App Check verification failed");
  });

  test.each(ENDPOINTS)("%s enforce modunda sahte App Check token'ını reddeder", async (fn, body) => {
    process.env.APP_CHECK_MODE = "enforce";
    const idToken = await getIdTokenForUid(`enforce-bogus-${fn}`);
    const res = await call(fn, {idToken, body, headers: {"X-Firebase-AppCheck": "not-a-real-token"}});
    expect(res.statusCode).toBe(401);
  });

  test("monitor modunda App Check eksikliği isteği bozmaz (geçerli oturum)", async () => {
    process.env.APP_CHECK_MODE = "monitor";
    const uid = "monitor-ok";
    const idToken = await getIdTokenForUid(uid);
    const res = await call("syncIslandItems", {idToken});
    expect(res.statusCode).toBe(200);
    await db.collection("island").doc(uid).delete();
  });

  test("gövdedeki uid alanı çağıranın kimliğini değiştirmez", async () => {
    const victim = "victim-uid";
    await db.collection("users").doc(victim).collection("journal_entries").doc("j").set({body: "x"});
    const idToken = await getIdTokenForUid("attacker-uid");
    const res = await call("syncIslandItems", {idToken, body: {uid: victim, userId: victim}});
    expect(res.statusCode).toBe(200);
    expect((await db.collection("island").doc(victim).get()).exists).toBe(false);
    expect((await db.collection("island").doc("attacker-uid").get()).exists).toBe(true);
    await db.recursiveDelete(db.collection("users").doc(victim));
    await db.collection("island").doc("attacker-uid").delete();
  });
});
