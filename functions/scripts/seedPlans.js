#!/usr/bin/env node
/**
 * Upserts content/plans.json into the `plans` Firestore collection (ADR-0005).
 *
 * Same pipeline shape as seedArticles.js / seedMovementPrograms.js: the JSON
 * file is the single source of truth for plan copy, and this script is the
 * only thing allowed to write the collection — firestore.rules denies every
 * client write (`allow write: if false`).
 *
 * Schema of one plan (see lib/features/plans/plan_model.dart):
 *   {
 *     "id": "7-gun-hareket",           // stable, never reused
 *     "title": "7 gün hareket",
 *     "description": "Bir haftada bedeni yeniden hatırlamak.",
 *     "order": 0,                      // shelf order, ascending
 *     "premium": false,                // true = ILND+ only
 *     "coverUrl": "https://.../cover.jpg",
 *     "days": [
 *       {
 *         "id": "d1",                  // STABLE: user progress is keyed on it
 *         "title": "başlangıç",
 *         "articleId": "bacaklar-duvara",   // an `articles` doc id (optional)
 *         "action": "breath",          // none | breath | move | water | journal
 *         "note": "beş dakika, hepsi bu."
 *       }
 *     ],
 *     "en": {
 *       "title": "7 days of movement",
 *       "description": "Remembering the body in a week.",
 *       "dayTitles": {"d1": "the beginning"},
 *       "dayNotes": {"d1": "five minutes, that is all."}
 *     }
 *   }
 *
 * A plan is only shown in the app when its length is 7, 14 or 21 AND every
 * day carries content (an articleId or an action). Half-loaded content must
 * not surface as an empty promise — this script warns about such plans
 * instead of failing, so content can be seeded incrementally.
 *
 * Usage:
 *   node functions/scripts/seedPlans.js              # against prod
 *   node functions/scripts/seedPlans.js --prune      # also delete orphans
 *   An explicit target is REQUIRED: --project=<id> (prod also needs
 *   --confirm-prod; prod --prune is a dry run without --confirm-prune).
 *   See scripts/lib/target.js.
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 node functions/scripts/seedPlans.js
 *
 * Requires a service account: Application Default Credentials or
 * GOOGLE_APPLICATION_CREDENTIALS, same as seedArticles.js.
 */
const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");
const {resolveTarget, pruneOrphans, describeTarget} = require("./lib/target");

const PLANS_PATH = path.join(__dirname, "..", "..", "content", "plans.json");

// Mirrors kPlanLengths in lib/features/plans/plan_model.dart.
const LENGTHS = new Set([7, 14, 21]);
const ACTIONS = new Set(["none", "breath", "move", "water", "journal"]);

/**
 * Fails loudly on content mistakes that would silently break the app: a
 * missing id makes the upsert non-idempotent, a duplicate day id corrupts
 * progress tracking, an unknown action falls back to "none" without anyone
 * noticing.
 * @param {object} plan one entry from plans.json
 * @return {void}
 */
function validatePlan(plan) {
  if (!plan.id) {
    throw new Error(`Plan "${plan.title}" is missing a stable id.`);
  }
  const days = plan.days || [];
  const seen = new Set();
  for (const day of days) {
    if (!day.id) {
      throw new Error(
          `Plan "${plan.id}" has a day with no id — user progress is keyed ` +
          "on day id, so it must be present and stable.",
      );
    }
    if (seen.has(day.id)) {
      throw new Error(`Plan "${plan.id}" has duplicate day id "${day.id}".`);
    }
    seen.add(day.id);
    if (day.action && !ACTIONS.has(day.action)) {
      throw new Error(
          `Plan "${plan.id}" day "${day.id}" has unknown action ` +
          `"${day.action}" (expected one of: ${[...ACTIONS].join(", ")}).`,
      );
    }
  }
  if (!LENGTHS.has(days.length)) {
    console.warn(
        `! Plan "${plan.id}" has ${days.length} day(s) — only ` +
        `${[...LENGTHS].join("/")}-day plans are shown in the app, so this ` +
        "one stays hidden until the length matches.",
    );
  }
  const empty = days.filter((d) => !d.articleId && (!d.action ||
      d.action === "none"));
  if (empty.length > 0) {
    console.warn(
        `! Plan "${plan.id}" has ${empty.length} day(s) with neither an ` +
        "articleId nor an action — the plan stays hidden until they carry " +
        "content.",
    );
  }
  // The free entry step is the 7-day one (ADR-0005). A premium 7-day plan is
  // legal but almost always a content mistake, so it is called out.
  if (plan.premium === true && days.length === 7) {
    console.warn(
        `! Plan "${plan.id}" is 7 days AND premium — the 7-day step is the ` +
        "free entry point in ADR-0005. Intentional?",
    );
  }
}

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
  const col = db.collection("plans");

  const plans = JSON.parse(fs.readFileSync(PLANS_PATH, "utf8"));
  const seenIds = new Set();

  const batch = db.batch();
  for (const plan of plans) {
    validatePlan(plan);
    if (seenIds.has(plan.id)) {
      throw new Error(`Duplicate plan id "${plan.id}".`);
    }
    seenIds.add(plan.id);
    const {id, ...data} = plan;
    batch.set(col.doc(id), data, {merge: true});
  }
  await batch.commit();
  console.log(`Upserted ${plans.length} plan(s).`);

  await pruneOrphans(col, seenIds, target, "plan(s) not in plans.json");
}

// Yalnız doğrudan çalıştırılınca Firestore'a bağlanır. `require` edildiğinde
// sadece doğrulama dışa açılır — içerik formatı kimlik bilgisi olmadan ve
// prod'a dokunmadan denetlenebilsin (npm run check:plans).
if (require.main === module) {
  main().catch((err) => {
    console.error("seedPlans failed:", err);
    process.exitCode = 1;
  });
}

module.exports = {validatePlan, PLANS_PATH, LENGTHS, ACTIONS};
