#!/usr/bin/env node
/**
 * Sunucu sayaçlarını bir kez doldurur (deploy sonrası).
 *
 * Neden: güvenlik denetimi H-1/H-6 ile istemci `daily_checkins` ve
 * `events/{id}/rsvps` koleksiyonlarını artık okuyamıyor; sayılar
 * `events/{id}.rsvpCount` ve `public_stats/weekly_active` alanlarından
 * geliyor. Tetikleyici yalnız YENİ bir RSVP yazılınca, zamanlanmış görev saatte
 * bir çalışır. Bu script çalışmadan deploy'dan hemen sonra mevcut etkinliklerin
 * katılımcı sayısı 0, sosyal kanıt rozeti boş görünür.
 *
 * İdempotent: her sayı baştan hesaplanır, tekrar çalıştırmak zararsız.
 *
 * Kullanım (hedef ZORUNLU — bkz. scripts/lib/target.js):
 *   node scripts/backfillCounters.js --project=ilnd-app-8dcbd --confirm-prod
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 node scripts/backfillCounters.js
 */
const admin = require("firebase-admin");
const {resolveTarget, describeTarget} = require("./lib/target");
const {recomputeRsvpCount, recomputeWeeklyActive} = require("../counters");

/**
 * @return {Promise<void>}
 */
async function main() {
  const target = resolveTarget();
  console.log(describeTarget(target));
  if (!admin.apps.length) admin.initializeApp({projectId: target.projectId});
  const db = admin.firestore();

  const events = await db.collection("events").get();
  let updated = 0;
  for (const doc of events.docs) {
    const count = await recomputeRsvpCount(db, doc.id);
    if (count !== null) updated++;
  }
  console.log(`rsvpCount recomputed for ${updated} event(s).`);

  const weekly = await recomputeWeeklyActive(db);
  console.log(`public_stats/weekly_active = ${weekly}.`);
}

main().catch((err) => {
  console.error("backfillCounters failed:", err);
  process.exitCode = 1;
});
