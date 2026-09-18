/**
 * Emülatörde çalışır. Deploy sonrası sayaç doldurma script'i: mevcut
 * etkinliklere rsvpCount yazar, haftalık aktif sayıyı üretir, hedefsiz
 * çalıştırılırsa (emülatör dışı) hiçbir şeye dokunmadan reddeder.
 */
const {execFileSync} = require("child_process");
const path = require("path");
const admin = require("firebase-admin");

if (admin.apps.length === 0) admin.initializeApp();
const db = admin.firestore();
const SCRIPT = path.join(__dirname, "..", "scripts", "backfillCounters.js");

jest.setTimeout(30000);

async function wipe(col) {
  const snap = await db.collection(col).get();
  await Promise.all(snap.docs.map((d) => db.recursiveDelete(d.ref)));
}

// Önce de temizlenir: başka test dosyalarının bıraktığı check-in'ler
// (ör. deleteAccount'un dokunmadığı "seyirci" kullanıcı) haftalık sayıyı
// dosya sırasına bağımlı hale getiriyordu.
const wipeAll = async () => {
  await wipe("events");
  await wipe("daily_checkins");
  await wipe("public_stats");
};
beforeEach(wipeAll);
afterEach(wipeAll);

test("mevcut etkinliklerin katılımcı sayısını ve haftalık sayıyı doldurur", async () => {
  const today = new Date().toISOString().slice(0, 10);
  await db.doc("events/e1").set({title: "yürüyüş"});
  await db.doc("events/e1/rsvps/A").set({userId: "A"});
  await db.doc("events/e1/rsvps/B").set({userId: "B"});
  await db.doc("events/e2").set({title: "boş"});
  await db.doc(`daily_checkins/A_${today}`).set({userId: "A", date: today});

  execFileSync("node", [SCRIPT], {env: process.env, stdio: "pipe"});

  expect((await db.doc("events/e1").get()).data().rsvpCount).toBe(2);
  expect((await db.doc("events/e2").get()).data().rsvpCount).toBe(0);
  expect((await db.doc("public_stats/weekly_active").get()).data().count).toBe(1);
});

test("emülatör dışında hedefsiz çalıştırmayı reddeder", () => {
  const env = {...process.env};
  delete env.FIRESTORE_EMULATOR_HOST;
  let status = 0;
  let output = "";
  try {
    execFileSync("node", [SCRIPT], {env, stdio: "pipe"});
  } catch (err) {
    status = err.status;
    output = `${err.stderr || ""}${err.stdout || ""}`;
  }
  expect(status).not.toBe(0);
  expect(output).toMatch(/explicit target/);
});
