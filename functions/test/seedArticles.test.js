const {execSync} = require("child_process");
const path = require("path");
const admin = require("firebase-admin");

// Diğer test dosyaları ../index'i import ettiği için initializeApp() orada
// çalışıyor; bu dosya yalnız seed SCRIPT'ini test ediyor ve index'e hiç
// dokunmuyor. Jest her test dosyasına ayrı bir modül kaydı verdiğinden
// varsayılan app burada hiç oluşmuyordu ve suite "The default Firebase app
// does not exist" ile daha ilk satırda düşüyordu.
if (admin.apps.length === 0) admin.initializeApp();

const db = admin.firestore();
const SCRIPT_PATH = path.join(__dirname, "..", "scripts", "seedArticles.js");

// Her vaka seed script'ini AYRI bir node süreci olarak (bazıları iki kez)
// çalıştırıyor; süreç başlatma + emülatöre yazma jest'in 5 sn varsayılanına
// sığmıyor. Yavaşlık testin değil, kurulumun doğası.
jest.setTimeout(30000);

/**
 * @param {string[]} args extra CLI args, e.g. ["--prune"].
 * @return {void}
 */
function runSeedScript(args = []) {
  execSync(`node ${SCRIPT_PATH} ${args.join(" ")}`, {
    env: process.env, // carries FIRESTORE_EMULATOR_HOST through
    stdio: "pipe",
  });
}

describe("seedArticles script", () => {
  afterEach(async () => {
    const snap = await db.collection("articles").get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  });

  test("upserts every article from content/articles.json", () => {
    runSeedScript();
  });

  test("is idempotent — running it twice doesn't duplicate or error", async () => {
    runSeedScript();
    const firstRun = await db.collection("articles").get();
    const firstCount = firstRun.size;

    runSeedScript();
    const secondRun = await db.collection("articles").get();

    expect(secondRun.size).toBe(firstCount);
  });

  test("--prune removes articles no longer present in the JSON source", async () => {
    runSeedScript();
    await db.collection("articles").doc("stale-article-not-in-json").set({
      title: "should be pruned",
      order: 999,
    });

    runSeedScript(["--prune"]);

    const stale = await db.collection("articles").doc("stale-article-not-in-json").get();
    expect(stale.exists).toBe(false);
  });

  test("a plain run (no --prune) leaves orphaned docs alone", async () => {
    runSeedScript();
    await db.collection("articles").doc("manually-added-article").set({
      title: "manually added, not in JSON",
      order: 999,
    });

    runSeedScript();

    const manual = await db.collection("articles").doc("manually-added-article").get();
    expect(manual.exists).toBe(true);
  });
});
