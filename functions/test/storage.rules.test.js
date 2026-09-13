/**
 * Storage güvenlik kuralları — Storage emülatörü gerekir
 * (`firebase emulators:exec` firebase.json'daki storage emülatörünü başlatır).
 * Güvenlik denetimi H-8 (2026-09-13): istemci Storage'a hiç erişemez.
 * Emülatör yoksa (FIREBASE_STORAGE_EMULATOR_HOST tanımsız) dosya atlanır.
 */
const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {ref, uploadString, getBytes, deleteObject, listAll} = require("firebase/storage");

const host = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
const maybe = host ? describe : describe.skip;

jest.setTimeout(30000);

maybe("storage.rules", () => {
  let env;

  beforeAll(async () => {
    const [h, port] = host.split(":");
    env = await initializeTestEnvironment({
      projectId: process.env.GCLOUD_PROJECT || "demo-ilnd-test",
      storage: {
        host: h,
        port: Number(port),
        rules: fs.readFileSync(path.join(__dirname, "..", "..", "storage.rules"), "utf8"),
      },
    });
    await env.withSecurityRulesDisabled(async (ctx) => {
      await uploadString(ref(ctx.storage(), "users/A/avatar.jpg"), "fake");
    });
  });

  afterAll(async () => {
    if (env) {
      await env.clearStorage();
      await env.cleanup();
    }
  });

  const as = (uid) => env.authenticatedContext(uid).storage();

  test("sahibi bile kendi yoluna yükleyemez (istemci yüklemesi yok)", async () => {
    await assertFails(uploadString(ref(as("A"), "users/A/x.jpg"), "data"));
  });

  test("B, A'nın dosyasını okuyamaz, silemez, listeleyemez", async () => {
    const b = as("B");
    await assertFails(getBytes(ref(b, "users/A/avatar.jpg")));
    await assertFails(deleteObject(ref(b, "users/A/avatar.jpg")));
    await assertFails(listAll(ref(b, "users/A")));
  });

  test("kimliksiz kullanıcı hiçbir yola yazamaz ve okuyamaz", async () => {
    const anon = env.unauthenticatedContext().storage();
    await assertFails(uploadString(ref(anon, "public/x.html"), "<script>"));
    await assertFails(getBytes(ref(anon, "users/A/avatar.jpg")));
  });
});
