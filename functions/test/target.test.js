/**
 * Saf birim testi (emülatörsüz). Güvenlik denetimi C-2: Admin SDK
 * scriptlerinin prod'a kazara yazamadığını kilitler.
 */
const {resolveTarget, pruneOrphans, TargetError} = require("../scripts/lib/target");

const PROD = "ilnd-app-8dcbd";

describe("resolveTarget", () => {
  test("hedef yoksa ve emülatör değilse çalışmayı reddeder", () => {
    expect(() => resolveTarget({argv: [], env: {}})).toThrow(TargetError);
  });

  test("ortamdaki GCLOUD_PROJECT tek başına hedef sayılmaz", () => {
    expect(() => resolveTarget({argv: [], env: {GCLOUD_PROJECT: PROD}})).toThrow(/explicit target/);
  });

  test("prod'a yazma onaysız reddedilir", () => {
    expect(() => resolveTarget({argv: [`--project=${PROD}`], env: {}})).toThrow(/PRODUCTION/);
    expect(() => resolveTarget({argv: ["--project", PROD], env: {}})).toThrow(/PRODUCTION/);
  });

  test("prod'a yazma --confirm-prod ile açılır", () => {
    const t = resolveTarget({argv: [`--project=${PROD}`, "--confirm-prod"], env: {}});
    expect(t).toMatchObject({projectId: PROD, isProd: true, prune: false});
  });

  test("prod'da --prune onaysızsa kuru çalışmadır", () => {
    const t = resolveTarget({argv: [`--project=${PROD}`, "--confirm-prod", "--prune"], env: {}});
    expect(t.pruneDryRun).toBe(true);
    const confirmed = resolveTarget({argv: [`--project=${PROD}`, "--confirm-prod", "--prune", "--confirm-prune"], env: {}});
    expect(confirmed.pruneDryRun).toBe(false);
  });

  test("salt okunur script prod'u onaysız okuyabilir", () => {
    const t = resolveTarget({argv: [`--project=${PROD}`], env: {}, writes: false});
    expect(t.isProd).toBe(true);
  });

  test("prod olmayan proje onay istemez, prune gerçekten siler", () => {
    const t = resolveTarget({argv: ["--project=ilnd-staging", "--prune"], env: {}});
    expect(t).toMatchObject({isProd: false, pruneDryRun: false});
  });

  test("emülatörde hedef ortamdan gelir ve prod sayılmaz", () => {
    const t = resolveTarget({argv: ["--prune"], env: {FIRESTORE_EMULATOR_HOST: "localhost:8080", GCLOUD_PROJECT: "demo-ilnd-test"}});
    expect(t).toMatchObject({projectId: "demo-ilnd-test", emulator: true, isProd: false, pruneDryRun: false});
  });
});

describe("pruneOrphans", () => {
  const fakeCol = (ids) => {
    const deleted = [];
    const col = {
      get: async () => ({docs: ids.map((id) => ({id, ref: id}))}),
      firestore: {
        batch: () => ({delete: (ref) => deleted.push(ref), commit: async () => {}}),
      },
    };
    return {col, deleted};
  };

  test("kuru çalışma hiçbir şey silmez", async () => {
    const {col, deleted} = fakeCol(["keep", "stale"]);
    const ids = await pruneOrphans(col, new Set(["keep"]), {prune: true, pruneDryRun: true}, "x");
    expect(ids).toEqual(["stale"]);
    expect(deleted).toEqual([]);
  });

  test("onaylı çalışma yalnız kaynakta olmayanları siler", async () => {
    const {col, deleted} = fakeCol(["keep", "stale"]);
    await pruneOrphans(col, new Set(["keep"]), {prune: true, pruneDryRun: false}, "x");
    expect(deleted).toEqual(["stale"]);
  });

  test("--prune yoksa koleksiyonu okumaz bile", async () => {
    const col = {get: jest.fn()};
    await pruneOrphans(col, new Set(), {prune: false}, "x");
    expect(col.get).not.toHaveBeenCalled();
  });
});
