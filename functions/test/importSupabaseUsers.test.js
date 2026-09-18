/**
 * Supabase auth.users → Firebase Auth taşıma script'i (ADR-0010).
 * Saf mantık + GoTrue sayfalama emülatörsüz; uçtan uca kısım Auth
 * emülatörüne karşı ayrı süreç olarak. Gerçek Supabase'e istek gitmez.
 */
const {execFileSync} = require("child_process");
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");
const admin = require("firebase-admin");
const {normalizeSupabaseUser, planUserImport} = require("../scripts/lib/userImport");
const {fetchSupabaseUsers} = require("../scripts/importSupabaseUsers");

const SCRIPT = path.join(__dirname, "..", "scripts", "importSupabaseUsers.js");
jest.setTimeout(60000);

const sbUser = (id, email, over = {}) => ({
  id,
  email,
  email_confirmed_at: "2026-07-01T10:00:00Z",
  user_metadata: {name: "Ela"},
  app_metadata: {provider: "email", providers: ["email"]},
  is_anonymous: false,
  ...over,
});

describe("normalizeSupabaseUser", () => {
  test("admin API ve SQL dışa aktarım biçimlerini okur", () => {
    const id = crypto.randomUUID();
    expect(normalizeSupabaseUser(sbUser(id, " Ela@X.com "))).toEqual({
      id, email: "ela@x.com", emailVerified: true, displayName: "Ela",
      providers: ["email"], anonymous: false,
    });
    const sql = normalizeSupabaseUser({
      id, email: "a@x.com", email_confirmed_at: null,
      raw_user_meta_data: {}, raw_app_meta_data: {provider: "email"},
    });
    expect(sql).toMatchObject({emailVerified: false, displayName: null, providers: ["email"]});
  });
});

describe("planUserImport", () => {
  const [A, B, C, D, E, F, G] = Array.from({length: 7}, () => crypto.randomUUID());

  test("yarat / e-posta ekle / zaten var / çakışma / atla ayrışır", () => {
    const users = [
      sbUser(A, "a@x.com"), // Firebase'te yok → yarat
      sbUser(B, "b@x.com"), // köprü kaydı, e-postasız → e-posta ekle
      sbUser(C, "c@x.com"), // zaten taşınmış
      sbUser(D, "d@x.com"), // e-posta başka uid'de → çakışma
      sbUser(E, null), // e-postasız
      sbUser(F, "f@x.com", {app_metadata: {providers: ["email", "google"]}}),
      sbUser(G, "g@x.com", {is_anonymous: true}),
      sbUser("not-a-uuid", "z@x.com"),
    ].map(normalizeSupabaseUser);
    const plan = planUserImport({
      users,
      firebaseByUid: new Map([[B, {}], [C, {email: "c@x.com"}]]),
      firebaseUidByEmail: new Map([["c@x.com", C], ["d@x.com", "someone-else"]]),
    });
    expect(plan.create.map((p) => p.uid)).toEqual([A]);
    expect(plan.create[0].attrs).toEqual({email: "a@x.com", emailVerified: true, displayName: "Ela"});
    expect(plan.addEmail.map((p) => p.uid)).toEqual([B]);
    expect(plan.alreadyImported).toEqual([C]);
    expect(plan.conflicts).toEqual([{uid: D, reason: "email-used-by-other-uid"}]);
    expect(plan.noEmail).toEqual([E]);
    expect(plan.unsupportedProvider).toEqual([{uid: F, providers: ["google"]}]);
    expect(plan.anonymous).toEqual([G]);
    expect(plan.invalid).toEqual(["not-a-uuid"]);
  });

  test("aynı uid ya da aynı e-posta iki kez → ikisine de dokunulmaz", () => {
    const users = [sbUser(A, "a@x.com"), sbUser(B, "A@x.com")].map(normalizeSupabaseUser);
    const plan = planUserImport({users, firebaseByUid: new Map(), firebaseUidByEmail: new Map()});
    expect(plan.create).toEqual([]);
    expect(plan.duplicates).toEqual([A, B]);
  });
});

describe("fetchSupabaseUsers", () => {
  test("sayfalar; anahtar yalnız başlıkta", async () => {
    const calls = [];
    const pages = [{users: Array.from({length: 1000}, (_, i) => ({id: `u${i}`}))}, {users: [{id: "last"}]}];
    const fetchImpl = async (url, opts) => {
      calls.push({url, opts});
      return {ok: true, status: 200, json: async () => pages[calls.length - 1]};
    };
    const users = await fetchSupabaseUsers({url: "https://sb.test", key: "sb_secret_k-9", fetchImpl});
    expect(users).toHaveLength(1001);
    expect(calls[1].url).toBe("https://sb.test/auth/v1/admin/users?page=2&per_page=1000");
    expect(calls[0].url).not.toContain("k-9");
    // sb_secret: yalnız apikey (Authorization: Bearer'da platform 401 döner).
    expect(calls[0].opts.headers).toEqual({apikey: "sb_secret_k-9"});
  });

  test("HTTP hatasında yalnız durum kodu", async () => {
    const fetchImpl = async () => ({ok: false, status: 403, json: async () => ({})});
    await expect(fetchSupabaseUsers({url: "https://sb.test", key: "k", fetchImpl}))
        .rejects.toThrow("HTTP 403");
  });
});

describe("uçtan uca (Auth emülatörü)", () => {
  if (admin.apps.length === 0) admin.initializeApp();
  const A = crypto.randomUUID(); // yok → yaratılır
  const B = crypto.randomUUID(); // köprü kaydı (e-postasız) → e-posta eklenir
  const U = crypto.randomUUID(); // doğrulanmamış
  const tag = crypto.randomUUID().slice(0, 8);
  const email = (x) => `${x}-${tag}@example.com`;
  let input;

  const run = (args, envOver = {}) => {
    try {
      const out = execFileSync("node", [SCRIPT, `--input=${input}`, ...args], {
        env: {...process.env, ...envOver}, stdio: "pipe",
      }).toString();
      return {status: 0, out};
    } catch (err) {
      return {status: err.status, out: `${err.stdout || ""}${err.stderr || ""}`};
    }
  };

  beforeAll(() => {
    input = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "users-")), "users.json");
    fs.writeFileSync(input, JSON.stringify([
      sbUser(A, email("a")),
      sbUser(B, email("b")),
      sbUser(U, email("u"), {email_confirmed_at: null}),
    ]));
  });

  beforeEach(async () => {
    await admin.auth().deleteUsers([A, B, U]);
    await admin.auth().createUser({uid: B}); // köprünün bıraktığı kayıt
  });

  afterAll(async () => {
    await admin.auth().deleteUsers([A, B, U]);
  });

  test("varsayılan kuru çalışma hiçbir şey yazmaz", async () => {
    const {status, out} = run([]);
    expect(status).toBe(0);
    expect(out).toContain("DRY RUN");
    expect(out).toMatch(/"wouldCreate": 2/);
    expect(out).toMatch(/"wouldAddEmail": 1/);
    await expect(admin.auth().getUser(A)).rejects.toThrow();
    expect((await admin.auth().getUser(B)).email).toBeUndefined();
  });

  test("--apply: aynı uid, e-posta, doğrulama durumu; şifre yok", async () => {
    const {status, out} = run(["--apply"]);
    expect(status).toBe(0);
    expect(out).toMatch(/"created": 2/);
    expect(out).toMatch(/"emailAdded": 1/);

    const a = await admin.auth().getUser(A);
    expect(a).toMatchObject({email: email("a"), emailVerified: true, displayName: "Ela"});
    expect(a.passwordHash).toBeUndefined();
    const b = await admin.auth().getUser(B);
    expect(b.email).toBe(email("b"));
    expect((await admin.auth().getUser(U)).emailVerified).toBe(false);

    // Tekrar çalıştırmak zararsız.
    const again = run(["--apply"]);
    expect(again.out).toMatch(/"alreadyImported": 3/);
    expect(again.out).toMatch(/"created": 0/);
  });

  test("çıktıda e-posta adresi yok", () => {
    const {out} = run(["--apply"]);
    expect(out).not.toContain(tag);
    expect(out).not.toContain("@example.com");
  });

  test("prod'a --confirm-prod olmadan yazmayı reddeder", () => {
    const env = {FIRESTORE_EMULATOR_HOST: "", FIREBASE_AUTH_EMULATOR_HOST: ""};
    const {status, out} = run(["--project=ilnd-app-8dcbd", "--apply"], env);
    expect(status).not.toBe(0);
    expect(out).toMatch(/PRODUCTION/);
  });
});
