#!/usr/bin/env node
/**
 * Upserts content/movementPrograms.json into the `movement_programs`
 * Firestore collection (ADR-0004).
 *
 * Same pipeline shape as seedArticles.js: the JSON file is the single source
 * of truth for program copy, and this script is the only thing allowed to
 * write the collection — firestore.rules denies every client write
 * (`allow write: if false`).
 *
 * Schema of one program (see lib/features/movement/movement_program.dart):
 *   {
 *     "id": "sabah-acilisi",          // stable, never reused for other content
 *     "title": "sabah açılışı",
 *     "description": "Uyanır uyanmaz bedeni açan üç kısa seans.",
 *     "level": "easy" | "medium" | "strong",
 *     "order": 0,                      // shelf order, ascending
 *     "premium": false,                // true = ILND+ only
 *     "coverUrl": "https://.../cover.jpg",
 *     "sessions": [
 *       {
 *         "id": "s1",                  // STABLE: user progress is keyed on it
 *         "title": "boyun ve omuz",
 *         "minutes": 6,
 *         "videoUrl": "https://firebasestorage.../movement%2F...mp4?alt=media",
 *         "thumbnailUrl": "https://.../s1.jpg"
 *       }
 *     ],
 *     "en": {
 *       "title": "morning opener",
 *       "description": "Three short sessions...",
 *       "sessionTitles": {"s1": "neck and shoulders"}
 *     }
 *   }
 *
 * A session with an empty videoUrl is ignored by the app, and a program with
 * no playable session is never shown — half-loaded content must not surface
 * as an empty promise.
 *
 * Videos live in Firebase Storage under `movement/{programId}/{sessionId}.mp4`;
 * `videoUrl` is the download URL of that object.
 *
 * Usage:
 *   node functions/scripts/seedMovementPrograms.js              # against prod
 *   node functions/scripts/seedMovementPrograms.js --prune      # also delete orphans
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 node functions/scripts/seedMovementPrograms.js
 *
 * Requires a service account: Application Default Credentials or
 * GOOGLE_APPLICATION_CREDENTIALS, same as seedArticles.js.
 */
const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

const PROGRAMS_PATH = path.join(
    __dirname, "..", "..", "content", "movementPrograms.json",
);

const LEVELS = new Set(["easy", "medium", "strong"]);

/**
 * Fails loudly on content mistakes that would silently break the app: a
 * missing id makes the upsert non-idempotent, a duplicate session id
 * corrupts progress tracking, an unknown level falls back to "easy" without
 * anyone noticing.
 * @param {object} program one entry from movementPrograms.json
 * @return {void}
 */
function validateProgram(program) {
  if (!program.id) {
    throw new Error(`Program "${program.title}" is missing a stable id.`);
  }
  if (program.level && !LEVELS.has(program.level)) {
    throw new Error(
        `Program "${program.id}" has unknown level "${program.level}" ` +
        `(expected one of: ${[...LEVELS].join(", ")}).`,
    );
  }
  const sessions = program.sessions || [];
  const seen = new Set();
  for (const session of sessions) {
    if (!session.id) {
      throw new Error(
          `Program "${program.id}" has a session with no id — user progress ` +
          "is keyed on session id, so it must be present and stable.",
      );
    }
    if (seen.has(session.id)) {
      throw new Error(
          `Program "${program.id}" has duplicate session id "${session.id}".`,
      );
    }
    seen.add(session.id);
  }
  const playable = sessions.filter((s) => s.videoUrl);
  if (playable.length === 0) {
    console.warn(
        `! Program "${program.id}" has no session with a videoUrl — it will ` +
        "be seeded but stays hidden in the app until a video is attached.",
    );
  }
}

/**
 * @return {Promise<void>}
 */
async function main() {
  const prune = process.argv.includes("--prune");

  if (!admin.apps.length) {
    admin.initializeApp();
  }
  const db = admin.firestore();
  const col = db.collection("movement_programs");

  const programs = JSON.parse(fs.readFileSync(PROGRAMS_PATH, "utf8"));
  const seenIds = new Set();

  const batch = db.batch();
  for (const program of programs) {
    validateProgram(program);
    if (seenIds.has(program.id)) {
      throw new Error(`Duplicate program id "${program.id}".`);
    }
    seenIds.add(program.id);
    const {id, ...data} = program;
    batch.set(col.doc(id), data, {merge: true});
  }
  await batch.commit();
  console.log(`Upserted ${programs.length} movement program(s).`);

  if (prune) {
    const existing = await col.get();
    const orphaned = existing.docs.filter((d) => !seenIds.has(d.id));
    if (orphaned.length > 0) {
      const pruneBatch = db.batch();
      orphaned.forEach((d) => pruneBatch.delete(d.ref));
      await pruneBatch.commit();
      console.log(
          `Pruned ${orphaned.length} orphaned program(s) not in ` +
          "movementPrograms.json.",
      );
    }
  }
}

main().catch((err) => {
  console.error("seedMovementPrograms failed:", err);
  process.exitCode = 1;
});
