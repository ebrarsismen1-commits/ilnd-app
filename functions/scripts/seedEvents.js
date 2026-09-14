#!/usr/bin/env node
/**
 * content/events.json → `events` koleksiyonuna upsert (ADR-0002).
 * seedArticles.js ile aynı desen: stable id, merge, --prune ile orphan silme.
 *
 * Kullanım (hedef ZORUNLU — bkz. scripts/lib/target.js):
 *   node functions/scripts/seedEvents.js --project=<id> [--confirm-prod] [--prune [--confirm-prune]]
 * (Application Default Credentials veya GOOGLE_APPLICATION_CREDENTIALS gerekir.)
 */
const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");
const {resolveTarget, pruneOrphans, describeTarget} = require("./lib/target");

const EVENTS_PATH = path.join(__dirname, "..", "..", "content", "events.json");

async function main() {
  const target = resolveTarget();
  console.log(describeTarget(target));
  if (!admin.apps.length) admin.initializeApp({projectId: target.projectId});
  const db = admin.firestore();
  const col = db.collection("events");

  const events = JSON.parse(fs.readFileSync(EVENTS_PATH, "utf8"));
  const seenIds = new Set();

  const batch = db.batch();
  for (const ev of events) {
    if (!ev.id) throw new Error(`Event "${ev.title}" is missing a stable id.`);
    seenIds.add(ev.id);
    const {id, startsAt, ...data} = ev;
    batch.set(
      col.doc(id),
      {...data, startsAt: admin.firestore.Timestamp.fromDate(new Date(startsAt))},
      {merge: true},
    );
  }
  await batch.commit();
  console.log(`Upserted ${events.length} event(s).`);

  await pruneOrphans(col, seenIds, target, "event(s)");
}

main().catch((err) => {
  console.error("seedEvents failed:", err);
  process.exitCode = 1;
});
