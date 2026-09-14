#!/usr/bin/env node
/**
 * Upserts content/articles.json into the `articles` Firestore collection.
 *
 * This is the actual content pipeline: `content/articles.json` is the
 * single source of truth for article copy (editable without touching Dart
 * or redeploying the app), and this script is the only thing with
 * permission to write to `articles` — firestore.rules denies all client
 * writes to that collection on purpose (`allow write: if false; // Admin
 * SDK ile yazılır`).
 *
 * Upserts by stable `id` (not delete-then-recreate), so:
 *   - running it twice is a no-op if content didn't change
 *   - it never produces a window where the collection is empty
 *   - removing an article from the JSON does NOT delete it from Firestore
 *     automatically (run with --prune to also delete orphaned docs)
 *
 * Usage (an explicit target is REQUIRED — see scripts/lib/target.js):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 node functions/scripts/seedArticles.js
 *   node functions/scripts/seedArticles.js --project=<staging-id>
 *   node functions/scripts/seedArticles.js --project=ilnd-app-8dcbd --confirm-prod
 *   ... --prune                   # on prod: dry run, lists what would be deleted
 *   ... --prune --confirm-prune   # on prod: actually delete orphans
 *
 * Requires a service account: either run inside an environment with
 * Application Default Credentials (e.g. `gcloud auth application-default
 * login`, or Cloud Shell), or set GOOGLE_APPLICATION_CREDENTIALS to a
 * service account key file.
 */
const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");
const {resolveTarget, pruneOrphans, describeTarget} = require("./lib/target");

const ARTICLES_PATH = path.join(__dirname, "..", "..", "content", "articles.json");

/**
 * @return {Promise<void>}
 */
async function main() {
  const target = resolveTarget();
  console.log(describeTarget(target));

  if (!admin.apps.length) {
    admin.initializeApp({projectId: target.projectId});
  }
  const db = admin.firestore();
  const col = db.collection("articles");

  const articles = JSON.parse(fs.readFileSync(ARTICLES_PATH, "utf8"));
  const seenIds = new Set();

  const batch = db.batch();
  for (const article of articles) {
    if (!article.id) {
      throw new Error(`Article "${article.title}" is missing a stable id.`);
    }
    seenIds.add(article.id);
    const {id, ...data} = article;
    batch.set(col.doc(id), data, {merge: true});
  }
  await batch.commit();
  console.log(`Upserted ${articles.length} articles.`);

  await pruneOrphans(col, seenIds, target, "article(s) not in articles.json");
}

main().catch((err) => {
  console.error("seedArticles failed:", err);
  process.exitCode = 1;
});
