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

// Hız sınırı bu dosyada kapalı: testler art arda senkron çağırıp veri
// değişimini ölçüyor. Sınırın kendisi "Phase 7" bloğunda açılır. Değer her
// istekte okunduğu için modül yüklendikten sonra ayarlamak yeterli.
process.env.ISLAND_SYNC_MIN_INTERVAL_MS = "0";

/**
 * Göreli tarih: sabit tarihler seri penceresinden (60 gün) zamanla düşüp
 * testleri kendiliğinden kırardı.
 * @param {number} n kaç gün önce
 * @return {string} UTC YYYY-MM-DD
 */
const daysAgo = (n) =>
  new Date(Date.now() - n * 86400000).toISOString().slice(0, 10);

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

  test("son etkin gün sunucuda hesaplanır ve yazılır", async () => {
    // Su bu alandan koyulaşıyor (ADR-0006 §5). Gün SAYISI değil, gün
    // DİZESİ yazılır: sayı iki senkron arasında bayatlardı.
    const day = daysAgo(24);
    await db.collection("daily_checkins").doc(`${UID}_${day}`)
        .set({userId: UID, date: day});

    const token = await getIdTokenForUid(UID);
    const {body} = await callSync(token);

    expect(body.metrics.lastActiveDate).toBe(day);
    const doc = await db.collection("island").doc(UID).get();
    expect(doc.data().lastActiveDate).toBe(day);
  });

  test("öğün, check-in yazmasa bile son etkin günü ilerletir", async () => {
    const checkinDay = daysAgo(34);
    const mealDay = daysAgo(22);
    await db.collection("daily_checkins").doc(`${UID}_${checkinDay}`)
        .set({userId: UID, date: checkinDay});
    await db.collection("users").doc(UID).collection("food_entries").add({
      kalori: 300,
      createdAt: admin.firestore.Timestamp.fromDate(
          new Date(`${mealDay}T10:00:00Z`)),
    });

    const token = await getIdTokenForUid(UID);
    const {body} = await callSync(token);

    // Yalnız check-in'e bakılsaydı bu kullanıcının suyu 12 gün daha uzun
    // sessizmiş gibi koyulaşacaktı — oysa sonradan yemeğini yazmış.
    expect(body.metrics.lastActiveDate).toBe(mealDay);
  });

  test("hiç veri yoksa son etkin gün null, su berrak kalır", async () => {
    const token = await getIdTokenForUid(UID);
    const {body} = await callSync(token);
    expect(body.metrics.lastActiveDate).toBeNull();
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

  // ── Phase 7 (denetim H-6): sınırlı okuma ve hız sınırı ─────────────────
  describe("sınırlı okuma ve hız sınırı", () => {
    afterEach(() => {
      process.env.ISLAND_SYNC_MIN_INTERVAL_MS = "0";
    });

    test("400 günlük geçmiş okunmaz: seri pencerede (60) durur", async () => {
      // Eski sorgu kullanıcının TÜM check-in'lerini okuyordu ve bu durumda
      // seri 400 çıkıyordu.
      const batch = db.batch();
      for (let i = 0; i < 400; i++) {
        const d = daysAgo(i);
        batch.set(db.collection("daily_checkins").doc(`${UID}_${d}`), {userId: UID, date: d});
      }
      await batch.commit();

      const {body} = await callSync(await getIdTokenForUid(UID));

      expect(body.metrics.streakDays).toBe(60);
      expect(body.earned).toEqual(expect.arrayContaining(["pine", "windrose"]));
    }, 30000);

    test("pencere dışındaki son check-in yine son etkin gün sayılır (su koyulaşır)", async () => {
      const d = daysAgo(90);
      await db.collection("daily_checkins").doc(`${UID}_${d}`).set({userId: UID, date: d});

      const {body} = await callSync(await getIdTokenForUid(UID));

      expect(body.metrics.lastActiveDate).toBe(d);
      expect(body.metrics.streakDays).toBe(0);
    });

    test("pencere içindeki tekrar çağrı ölçüt okumaz, son bilinen durumu döner", async () => {
      process.env.ISLAND_SYNC_MIN_INTERVAL_MS = "60000";
      const token = await getIdTokenForUid(UID);

      const first = await callSync(token);
      expect(first.body.earned).toEqual([]);

      await db.collection("users").doc(UID).collection("journal_entries").add({text: "x"});
      const second = await callSync(token);
      expect(second.body).toEqual({earned: [], gained: [], throttled: true});
      expect((await db.collection("island").doc(UID).get()).data().earned).toEqual([]);

      // Pencere geçince yeni kazanım gelir.
      process.env.ISLAND_SYNC_MIN_INTERVAL_MS = "0";
      const third = await callSync(token);
      expect(third.body.earned).toContain("lantern");
    });

    test("ilk senkron hız sınırına takılmaz", async () => {
      process.env.ISLAND_SYNC_MIN_INTERVAL_MS = "60000";
      await db.collection("users").doc(UID).collection("journal_entries").add({text: "x"});

      const {body} = await callSync(await getIdTokenForUid(UID));

      expect(body.throttled).toBeUndefined();
      expect(body.earned).toContain("lantern");
    });
  });
});
