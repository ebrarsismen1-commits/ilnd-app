// Supabase yapılandırması index.js yüklenmeden ÖNCE: SUPABASE_URL modül
// yüklenirken okunuyor. Gerçek Supabase'e hiçbir istek gitmez; aşağıdaki fetch
// sahtesi bu alan adını yakalar.
process.env.SUPABASE_URL = "https://supabase.test";
process.env.SUPABASE_SERVICE_ROLE_KEY = "test-service-role-key";

const admin = require("firebase-admin");
const httpMocks = require("node-mocks-http");
const {getIdTokenForUid, getAppCheckHeaderForTests} = require("./helpers");

const myFunctions = require("../index");
const {
  retryPendingDeletions,
  runAccountDeletion,
  hasDeletionRequest,
  isSafeUid,
} = require("../accountDeletion");

/** Modül düzeyindeki testler için gerçek (emülatör) bağımlılıklar. */
const moduleDeps = () => ({
  db,
  auth: admin.auth(),
  getBucket: () => null,
  supabase: {url: process.env.SUPABASE_URL, serviceKey: process.env.SUPABASE_SERVICE_ROLE_KEY},
  revenueCatKey: "",
  fetchImpl: global.fetch,
  log: {warn() {}, error() {}},
});

const db = admin.firestore();

jest.setTimeout(30000);

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

// Supabase sahte sunucusu: her testte davranışı değiştirilebilir.
let supabaseStatus = {profiles: 204, authUser: 200};
const supabaseCalls = [];

let realFetch;
beforeAll(() => {
  realFetch = global.fetch;
  global.fetch = jest.fn((url, options) => {
    const u = String(url);
    if (u.startsWith("https://supabase.test")) {
      supabaseCalls.push({url: u, options});
      const status = u.includes("/rest/v1/profiles") ? supabaseStatus.profiles : supabaseStatus.authUser;
      return Promise.resolve({ok: status >= 200 && status < 300, status});
    }
    return realFetch(url, options);
  });
});
afterAll(() => {
  global.fetch = realFetch;
});
beforeEach(() => {
  supabaseStatus = {profiles: 204, authUser: 200};
  supabaseCalls.length = 0;
});

const today = new Date().toISOString().slice(0, 10);

/** Bir kullanıcının denetimde listelenen HER veri türünden birer kayıt yazar. */
async function seedEverything(uid) {
  await db.doc(`users/${uid}`).set({name: "Test User", photoBase64: "abc"});
  await db.doc(`users/${uid}/journal_entries/j1`).set({body: "özel"});
  await db.doc(`users/${uid}/food_entries/f1`).set({yemekAdi: "çorba"});
  await db.doc(`users/${uid}/plan_progress/p1`).set({completedDayIds: ["d1"]});
  await db.doc(`users/${uid}/plan_progress/p1/nested/n1`).set({x: 1});
  await db.collection("habits").add({userId: uid, name: "su"});
  await db.doc(`habit_completions/${today}_h-${uid}`).set({userId: uid, habitId: `h-${uid}`, date: today});
  await db.doc(`daily_checkins/${uid}_${today}`).set({userId: uid, date: today});
  await db.doc(`ai_usage/${uid}_${today}`).set({uid, counts: {quick: 1}});
  await db.doc(`ai_usage/${uid}_premium`).set({uid, premium: true});
  await db.doc(`ai_token_usage/${uid}_${today}`).set({uid, estimatedUsd: 0.1});
  await db.doc(`island/${uid}`).set({uid, earned: ["pine"]});
  await db.doc(`events/e-${uid}`).set({title: "buluşma"});
  await db.doc(`events/e-${uid}/rsvps/${uid}`).set({userId: uid});
  await db.doc(`user_growth/${uid}`).set({referral_code: `C${uid.length}ODE`});
  await db.collection("referrals").add({referrer_id: uid, referred_id: "someone"});
  await db.collection("referrals").add({referrer_id: "someone", referred_id: uid});
}

/** uid'e ait kalan kayıtların yollarını döner. */
async function remainingFor(uid) {
  const left = [];
  const checks = [
    db.doc(`users/${uid}`).get(),
    db.doc(`island/${uid}`).get(),
    db.doc(`user_growth/${uid}`).get(),
    db.doc(`events/e-${uid}/rsvps/${uid}`).get(),
  ];
  for (const snap of await Promise.all(checks)) if (snap.exists) left.push(snap.ref.path);
  const sub = await db.doc(`users/${uid}`).listCollections();
  if (sub.length) left.push(...sub.map((c) => c.path));
  for (const [col, field] of [
    ["habits", "userId"], ["habit_completions", "userId"], ["daily_checkins", "userId"],
    ["ai_usage", "uid"], ["ai_token_usage", "uid"], ["referrals", "referred_id"], ["referrals", "referrer_id"],
  ]) {
    const q = await db.collection(col).where(field, "==", uid).get();
    q.docs.forEach((d) => left.push(d.ref.path));
  }
  return left;
}

describe("deleteAccount", () => {
  test("rejects requests with no bearer token", async () => {
    const res = await callDelete(null);
    expect(res.statusCode).toBe(401);
  });

  test("H-3: her veri türünü siler, başka kullanıcıya dokunmaz", async () => {
    const uid = "del-all-1";
    const other = "del-bystander-1";
    await admin.auth().createUser({uid});
    await admin.auth().createUser({uid: other});
    await seedEverything(uid);
    await seedEverything(other);

    const res = await callDelete(await getIdTokenForUid(uid));

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({deleted: true});
    expect(await remainingFor(uid)).toEqual([]);
    await expect(admin.auth().getUser(uid)).rejects.toThrow();

    expect((await remainingFor(other)).length).toBeGreaterThan(10);
    await expect(admin.auth().getUser(other)).resolves.toBeDefined();

    const tomb = (await db.doc(`deletion_requests/${uid}`).get()).data();
    expect(tomb.status).toBe("done");
    expect(Object.keys(tomb).sort()).toEqual(["attempts", "completedAt", "failedSteps", "lastAttemptAt", "status", "uid"]);
  });

  test("Supabase'e doğru uid ve service key ile gider", async () => {
    const uid = "del-supabase-1";
    await admin.auth().createUser({uid});
    await callDelete(await getIdTokenForUid(uid));

    const urls = supabaseCalls.map((c) => c.url);
    expect(urls).toEqual([
      `https://supabase.test/rest/v1/profiles?id=eq.${uid}`,
      `https://supabase.test/auth/v1/admin/users/${uid}`,
    ]);
    supabaseCalls.forEach((c) => {
      expect(c.options.method).toBe("DELETE");
      expect(c.options.headers.Authorization).toBe("Bearer test-service-role-key");
    });
  });

  test("H-3: Supabase başarısızsa başarı DEMEZ, yeniden girişi kilitler", async () => {
    const uid = "del-partial-1";
    await admin.auth().createUser({uid});
    await seedEverything(uid);
    supabaseStatus.authUser = 500;

    const res = await callDelete(await getIdTokenForUid(uid));

    expect(res.statusCode).toBe(500);
    expect(res.body.retryable).toBe(true);
    expect(res.body.failedSteps).toEqual(["supabase"]);
    // Firebase kullanıcısı silinmedi (mevcut oturumla tekrar deneyebilsin),
    // ama mezar taşı var: mintFirebaseToken bu uid'e yeni oturum açmaz.
    await expect(admin.auth().getUser(uid)).resolves.toBeDefined();
    expect(await hasDeletionRequest(db, uid)).toBe(true);
    // Bağımsız veri adımları yine de çalıştı.
    expect(await remainingFor(uid)).toEqual([]);
    expect((await db.doc(`deletion_requests/${uid}`).get()).data().status).toBe("failed");
  });

  test("H-3: başarısız silme tekrar denenince tamamlanır", async () => {
    const uid = "del-retry-1";
    await admin.auth().createUser({uid});
    const idToken = await getIdTokenForUid(uid);
    supabaseStatus.profiles = 503;
    expect((await callDelete(idToken)).statusCode).toBe(500);

    supabaseStatus.profiles = 204;
    const retry = await callDelete(idToken);
    expect(retry.statusCode).toBe(200);
    await expect(admin.auth().getUser(uid)).rejects.toThrow();
    const tomb = (await db.doc(`deletion_requests/${uid}`).get()).data();
    expect(tomb.status).toBe("done");
    expect(tomb.attempts).toBe(2);
  });

  // Not: silme BAŞARIYLA bittikten sonra aynı token'la ikinci HTTP çağrısı
  // üretimde 200 döner (verifyIdToken checkRevoked olmadan kullanıcının
  // varlığına bakmaz). Auth emülatöründe ise Admin SDK her zaman
  // iptal/varlık kontrolü yapar ve 401 döner; bu yüzden "silinmiş hesapta
  // tekrar" idempotentliği modül düzeyinde doğrulanır.
  test("H-3: iki kez çalıştırmak hata vermez ve ikisi de tamamlanır", async () => {
    const uid = "del-twice-1";
    await admin.auth().createUser({uid});
    await seedEverything(uid);
    const first = await runAccountDeletion(uid, moduleDeps());
    const second = await runAccountDeletion(uid, moduleDeps());
    expect(first.complete).toBe(true);
    expect(second.complete).toBe(true);
    expect(await remainingFor(uid)).toEqual([]);
    expect((await db.doc(`deletion_requests/${uid}`).get()).data().attempts).toBe(2);
  });

  test("H-3: yarım silmeden sonra ikinci HTTP çağrısı tamamlar (200, 500 değil)", async () => {
    const uid = "del-twice-http";
    await admin.auth().createUser({uid});
    const idToken = await getIdTokenForUid(uid);
    supabaseStatus.authUser = 502;
    expect((await callDelete(idToken)).statusCode).toBe(500);
    supabaseStatus.authUser = 200;
    const second = await callDelete(idToken);
    expect(second.statusCode).toBe(200);
    expect(second.body).toEqual({deleted: true});
  });

  test("silme istenmemiş hesapta yeniden giriş kilidi yok", async () => {
    expect(await hasDeletionRequest(db, "never-requested")).toBe(false);
  });

  test("Supabase kullanıcısı zaten yoksa (404) başarı sayılır", async () => {
    const uid = "del-gone-1";
    await admin.auth().createUser({uid});
    supabaseStatus = {profiles: 404, authUser: 404};
    expect((await callDelete(await getIdTokenForUid(uid))).statusCode).toBe(200);
  });

  test("Firebase kullanıcısı hiç yoksa bile tamamlanır", async () => {
    const uid = "del-no-auth-user";
    await db.doc(`island/${uid}`).set({uid});
    const result = await runAccountDeletion(uid, moduleDeps());
    expect(result.complete).toBe(true);
    expect((await db.doc(`island/${uid}`).get()).exists).toBe(false);
  });

  test("zamanlanmış yeniden deneme yarım kalanı bitirir", async () => {
    const uid = "del-sweep-1";
    await admin.auth().createUser({uid});
    supabaseStatus.authUser = 500;
    expect((await callDelete(await getIdTokenForUid(uid))).statusCode).toBe(500);

    supabaseStatus.authUser = 200;
    const summary = await retryPendingDeletions(moduleDeps());
    expect(summary.completed).toBeGreaterThanOrEqual(1);
    await expect(admin.auth().getUser(uid)).rejects.toThrow();
    expect((await db.doc(`deletion_requests/${uid}`).get()).data().status).toBe("done");
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

describe("isSafeUid", () => {
  test.each(["", "a/b", "..", ".", "x".repeat(129), null, 5])("%p reddedilir", (uid) => {
    expect(isSafeUid(uid)).toBe(false);
  });
  test("normal uid geçer", () => {
    expect(isSafeUid("7b0c2f7e-2a0e-4c38-9b8f-3c1f0d7a9e11")).toBe(true);
  });
});
