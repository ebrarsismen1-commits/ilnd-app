#!/usr/bin/env node
/**
 * Validates content/plans.json WITHOUT touching Firestore (ADR-0005).
 *
 * Why separate from seedPlans.js: content is written long before anyone has
 * production credentials, and a format mistake found at seed time is found
 * too late — the whole batch fails on the first bad plan. This runs the exact
 * same `validatePlan` the seed uses, plus the two checks the app cares about
 * that the seed only warns on (length must be 7/14/21, every day must carry
 * content) — because a plan failing those is invisible in the app, which is
 * the most confusing failure mode there is.
 *
 * Usage:
 *   npm run check:plans                    (from functions/)
 *   node scripts/checkPlans.js some.json   (any file — used to prove the
 *                                           checks actually fail on bad input)
 */
const fs = require("fs");
const path = require("path");
const {validatePlan, PLANS_PATH, LENGTHS} = require("./seedPlans");

const ARTICLES_PATH = path.join(
    __dirname, "..", "..", "content", "articles.json",
);

const targetPath = process.argv[2] || PLANS_PATH;
const plans = JSON.parse(fs.readFileSync(targetPath, "utf8"));
// A day pointing at an article id that does not exist opens as a day with no
// read at all — the seed cannot catch this because the two files are seeded
// by different scripts.
const articleIds = new Set(
    JSON.parse(fs.readFileSync(ARTICLES_PATH, "utf8")).map((a) => a.id),
);
const problems = [];
const seenIds = new Set();

for (const plan of plans) {
  validatePlan(plan);
  if (seenIds.has(plan.id)) problems.push(`duplicate plan id "${plan.id}"`);
  seenIds.add(plan.id);

  const days = plan.days || [];
  if (!LENGTHS.has(days.length)) {
    problems.push(
        `"${plan.id}": ${days.length} day(s) — must be one of ` +
        `${[...LENGTHS].join("/")} or the plan never appears in the app`,
    );
  }
  for (const day of days) {
    if (!day.articleId && (!day.action || day.action === "none")) {
      problems.push(
          `"${plan.id}" day "${day.id}": neither articleId nor action — ` +
          "the whole plan stays hidden",
      );
    }
    if (!day.title) {
      problems.push(`"${plan.id}" day "${day.id}": missing title`);
    }
    if (day.articleId && !articleIds.has(day.articleId)) {
      problems.push(
          `"${plan.id}" day "${day.id}": articleId "${day.articleId}" is ` +
          "not in articles.json — the day would open with no read",
      );
    }
  }

  // A translation keyed on a day id that does not exist is dead content: the
  // EN user silently gets the Turkish line and nobody notices.
  const dayIds = new Set(days.map((d) => d.id));
  const en = plan.en || {};
  for (const key of Object.keys(en.dayTitles || {})) {
    if (!dayIds.has(key)) {
      problems.push(`"${plan.id}": en.dayTitles has unknown day "${key}"`);
    }
  }
  for (const key of Object.keys(en.dayNotes || {})) {
    if (!dayIds.has(key)) {
      problems.push(`"${plan.id}": en.dayNotes has unknown day "${key}"`);
    }
  }
}

if (problems.length > 0) {
  console.error(`plans.json has ${problems.length} problem(s):`);
  problems.forEach((p) => console.error(`  - ${p}`));
  process.exitCode = 1;
} else {
  const total = plans.reduce((n, p) => n + (p.days || []).length, 0);
  console.log(
      `plans.json OK — ${plans.length} plan(s), ${total} day(s), ` +
      "every one publishable.",
  );
}
