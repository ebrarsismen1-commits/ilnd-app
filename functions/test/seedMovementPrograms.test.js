/**
 * Runs against the Firebase Emulator Suite — see functions/package.json's
 * `test` script. Exercises the movement program content pipeline (ADR-0004)
 * the same way seedArticles.test.js exercises the article one.
 */
const {execFileSync} = require("child_process");
const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

if (admin.apps.length === 0) admin.initializeApp();

const db = admin.firestore();
const SCRIPT_PATH = path.join(
    __dirname, "..", "scripts", "seedMovementPrograms.js",
);
const CONTENT_PATH = path.join(
    __dirname, "..", "..", "content", "movementPrograms.json",
);

// Her vaka seed script'ini ayrı bir node süreci olarak çalıştırıyor; süreç
// başlatma + emülatöre yazma jest'in 5 sn varsayılanına sığmıyor.
jest.setTimeout(30000);

/**
 * Writes [programs] into content/movementPrograms.json, runs the seed
 * script, then restores the original file. The script reads that fixed path,
 * so the test has to own it for the duration of the run.
 * @param {Array<object>} programs content to seed.
 * @param {string[]} args extra CLI args, e.g. ["--prune"].
 * @return {{status: number, stderr: string}} how the script exited.
 */
function runSeed(programs, args = []) {
  const original = fs.existsSync(CONTENT_PATH) ?
    fs.readFileSync(CONTENT_PATH, "utf8") :
    null;
  fs.writeFileSync(CONTENT_PATH, JSON.stringify(programs, null, 2));
  try {
    execFileSync("node", [SCRIPT_PATH, ...args], {
      env: process.env, // FIRESTORE_EMULATOR_HOST'u taşır
      stdio: "pipe",
    });
    return {status: 0, stderr: ""};
  } catch (err) {
    return {
      status: err.status === undefined ? 1 : err.status,
      stderr: `${err.stderr || ""}${err.stdout || ""}`,
    };
  } finally {
    if (original !== null) fs.writeFileSync(CONTENT_PATH, original);
  }
}

const program = (over = {}) => ({
  id: "sabah",
  title: "sabah açılışı",
  level: "easy",
  order: 0,
  premium: false,
  sessions: [
    {id: "s1", title: "boyun ve omuz", minutes: 6, videoUrl: "https://v/1.mp4"},
  ],
  ...over,
});

describe("seedMovementPrograms", () => {
  afterEach(async () => {
    const snap = await db.collection("movement_programs").get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  });

  test("upserts programs into movement_programs, keyed on the stable id", async () => {
    expect(runSeed([program()]).status).toBe(0);

    const doc = await db.collection("movement_programs").doc("sabah").get();
    expect(doc.exists).toBe(true);
    expect(doc.data().title).toBe("sabah açılışı");
    expect(doc.data().sessions[0].videoUrl).toBe("https://v/1.mp4");
    // id alan olarak DEĞİL doküman kimliği olarak yazılır.
    expect(doc.data().id).toBeUndefined();
  });

  test("is idempotent — a second run does not duplicate", async () => {
    runSeed([program()]);
    runSeed([program({title: "sabah açılışı v2"})]);

    const snap = await db.collection("movement_programs").get();
    expect(snap.size).toBe(1);
    expect(snap.docs[0].data().title).toBe("sabah açılışı v2");
  });

  test("rejects a program with no id (upsert would not be idempotent)", () => {
    const res = runSeed([program({id: undefined})]);
    expect(res.status).not.toBe(0);
    expect(res.stderr).toContain("stable id");
  });

  test("rejects duplicate session ids (progress is keyed on them)", () => {
    const res = runSeed([
      program({
        sessions: [
          {id: "s1", title: "a", videoUrl: "https://v/1.mp4"},
          {id: "s1", title: "b", videoUrl: "https://v/2.mp4"},
        ],
      }),
    ]);
    expect(res.status).not.toBe(0);
    expect(res.stderr).toContain("duplicate session id");
  });

  test("rejects an unknown level instead of silently defaulting", () => {
    const res = runSeed([program({level: "extreme"})]);
    expect(res.status).not.toBe(0);
    expect(res.stderr).toContain("unknown level");
  });

  test("warns but still seeds a program whose sessions have no video yet", async () => {
    const res = runSeed([
      program({sessions: [{id: "s1", title: "yakında", videoUrl: ""}]}),
    ]);

    expect(res.status).toBe(0);
    // Doküman yazılır ama uygulama onu gizler (isPublishable == false).
    const doc = await db.collection("movement_programs").doc("sabah").get();
    expect(doc.exists).toBe(true);
  });

  test("--prune removes programs no longer present in the JSON source", async () => {
    runSeed([program(), program({id: "aksam", title: "akşam indirme"})]);
    expect((await db.collection("movement_programs").get()).size).toBe(2);

    runSeed([program()], ["--prune"]);

    const snap = await db.collection("movement_programs").get();
    expect(snap.docs.map((d) => d.id)).toEqual(["sabah"]);
  });

  test("a plain run (no --prune) leaves other programs alone", async () => {
    runSeed([program(), program({id: "aksam", title: "akşam indirme"})]);
    runSeed([program()]);

    const snap = await db.collection("movement_programs").get();
    expect(snap.size).toBe(2);
  });
});
