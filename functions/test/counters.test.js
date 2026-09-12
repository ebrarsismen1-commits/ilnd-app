/**
 * Emülatörde çalışır. Denetim H-1/H-6: istemciye kapatılan koleksiyonların
 * yerine sunucunun yazdığı sayaçlar doğru ve idempotent olmalı.
 */
const admin = require("firebase-admin");
const {recomputeRsvpCount, recomputeWeeklyActive, recentDateKeys} = require("../counters");

if (admin.apps.length === 0) admin.initializeApp();
const db = admin.firestore();

async function wipe(col) {
  const snap = await db.collection(col).get();
  await Promise.all(snap.docs.map((d) => db.recursiveDelete(d.ref)));
}

afterEach(async () => {
  await wipe("events");
  await wipe("daily_checkins");
  await wipe("public_stats");
});

describe("recomputeRsvpCount", () => {
  test("katılımcı sayısını yazar ve tekrar çalışınca aynı kalır", async () => {
    await db.doc("events/e1").set({title: "yürüyüş"});
    await db.doc("events/e1/rsvps/A").set({userId: "A"});
    await db.doc("events/e1/rsvps/B").set({userId: "B"});

    expect(await recomputeRsvpCount(db, "e1")).toBe(2);
    expect(await recomputeRsvpCount(db, "e1")).toBe(2);
    expect((await db.doc("events/e1").get()).data().rsvpCount).toBe(2);

    await db.doc("events/e1/rsvps/B").delete();
    await recomputeRsvpCount(db, "e1");
    expect((await db.doc("events/e1").get()).data().rsvpCount).toBe(1);
  });

  test("silinmiş etkinlik için hayalet doküman yaratmaz", async () => {
    await db.doc("events/gone/rsvps/A").set({userId: "A"});
    expect(await recomputeRsvpCount(db, "gone")).toBeNull();
    expect((await db.doc("events/gone").get()).exists).toBe(false);
  });
});

describe("recomputeWeeklyActive", () => {
  test("yalnız son haftanın kullanıcı-günlerini sayar", async () => {
    const now = Date.UTC(2026, 8, 13, 12);
    const [today, yesterday] = recentDateKeys(now, 2);
    await db.doc(`daily_checkins/A_${today}`).set({userId: "A", date: today});
    await db.doc(`daily_checkins/B_${yesterday}`).set({userId: "B", date: yesterday});
    await db.doc("daily_checkins/C_2026-08-01").set({userId: "C", date: "2026-08-01"});

    expect(await recomputeWeeklyActive(db, now)).toBe(2);
    const stats = (await db.doc("public_stats/weekly_active").get()).data();
    expect(stats.count).toBe(2);
    expect(stats.window).toContain(today);
    expect(stats).not.toHaveProperty("userIds");
  });
});
