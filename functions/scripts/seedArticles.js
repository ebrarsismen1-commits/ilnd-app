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
 * Usage:
 *   node functions/scripts/seedArticles.js                  # against prod
 *   node functions/scripts/seedArticles.js --prune          # also delete orphans
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 node functions/scripts/seedArticles.js
 *
 * Requires a service account: either run inside an environment with
 * Application Default Credentials (e.g. `gcloud auth application-default
 * login`, or Cloud Shell), or set GOOGLE_APPLICATION_CREDENTIALS to a
 * service account key file.
 */
const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

const ARTICLES_PATH = path.join(__dirname, "..", "..", "content", "articles.json");

/**
 * @return {Promise<void>}
 */
async function main() {
  const prune = process.argv.includes("--prune");

  if (!admin.apps.length) {
    admin.initializeApp();
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

  if (prune) {
    const existing = await col.get();
    const orphaned = existing.docs.filter((d) => !seenIds.has(d.id));
    if (orphaned.length > 0) {
      const pruneBatch = db.batch();
      orphaned.forEach((d) => pruneBatch.delete(d.ref));
      await pruneBatch.commit();
      console.log(`Pruned ${orphaned.length} orphaned article(s) not in articles.json.`);
    }
  }
}

main().catch((err) => {
  console.error("seedArticles failed:", err);
  process.exitCode = 1;
});
