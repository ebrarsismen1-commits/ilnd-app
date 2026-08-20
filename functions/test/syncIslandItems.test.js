/**
 * Adan öğe kazanımı (ADR-0006) — Firebase Emulator Suite üzerinde koşar.
 *
 * Bu fonksiyon güvenlik açısından kritik: öğeyi veren tek yer burası, çünkü
 * istemcinin `island/{uid}` dokümanına yazması firestore.rules'da kapalı.
 * Testler iki şeyi kilitler: eşiği geçmeden öğe VERİLMEZ, kazanılan öğe
 * ASLA geri alınmaz.
 */
const admin = require("firebase-admin");
const httpMocks = require("node-mocks-http");
const {getIdTokenForUid} = require("./helpers");

const myFunctions = require("../index");

const db = admin.firestore();
const UID = "island-test-user";

/**
 * syncIslandItems handler'ını sahte req/res ile çağırır.
 * @param {string|null} idToken Bearer token, yoksa null.
 * @return {Promise<{statusCode: number, body: object}>}
 */
async function callSync(idToken) {
  const req = httpMocks.createRequest({
    method: "POST",
    headers: {...(idToken ? {authorization: `Bearer ${idToken}`} : {})},
    body: {},
  });
  const res = httpMocks.createResponse({
    eventEmitter: require("events").EventEmitter,
  });
  await myFunctions.syncIslandItems(req, res);
  return {statusCode: res.statusCode, body: res._getJSONData()};
}

/**
 * Bir koleksiyondaki tüm dokümanları siler.
 * @param {FirebaseFirestore.Query} query silinecek doküman sorgusu
 */
async function wipe(query) {
  const snap = await query.get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}

describe("syncIslandItems", () => {
  beforeEach(async () => {
    await db.collection("island").doc(UID).delete().catch(() => {});
    await wipe(db.collection("users").doc(UID).collection("journal_entries"));
    await wipe(db.collection("users").doc(UID).collection("food_entries"));
    await wipe(db.collection("daily_checkins").where("userId", "==", UID));
    await wipe(db.collection("users").doc(UID).collection("sleep_rituals"));
    await wipe(db.collectionGroup("rsvps").where("userId", "==", UID));
  });

  test("token yoksa 401", async () => {
    const {statusCode} = await callSync(null);
    expect(statusCode).toBe(401);
  });

  test("veri yokken hiçbir öğe verilmez", async () => {
    const token = await getIdTokenForUid(UID);
    const {statusCode, body} = await callSync(token);

    expect(statusCode).toBe(200);
    expect(body.earned).toEqual([]);
  });

  test("ilk günlük fener kazandırır", async () => {
    await db
        .collection("users").doc(UID)
        .collection("journal_entries").add({text: "ilk yazı"});

    const token = await getIdTokenForUid(UID);
    const {body} = await callSync(token);

    expect(body.earned).toContain("lantern");
    expect(body.gained).toContain("lantern");

    // Yazma gerçekten sunucudan gitmiş olmalı.
    const doc = await db.collection("island").doc(UID).get();
    expect(doc.data().earned).toContain("lantern");
  });

  test("10 öğün fırın kazandırır, 9 öğün kazandırmaz", async () => {
    const meals = db.collection("users").doc(UID).collection("food_entries");
    for (let i = 0; i < 9; i++) await meals.add({kalori: 300});

    const token = await getIdTokenForUid(UID);
    let res = await callSync(token);
    expect(res.body.earned).not.toContain("oven");

    await meals.add({kalori: 300});
    res = await callSync(token);
    expect(res.body.earned).toContain("oven");
  });

  test("kazanılan öğe veri silinse bile geri alınmaz", async () => {
    const journal = db
        .collection("users").doc(UID).collection("journal_entries");
    await journal.add({text: "ilk yazı"});

    const token = await getIdTokenForUid(UID);
    await callSync(token);

    // Kullanıcı günlüğünü siler — ada küçülmez (handoff §7: ceza yok).
    await wipe(journal);
    const {body} = await callSync(token);

    expect(body.earned).toContain("lantern");
    expect(body.gained).toEqual([]);
  });

  test("gece ritüeli kaydı ay ışığını kazandırır", async () => {
    // Yayın öncesi düzeltme: ritüel tamamlanması artık Firestore'a da
    // yazılıyor (eskiden yalnız cihazdaydı, bu yüzden öğe kazanılamıyordu).
    await db
        .collection("users").doc(UID)
        .collection("sleep_rituals").doc("2026-08-19").set({date: "2026-08-19"});

    const token = await getIdTokenForUid(UID);
    const {body} = await callSync(token);

    expect(body.earned).toContain("moonlight");
  });

  test("etkinliğe RSVP buluşma taşını kazandırır", async () => {
    await db
        .collection("events").doc("evt-1")
        .collection("rsvps").doc(UID).set({userId: UID});

    const token = await getIdTokenForUid(UID);
    const {body} = await callSync(token);

    expect(body.earned).toContain("meetingStone");

    await db.collection("events").doc("evt-1")
        .collection("rsvps").doc(UID).delete();
  });

  test("çağrı idempotent — ikinci çağrı yeni öğe vermez", async () => {
    await db
        .collection("users").doc(UID)
        .collection("journal_entries").add({text: "x"});

    const token = await getIdTokenForUid(UID);
    await callSync(token);
    const {body} = await callSync(token);

    expect(body.gained).toEqual([]);
    expect(body.earned).toEqual(["lantern"]);
  });
});
