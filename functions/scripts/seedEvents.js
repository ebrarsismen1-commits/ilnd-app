#!/usr/bin/env node
/**
 * content/events.json → `events` koleksiyonuna upsert (ADR-0002).
 * seedArticles.js ile aynı desen: stable id, merge, --prune ile orphan silme.
 *
 * Kullanım:
 *   node functions/scripts/seedEvents.js [--prune]
 * (Application Default Credentials veya GOOGLE_APPLICATION_CREDENTIALS gerekir.)
 */
const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

const EVENTS_PATH = path.join(__dirname, "..", "..", "content", "events.json");

async function main() {
  const prune = process.argv.includes("--prune");
  if (!admin.apps.length) admin.initializeApp();
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

  if (prune) {
    const existing = await col.get();
    const orphaned = existing.docs.filter((d) => !seenIds.has(d.id));
    if (orphaned.length > 0) {
      const pruneBatch = db.batch();
      orphaned.forEach((d) => pruneBatch.delete(d.ref));
      await pruneBatch.commit();
      console.log(`Pruned ${orphaned.length} orphaned event(s).`);
    }
  }
}

main().catch((err) => {
  console.error("seedEvents failed:", err);
  process.exitCode = 1;
});
