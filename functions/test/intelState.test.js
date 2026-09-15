const fs = require("fs");
const path = require("path");
const {deriveNights, computeBaseline} = require("../intel/nights");
const {computeIntelState, ENGINE_VERSION} = require("../intel/state");
const {addDays} = require("../intel/nightKey");

/**
 * Kalite türetmesi, baseline ve durumun bir araya gelmesi (ADR-0009 §2–§4, §8).
 */

const OFFSET = 180;
const localMs = (iso, offset = OFFSET) => Date.parse(`${iso}Z`) - offset * 60000;

/**
 * Geçerli bir gece: akşam yerel 21:00, sabah ertesi gün yerel 08:00.
 * @param {string} nightKey gece
 * @param {{mood?: number, energy?: number, eveningOffset?: number,
 *   morningOffset?: number}} values değerler
 * @return {object} ham gece
 */
function night(nightKey, {mood, energy, eveningOffset = OFFSET, morningOffset = OFFSET} = {}) {
  const doc = {nightKey};
  if (mood !== undefined) {
    doc.evening = {mood, tzOffsetMin: eveningOffset,
      createdAtMs: localMs(`${nightKey}T21:00:00`, eveningOffset)};
  }
  if (energy !== undefined) {
    doc.morning = {energy, tzOffsetMin: morningOffset,
      createdAtMs: localMs(`${addDays(nightKey, 1)}T08:00:00`, morningOffset)};
  }
  return doc;
}

describe("deriveNights", () => {
  test("aralık dışı ya da tam sayı olmayan değer taraf olarak sayılmaz", () => {
    const out = deriveNights([
      night("2026-09-01", {mood: 0, energy: 3}),
      night("2026-09-02", {mood: 2.5, energy: 6}),
      night("2026-09-03", {mood: "3", energy: 4}),
    ]);
    expect(out).toEqual([
      {nightKey: "2026-09-01", mood: null, energy: 3, tzShift: false},
      {nightKey: "2026-09-03", mood: null, energy: 4, tzShift: false},
    ]);
  });

  test("pencere dışı saatteki taraf yok sayılır", () => {
    const doc = night("2026-09-01", {mood: 3, energy: 3});
    doc.evening.createdAtMs = localMs("2026-09-01T15:00:00");
    doc.morning.createdAtMs = localMs("2026-09-02T14:30:00");
    expect(deriveNights([doc])).toEqual([]);
  });

  test("başka geceye ait saat (anahtar uyuşmazlığı) yok sayılır", () => {
    const doc = night("2026-09-01", {mood: 3});
    doc.evening.createdAtMs = localMs("2026-09-02T21:00:00");
    expect(deriveNights([doc])).toEqual([]);
  });

  test("sırasız girdi sıralanır, aynı anahtar iki kez gelirse ikisi de atılır", () => {
    const out = deriveNights([
      night("2026-09-03", {mood: 4}),
      night("2026-09-01", {mood: 3}),
      night("2026-09-02", {mood: 1}),
      night("2026-09-02", {mood: 5}),
    ]);
    expect(out.map((n) => n.nightKey)).toEqual(["2026-09-01", "2026-09-03"]);
  });

  test("aynı gecede ≥120 dk fark seyahattir", () => {
    const [n] = deriveNights([night("2026-09-01", {mood: 3, energy: 3, morningOffset: -300})]);
    expect(n.tzShift).toBe(true);
  });

  test("yaz saati (60 dk) seyahat değildir", () => {
    const out = deriveNights([
      night("2026-09-01", {mood: 3, energy: 3}),
      night("2026-09-02", {mood: 3, energy: 3, eveningOffset: 120, morningOffset: 120}),
    ]);
    expect(out.map((n) => n.tzShift)).toEqual([false, false]);
  });

  test("seyahatten sonra yalnız geçiş gecesi işaretlenir", () => {
    const out = deriveNights([
      night("2026-09-01", {mood: 3, energy: 3}),
      night("2026-09-02", {mood: 3, energy: 3, eveningOffset: -300, morningOffset: -300}),
      night("2026-09-03", {mood: 3, energy: 3, eveningOffset: -300, morningOffset: -300}),
    ]);
    expect(out.map((n) => n.tzShift)).toEqual([false, true, false]);
  });
});

describe("computeBaseline", () => {
  const energies = [3, 4, 2, 3, 3, 4, 5, 3, 2, 4];

  test("ADR örneği: 10 sabah → 3.3", () => {
    const derived = deriveNights(energies.map((e, i) => night(addDays("2026-09-05", i), {energy: e})));
    const baseline = computeBaseline(derived, "2026-09-14");
    expect(baseline.energyN).toBe(10);
    expect(baseline.energyMean).toBeCloseTo(3.3, 10);
  });

  test("6 sabah null, 7 sabah ortalama", () => {
    const six = deriveNights([1, 2, 3, 4, 5, 3].map((e, i) => night(addDays("2026-09-01", i), {energy: e})));
    expect(computeBaseline(six, "2026-09-06").energyMean).toBeNull();
    const seven = deriveNights([1, 2, 3, 4, 5, 3, 3].map((e, i) => night(addDays("2026-09-01", i), {energy: e})));
    expect(computeBaseline(seven, "2026-09-07").energyMean).toBeCloseTo(3, 10);
  });

  test("28 günlük pencerenin dışı ve seyahat gecesi sayılmaz", () => {
    const asOf = "2026-09-28";
    const nights = [
      night(addDays(asOf, -28), {energy: 5}),
      night(addDays(asOf, -27), {energy: 1}),
      night(asOf, {energy: 3, morningOffset: -300, mood: 3}),
    ];
    const baseline = computeBaseline(deriveNights(nights), asOf);
    expect(baseline.energyN).toBe(1);
  });
});

describe("computeIntelState", () => {
  test("boş girdi güvenli bir boş durum döner", () => {
    const state = computeIntelState({uid: "u1", nights: []});
    expect(state.asOfNight).toBeNull();
    expect(state.engineVersion).toBe(ENGINE_VERSION);
    expect(state.baseline).toEqual({windowDays: 28, energyMean: null, energyN: 0});
    expect(state.p5.shownState).toBe("forming");
    expect(state.p5.status).toBe("insufficient");
  });

  test("uid olmadan hesap yapılmaz", () => {
    expect(() => computeIntelState({uid: "", nights: []})).toThrow(TypeError);
  });

  test("aynı girdi aynı çıktı ve aynı inputHash", () => {
    const nights = Array.from({length: 25}, (_, i) =>
      night(addDays("2026-08-01", i), {mood: (i % 5) + 1, energy: ((i * 3) % 5) + 1}));
    const a = computeIntelState({uid: "u1", nights});
    const b = computeIntelState({uid: "u1", nights: [...nights].reverse()});
    expect(b).toEqual(a);
  });

  test("bir değer düzenlenince inputHash değişir", () => {
    const nights = Array.from({length: 12}, (_, i) => night(addDays("2026-08-01", i), {mood: 3, energy: 3}));
    const before = computeIntelState({uid: "u1", nights}).inputHash;
    nights[4].morning.energy = 5;
    expect(computeIntelState({uid: "u1", nights}).inputHash).not.toBe(before);
  });
});

describe("saflık", () => {
  test("intel modülleri yalnız birbirini ister: ağ, Firebase ya da LLM yok", () => {
    const dir = path.join(__dirname, "..", "intel");
    for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".js"))) {
      // Yorumlar ayıklanır: "Math.random bilerek kullanılmaz" gibi bir açıklama
      // yasak kullanım sayılmasın.
      const source = fs.readFileSync(path.join(dir, file), "utf8")
          .replace(/\/\*[\s\S]*?\*\//g, "")
          .replace(/\/\/.*$/gm, "");
      const requires = [...source.matchAll(/require\(\s*["']([^"']+)["']\s*\)/g)].map((m) => m[1]);
      for (const spec of requires) expect(spec.startsWith("./")).toBe(true);
      expect(source).not.toMatch(/Math\.random|Date\.now|new Date\(\)/);
    }
  });
});
