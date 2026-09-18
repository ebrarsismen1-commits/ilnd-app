/**
 * Supabase profiles → Firestore users/{uid} taşıma script'i.
 * Saf mantık + PostgREST sayfalama emülatörsüz; uçtan uca kısım Auth ve
 * Firestore emülatörüne karşı, script ayrı süreç olarak koşar (gerçek
 * kullanımdaki gibi). Gerçek Supabase'e hiçbir istek gitmez.
 */
const {execFileSync} = require("child_process");
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");
const admin = require("firebase-admin");
const {mapProfileRow, planMigration, summarize} = require("../scripts/lib/profileMigration");
const {fetchSupabaseProfiles, supabaseAdminHeaders} = require("../scripts/migrateSupabaseProfiles");

const SCRIPT = path.join(__dirname, "..", "scripts", "migrateSupabaseProfiles.js");
jest.setTimeout(60000);

const row = (id, over = {}) => ({
  id,
  name: "Ela",
  updated_at: "2026-07-01T10:00:00Z",
  onboarding_done: true,
  first_entry_done: true,
  goals: ["uyku", "stres"],
  activity_level: "aktif",
  diet: "vegan",
  allergies: ["gluten"],
  age: 31,
  height: 168,
  weight: 72,
  ...over,
});

describe("mapProfileRow", () => {
  test("snake_case → camelCase, height/weight → heightCm/weightKg", () => {
    expect(mapProfileRow(row("x"))).toEqual({
      fields: {
        name: "Ela", onboardingDone: true, firstEntryDone: true,
        goals: ["uyku", "stres"], activityLevel: "aktif", diet: "vegan",
        allergies: ["gluten"], age: 31, heightCm: 168, weightKg: 72,
      },
      dropped: [],
    });
  });

  test("null/boş değerler yazılmaz; updated_at ve id taşınmaz", () => {
    const {fields} = mapProfileRow(row("x", {name: "", diet: null, age: null, goals: []}));
    expect(fields).not.toHaveProperty("name");
    expect(fields).not.toHaveProperty("diet");
    expect(fields).not.toHaveProperty("age");
    expect(fields).not.toHaveProperty("updated_at");
    expect(fields).not.toHaveProperty("id");
    expect(fields.goals).toEqual([]);
  });

  test("kural sınırı dışındaki değerler yazılmaz, raporlanır", () => {
    const {fields, dropped} = mapProfileRow(row("x", {
      age: 200, weight: 701, name: "x".repeat(101), goals: Array(51).fill("g"),
    }));
    expect(dropped.sort()).toEqual(["age", "goals", "name", "weight"]);
    expect(fields).not.toHaveProperty("age");
    expect(fields.heightCm).toBe(168);
  });
});

describe("planMigration", () => {
  const A = "11111111-1111-1111-1111-111111111111";
  const B = "22222222-2222-2222-2222-222222222222";
  const C = "33333333-3333-3333-3333-333333333333";
  const D = "44444444-4444-4444-4444-444444444444";

  test("eksik kullanıcı, çift kayıt, geçersiz id ve Firestore'da yeni profil ayrışır", () => {
    const rows = [row(A), row(B), row(B), row(C), row(D), row("not-a-uuid")];
    const plan = planMigration({
      rows,
      authUids: new Set([A, B, D]),
      existing: new Map([[A, {photoBase64: "AAAA"}], [D, {profileUpdatedAt: new Date()}]]),
    });
    expect(plan.toMigrate.map((m) => m.uid)).toEqual([A]);
    expect(plan.duplicates).toEqual([B]);
    expect(plan.missingUsers).toEqual([C]);
    expect(plan.alreadyOnFirestore).toEqual([D]);
    expect(plan.invalidIds).toEqual(["not-a-uuid"]);

    const s = summarize({rows, plan, apply: false});
    expect(s).toMatchObject({
      mode: "dry-run", totalProfiles: 6, matchedUsers: 2, migrated: 0, wouldMigrate: 1,
      skipped: 1, missingUsers: 1, duplicates: 1, invalidIds: 1, failed: 0,
    });
  });
});

describe("fetchSupabaseProfiles", () => {
  test("sayfalar, service key'i yalnız başlıkta gönderir", async () => {
    const calls = [];
    const pages = [Array.from({length: 1000}, (_, i) => ({id: `a${i}`})), [{id: "last"}]];
    const fetchImpl = async (url, opts) => {
      calls.push({url, opts});
      return {ok: true, status: 200, json: async () => pages[calls.length - 1]};
    };
    const rows = await fetchSupabaseProfiles({url: "https://sb.test/", key: "eyJk-123", fetchImpl});
    expect(rows).toHaveLength(1001);
    expect(calls[0].url).toMatch(/^https:\/\/sb\.test\/rest\/v1\/profiles\?select=id,name,.*&offset=0$/);
    expect(calls[1].url).toMatch(/offset=1000$/);
    expect(calls[0].url).not.toContain("k-123");
    expect(calls[0].opts.headers.Authorization).toBe("Bearer eyJk-123");
  });

  test("sb_secret anahtarı yalnız apikey başlığında gider (Bearer'da 401 olur)", () => {
    expect(supabaseAdminHeaders(" sb_secret_abc \n")).toEqual({apikey: "sb_secret_abc"});
    expect(supabaseAdminHeaders("eyJx.y.z")).toEqual({apikey: "eyJx.y.z", Authorization: "Bearer eyJx.y.z"});
  });

  test("HTTP hatası gövdeyi değil yalnız durum kodunu taşır", async () => {
    const fetchImpl = async () => ({ok: false, status: 401, json: async () => ({msg: "secret-ish"})});
    await expect(fetchSupabaseProfiles({url: "https://sb.test", key: "k", fetchImpl}))
        .rejects.toThrow("HTTP 401");
  });
});

describe("uçtan uca (emülatör)", () => {
  if (admin.apps.length === 0) admin.initializeApp();
  const db = admin.firestore();
  const uid = () => crypto.randomUUID();
  const A = uid(); // Auth'ta var, dokümanı yok
  const B = uid(); // Auth'ta var, yalnız fotoğrafı var
  const C = uid(); // Auth'ta YOK
  const D = uid(); // Auth'ta var, uygulama profili zaten Firestore'a yazmış
  const F = uid(); // Auth'ta var, sınır dışı yaş
  const SECRET = "sb-service-role-should-never-be-printed";
  let input;

  const run = (args, envOver = {}) => {
    try {
      const out = execFileSync("node", [SCRIPT, `--input=${input}`, ...args], {
        env: {...process.env, SUPABASE_SERVICE_ROLE_KEY: SECRET, ...envOver},
        stdio: "pipe",
      }).toString();
      return {status: 0, out};
    } catch (err) {
      return {status: err.status, out: `${err.stdout || ""}${err.stderr || ""}`};
    }
  };

  beforeAll(async () => {
    for (const u of [A, B, D, F]) await admin.auth().createUser({uid: u});
    input = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "mig-")), "profiles.json");
    fs.writeFileSync(input, JSON.stringify([
      row(A), row(B, {name: "Deniz"}), row(C), row(D, {weight: 99}), row(F, {age: 200}),
    ]));
  });

  beforeEach(async () => {
    await Promise.all([A, B, C, D, F].map((u) => db.doc(`users/${u}`).delete()));
    await db.doc(`users/${B}`).set({photoBase64: "AAAA", photoUpdatedAt: admin.firestore.Timestamp.now()});
    await db.doc(`users/${D}`).set({weightKg: 60, profileUpdatedAt: admin.firestore.Timestamp.now()});
  });

  afterAll(async () => {
    await Promise.all([A, B, C, D, F].map((u) => db.recursiveDelete(db.doc(`users/${u}`))));
    await admin.auth().deleteUsers([A, B, D, F]);
  });

  test("varsayılan kuru çalışma: özet doğru, hiçbir şey yazılmaz", async () => {
    const {status, out} = run([]);
    expect(status).toBe(0);
    expect(out).toContain("DRY RUN");
    expect(out).toMatch(/"totalProfiles": 5/);
    expect(out).toMatch(/"matchedUsers": 4/);
    expect(out).toMatch(/"wouldMigrate": 3/);
    expect(out).toMatch(/"migrated": 0/);
    expect(out).toMatch(/"skipped": 1/);
    expect(out).toMatch(/"missingUsers": 1/);
    expect(out).toContain(C);
    expect((await db.doc(`users/${A}`).get()).exists).toBe(false);
    expect((await db.doc(`users/${B}`).get()).data()).toEqual({
      photoBase64: "AAAA", photoUpdatedAt: expect.anything(),
    });
  });

  test("--apply: merge ile yazar, mevcut alanı ve yeni profili korur", async () => {
    const {status, out} = run(["--apply"]);
    expect(status).toBe(0);
    expect(out).toMatch(/"migrated": 3/);

    const a = (await db.doc(`users/${A}`).get()).data();
    expect(a).toMatchObject({
      name: "Ela", onboardingDone: true, firstEntryDone: true, goals: ["uyku", "stres"],
      activityLevel: "aktif", diet: "vegan", allergies: ["gluten"], age: 31,
      heightCm: 168, weightKg: 72, profileMigratedFrom: "supabase",
    });
    expect(a.profileMigratedAt).toBeDefined();
    // Tekrar çalıştırılabilsin diye istemci damgası konmaz.
    expect(a).not.toHaveProperty("profileUpdatedAt");
    expect(a).not.toHaveProperty("updated_at");
    expect(a).not.toHaveProperty("height");

    // Fotoğraf silinmedi, profil eklendi.
    expect((await db.doc(`users/${B}`).get()).data()).toMatchObject({photoBase64: "AAAA", name: "Deniz"});
    // Auth'ta olmayan kullanıcıya doküman açılmadı.
    expect((await db.doc(`users/${C}`).get()).exists).toBe(false);
    // Uygulamanın yazdığı daha yeni profil ezilmedi.
    expect((await db.doc(`users/${D}`).get()).data().weightKg).toBe(60);
    // Sınır dışı yaş yazılmadı, gerisi yazıldı ve raporlandı.
    const f = (await db.doc(`users/${F}`).get()).data();
    expect(f).not.toHaveProperty("age");
    expect(f.weightKg).toBe(72);
    expect(out).toMatch(/"sanitizedProfiles": 1/);
  });

  test("tekrar çalıştırmak güvenli; uygulama yazdıktan sonra o kullanıcı atlanır", async () => {
    expect(run(["--apply"]).status).toBe(0);
    await db.doc(`users/${A}`).set({weightKg: 65, profileUpdatedAt: admin.firestore.Timestamp.now()}, {merge: true});
    const {status, out} = run(["--apply"]);
    expect(status).toBe(0);
    expect(out).toMatch(/"migrated": 2/);
    expect(out).toMatch(/"skipped": 2/);
    expect((await db.doc(`users/${A}`).get()).data().weightKg).toBe(65);
  });

  test("gizli anahtar ve kişisel veri (ad) çıktıda yok", () => {
    const {out} = run(["--apply"]);
    expect(out).not.toContain(SECRET);
    expect(out).not.toContain("Ela");
    expect(out).not.toContain("gluten");
  });

  test("emülatör dışında hedefsiz çalışmayı reddeder", () => {
    const env = {FIRESTORE_EMULATOR_HOST: "", FIREBASE_AUTH_EMULATOR_HOST: ""};
    const {status, out} = run([], env);
    expect(status).not.toBe(0);
    expect(out).toMatch(/explicit target/);
  });

  test("prod'a --confirm-prod olmadan yazmayı reddeder", () => {
    const env = {FIRESTORE_EMULATOR_HOST: "", FIREBASE_AUTH_EMULATOR_HOST: ""};
    const {status, out} = run(["--project=ilnd-app-8dcbd", "--apply"], env);
    expect(status).not.toBe(0);
    expect(out).toMatch(/PRODUCTION/);
  });
});
