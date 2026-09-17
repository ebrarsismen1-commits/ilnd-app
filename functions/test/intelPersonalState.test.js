const fs = require("fs");
const path = require("path");
const {
  THRESHOLDS,
  nightsBetween,
  bandOf,
  classifyChange,
  summarizeVariable,
  computePersonalState,
  isStale,
} = require("../intel/personalState");
const {addDays} = require("../intel/nightKey");
const {mulberry32} = require("../intel/random");

/**
 * Seviye 2 Kişisel Durum sözleşmesi (ADR-0010). Eşikler ADR ile aynı kalmalı;
 * bir test kalırsa eşik değil kod düzeltilir.
 */

const OFFSET = 180;
const localMs = (iso, offset = OFFSET) => Date.parse(`${iso}Z`) - offset * 60000;
const AS_OF = "2026-09-30";

/**
 * @param {string} nightKey gece
 * @param {{mood?: number, energy?: number, eveningOffset?: number,
 *   morningOffset?: number, eveningTime?: string, morningTime?: string}} v
 * @return {object} ham gece
 */
function night(nightKey, v = {}) {
  const doc = {nightKey};
  if (v.mood !== undefined) {
    const offset = v.eveningOffset ?? OFFSET;
    doc.evening = {mood: v.mood, tzOffsetMin: offset,
      createdAtMs: localMs(`${nightKey}T${v.eveningTime || "21:00:00"}`, offset)};
  }
  if (v.energy !== undefined) {
    const offset = v.morningOffset ?? OFFSET;
    doc.morning = {energy: v.energy, tzOffsetMin: offset,
      createdAtMs: localMs(`${addDays(nightKey, 1)}T${v.morningTime || "08:00:00"}`, offset)};
  }
  return doc;
}

/**
 * asOf'tan geriye verilen ofsetlerde yalnız sabah kayıtları.
 * @param {Array<[number, number]>} pairs [geriOfset, enerji]
 * @param {string} [asOf] referans
 * @return {object[]} geceler
 */
function mornings(pairs, asOf = AS_OF) {
  return pairs.map(([back, energy]) => night(addDays(asOf, -back), {energy}));
}

/**
 * Enerji bölümünü döner.
 * @param {object[]} nights geceler
 * @param {object} [previous] önceki durum
 * @return {object} enerji bölümü
 */
function energyOf(nights, previous = null) {
  return computePersonalState({nights, previous}).energy;
}

/**
 * Son 7 gecede n kayıt: asOf'tan başlayarak geriye.
 * @param {number} n kayıt sayısı
 * @param {number} value değer
 * @return {Array<[number, number]>} [geriOfset, değer]
 */
const recentBlock = (n, value) => Array.from({length: n}, (_, i) => [i, value]);

describe("bandOf (ADR-0010 §4)", () => {
  test.each([
    [3, 1, "3"],
    [5, 1, "5"],
    [1, 1, "1"],
    [3, 2, "1_2"], // 1.50
    [9, 2, "4_5"], // 4.50
    [67, 20, "3_4"], // 3.35: tam sınır, dahil
    [167, 50, "3"], // 3.34: sınır dışı
    [73, 20, "3_4"], // 3.65: tam sınır, dahil
    [183, 50, "4"], // 3.66
    [249, 100, "2_3"], // 2.49
    [6, 5, "1"], // 1.20
    [133, 50, "3"], // 2.66 → round 3
    [265, 100, "2_3"], // 2.65: tam sınır, dahil
    [131, 50, "2_3"], // 2.62 → |2.62 − 2.5| = 0.12
  ])("toplam %i / n %i → %s", (sum, n, expected) => {
    expect(bandOf(sum, n)).toBe(expected);
  });
});

describe("classifyChange (ADR-0010 §6) Δ sınırları", () => {
  // nRecent = nPrevious = 100: Δ = (sumRecent − sumPrevious) / 100.
  const at = (delta, extra = {}) => classifyChange({
    sumRecent: 300 + Math.round(delta * 100), nRecent: 100,
    sumPrevious: 300, nPrevious: 100,
    recentHasLow: false, recentHasHigh: false, ...extra,
  });

  test.each([
    [0, "stable"],
    [0.24, "stable"],
    [0.25, "none"],
    [0.49, "none"],
    [0.5, "higher"],
    [1.2, "higher"],
    [-0.24, "stable"],
    [-0.25, "none"],
    [-0.49, "none"],
    [-0.5, "lower"],
  ])("Δ = %d → %s", (delta, expected) => {
    expect(at(delta)).toBe(expected);
  });

  test("mixed: |Δ| < 0.5 ve son 7 gecede hem ≤2 hem ≥4", () => {
    expect(at(0.1, {recentHasLow: true, recentHasHigh: true})).toBe("mixed");
    expect(at(0.3, {recentHasLow: true, recentHasHigh: true})).toBe("mixed");
    expect(at(0.1, {recentHasLow: true})).toBe("stable");
  });

  test("|Δ| ≥ 0.5 iken yön mixed'den önce gelir", () => {
    expect(at(0.5, {recentHasLow: true, recentHasHigh: true})).toBe("higher");
    expect(at(-0.5, {recentHasLow: true, recentHasHigh: true})).toBe("lower");
  });
});

describe("Haftan: son 7 gecede ≥5 kayıt", () => {
  test("4 kayıt yok, 5 kayıt var", () => {
    expect(energyOf(mornings(recentBlock(4, 3))).week).toBeNull();
    expect(energyOf(mornings(recentBlock(5, 3))).week).toEqual({n: 5, band: "3", min: 3, max: 3});
  });

  test("asOf − 7 penceresi dışında", () => {
    const nights = mornings([[0, 3], [1, 3], [2, 3], [3, 3], [7, 3]]);
    expect(energyOf(nights).week).toBeNull();
    const inside = mornings([[0, 3], [1, 3], [2, 3], [3, 3], [6, 3]]);
    expect(energyOf(inside).week).not.toBeNull();
  });

  test("min, max ve bant", () => {
    const week = energyOf(mornings([[0, 2], [1, 4], [2, 3], [4, 3], [6, 4]])).week;
    expect(week).toEqual({n: 5, band: "3", min: 2, max: 4});
  });
});

describe("Son 14 gecen: geçmiş ≥14 gece (dahil) ve ≥9 kayıt", () => {
  const nineIn14 = [[0, 3], [1, 4], [2, 3], [3, 2], [5, 4], [7, 3], [9, 5], [11, 1], [13, 3]];

  test("ilk kayıt asOf − 13 (14. gece) → açılır", () => {
    const days14 = energyOf(mornings(nineIn14)).days14;
    expect(days14).toEqual({n: 9, band: "3", low: 2, mid: 4, high: 3});
  });

  test("ilk kayıt asOf − 12 (13. gece) → 9 kayıt olsa da açılmaz", () => {
    const shifted = [[0, 3], [1, 4], [2, 3], [3, 2], [4, 4], [6, 3], [8, 5], [10, 1], [12, 3]];
    expect(energyOf(mornings(shifted)).days14).toBeNull();
  });

  test("14 gece geçmiş ama 8 kayıt → açılmaz", () => {
    const eight = nineIn14.filter(([back]) => back !== 5);
    const energy = energyOf(mornings(eight));
    expect(computePersonalState({nights: mornings(eight)}).asOfNight).toBe(AS_OF);
    expect(energy.days14).toBeNull();
  });

  test("önceki durumdaki ilk kayıt geçmişi sağlar", () => {
    const recentOnly = mornings([[0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [7, 3], [8, 3]]);
    expect(energyOf(recentOnly).days14).toBeNull();
    const previous = {firstMorningNight: addDays(AS_OF, -20)};
    expect(energyOf(recentOnly, previous).days14).toEqual({n: 9, band: "3", low: 0, mid: 9, high: 0});
  });

  test("kovalar: düşük 1–2, orta 3, yüksek 4–5", () => {
    const values = [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 3], [6, 3], [8, 5], [13, 1]];
    const days14 = energyOf(mornings(values)).days14;
    expect([days14.low, days14.mid, days14.high]).toEqual([3, 3, 3]);
  });
});

describe("Olağanın: geçmiş ≥28 gece (dahil) ve ≥10 kayıt", () => {
  const tenIn28 = [[0, 3], [2, 3], [5, 3], [8, 3], [11, 3], [14, 3], [17, 3], [20, 3], [24, 3], [27, 3]];

  test("ilk kayıt asOf − 27 (28. gece) → açılır", () => {
    expect(energyOf(mornings(tenIn28)).usual).toEqual({n: 10, band: "3"});
  });

  test("ilk kayıt asOf − 26 (27. gece) → açılmaz", () => {
    const shifted = tenIn28.map(([b, v]) => [Math.min(b, 26), v]);
    shifted[9] = [26, 3];
    shifted[8] = [25, 3];
    expect(energyOf(mornings(shifted)).usual).toBeNull();
  });

  test("28 gece geçmiş ama 9 kayıt → açılmaz", () => {
    expect(energyOf(mornings(tenIn28.slice(1))).usual).toBeNull();
  });

  test("olağan yoksa karşılaştırma asla açılmaz", () => {
    const manyRecent = mornings(Array.from({length: 20}, (_, i) => [i, 3]));
    const energy = energyOf(manyRecent);
    expect(energy.usual).toBeNull();
    expect(energy.change).toBe("insufficient");
  });
});

describe("Olağana göre: son 7 ≥5 ve önceki 21 ≥10", () => {
  const previousBlock = (n, value) => Array.from({length: n}, (_, i) => [7 + i, value]);
  const history = [[27, 3]];

  test("son 7'de 4 kayıt → insufficient", () => {
    const nights = mornings([...recentBlock(4, 5), ...previousBlock(12, 3), ...history]);
    expect(energyOf(nights).change).toBe("insufficient");
  });

  test("önceki 21'de 9 kayıt → insufficient", () => {
    const nights = mornings([...recentBlock(5, 5), ...previousBlock(8, 3), ...history]);
    expect(energyOf(nights).change).toBe("insufficient");
  });

  test("gerçek pencerelerle higher, lower, stable", () => {
    const base = [...previousBlock(12, 3), ...history]; // önceki 21: 13 kayıt, ort. 3
    expect(energyOf(mornings([...recentBlock(5, 4), ...base])).change).toBe("higher");
    expect(energyOf(mornings([...recentBlock(5, 2), ...base])).change).toBe("lower");
    expect(energyOf(mornings([...recentBlock(5, 3), ...base])).change).toBe("stable");
  });

  test("gerçek pencerelerde Δ = 40/140 → none, 20/140 → stable, ±80/140 → higher/lower", () => {
    // nRecent = 7, nPrevious = 20 (önceki 21 gecenin 20'si + asOf−27): Δ adımı 1/140.
    const prev = previousBlock(19, 3).concat([[27, 3]]); // 20 kayıt, toplam 60
    const recentWithSum = (sum) => {
      const values = Array(7).fill(3);
      let extra = sum - 21;
      for (let i = 0; extra !== 0 && i < 7; i++) {
        const step = Math.max(-2, Math.min(2, extra));
        values[i] += step;
        extra -= step;
      }
      return values.map((v, i) => [i, v]);
    };
    // Δ = sR/7 − 3 = (20·sR − 420) / 140.
    const deltaOf = (numerator) => (numerator + 420) / 20;
    const run = (numerator) => {
      const energy = energyOf(mornings([...recentWithSum(deltaOf(numerator)), ...prev]));
      return energy.change;
    };
    expect(run(40)).toBe("none"); // sR = 23: Δ = 40/140 ≈ 0.286
    expect(run(20)).toBe("stable"); // sR = 22: Δ = 20/140 ≈ 0.143
    expect(run(80)).toBe("higher"); // sR = 25: Δ = 80/140 ≈ 0.571
    expect(run(-80)).toBe("lower");
  });

  test("mixed gerçek veriyle: son 7'de 1 ve 5 var, Δ küçük", () => {
    const recent = [[0, 1], [1, 5], [2, 3], [3, 3], [4, 3]];
    const nights = mornings([...recent, ...previousBlock(12, 3), [27, 3]]);
    expect(energyOf(nights).change).toBe("mixed");
  });
});

describe("aşama önceliği ve son değerler", () => {
  test("empty → recent → week → days14 → usual", () => {
    expect(energyOf([]).stage).toBe("empty");
    expect(energyOf(mornings([[0, 3]])).stage).toBe("recent");
    expect(energyOf(mornings(recentBlock(5, 3))).stage).toBe("week");
    const d14 = mornings([...recentBlock(7, 3), [9, 3], [13, 3]]);
    expect(energyOf(d14).stage).toBe("days14");
    const usual = mornings([...recentBlock(7, 3), [9, 3], [13, 3], [27, 3]]);
    expect(energyOf(usual).stage).toBe("usual");
  });

  test("son değerler en fazla 6, kronolojik, 28 gecelik pencereden", () => {
    const nights = mornings([[40, 5], [8, 1], [6, 2], [5, 3], [4, 4], [3, 5], [2, 4], [0, 3]]);
    expect(energyOf(nights).lastValues).toEqual([2, 3, 4, 5, 4, 3]);
    expect(energyOf(mornings([[40, 5], [0, 2]])).lastValues).toEqual([2]);
  });
});

describe("geçerlilik: invalid_time hariç, seyahat dahil", () => {
  test("pencere dışı saatteki taraf sayılmaz", () => {
    const nights = [
      night(AS_OF, {mood: 3, eveningTime: "15:00:00"}),
      night(addDays(AS_OF, -1), {energy: 4, morningTime: "14:30:00"}),
    ];
    const state = computePersonalState({nights});
    expect(state.asOfNight).toBeNull();
    expect(state.mood.stage).toBe("empty");
    expect(state.energy.stage).toBe("empty");
  });

  test("aralık dışı ya da tam sayı olmayan değer kayıt değildir", () => {
    const nights = [
      night(AS_OF, {mood: 0, energy: 6}),
      night(addDays(AS_OF, -1), {mood: 2.5, energy: "3"}),
    ];
    expect(computePersonalState({nights}).asOfNight).toBeNull();
  });

  test("seyahat gecesi (akşam ve sabah UTC farkı ≥120 dk) iki bölümde de sayılır", () => {
    const nights = Array.from({length: 5}, (_, i) =>
      night(addDays(AS_OF, -i), {mood: 4, energy: 2, eveningOffset: 180, morningOffset: -300}));
    const state = computePersonalState({nights});
    expect(state.mood.week).toEqual({n: 5, band: "4", min: 4, max: 4});
    expect(state.energy.week).toEqual({n: 5, band: "2", min: 2, max: 2});
  });
});

describe("eksik geceler ve uzun aralar", () => {
  test("eksik gece düşük değer sayılmaz", () => {
    const nights = mornings([[0, 5], [2, 5], [3, 5], [5, 5], [6, 5], [8, 5], [10, 5], [12, 5], [13, 5]]);
    const energy = energyOf(nights);
    expect(energy.week).toEqual({n: 5, band: "5", min: 5, max: 5});
    expect(energy.days14).toEqual({n: 9, band: "5", low: 0, mid: 0, high: 9});
  });

  test("uzun aradan sonra eski kayıtlar pencerelere girmez, geçmiş korunur", () => {
    const old = mornings(Array.from({length: 20}, (_, i) => [40 + i, 3]));
    const energy = energyOf([...old, ...mornings([[0, 4]])]);
    expect(energy.stage).toBe("recent");
    expect(energy.lastValues).toEqual([4]);
    expect(energy.week).toBeNull();
    expect(energy.usual).toBeNull();
    expect(energy.change).toBe("insufficient");
  });
});

describe("değişkenlerin bağımsızlığı", () => {
  test("yalnız akşam geçmişi: ruh hali hesaplanır, enerji boş", () => {
    const nights = Array.from({length: 5}, (_, i) => night(addDays(AS_OF, -i), {mood: 3}));
    const state = computePersonalState({nights});
    expect(state.mood.stage).toBe("week");
    expect(state.energy.stage).toBe("empty");
    expect(state.firstMorningNight).toBeNull();
  });

  test("yalnız sabah geçmişi: enerji hesaplanır, ruh hali boş", () => {
    const state = computePersonalState({nights: mornings(recentBlock(5, 2))});
    expect(state.energy.stage).toBe("week");
    expect(state.mood.stage).toBe("empty");
    expect(state.firstEveningNight).toBeNull();
  });

  test("özellik: aynı gecelerde sabah değerleri değişince ruh hali bölümü değişmez (ve tersi)", () => {
    const rng = mulberry32(20260917);
    const score = () => 1 + Math.floor(rng() * 5);
    for (let trial = 0; trial < 200; trial++) {
      const nights = [];
      for (let back = 0; back < 40; back++) {
        const v = {};
        if (rng() < 0.8) v.mood = score();
        if (rng() < 0.7) v.energy = score();
        nights.push(night(addDays(AS_OF, -back), v));
      }
      const base = computePersonalState({nights});
      const morningsChanged = nights.map((n) => (n.morning ?
        {...n, morning: {...n.morning, energy: score()}} : n));
      const eveningsChanged = nights.map((n) => (n.evening ?
        {...n, evening: {...n.evening, mood: score()}} : n));
      expect(computePersonalState({nights: morningsChanged}).mood).toEqual(base.mood);
      expect(computePersonalState({nights: eveningsChanged}).energy).toEqual(base.energy);
    }
  });

  test("kaynak: Seviye 2 modülü Pattern ya da V0.1 modüllerini kullanmaz", () => {
    const source = fs.readFileSync(path.join(__dirname, "..", "intel", "personalState.js"), "utf8")
        .replace(/\/\*[\s\S]*?\*\//g, "")
        .replace(/\/\/.*$/gm, "");
    const requires = [...source.matchAll(/require\(\s*["']([^"']+)["']\s*\)/g)].map((m) => m[1]);
    expect(requires.sort()).toEqual(["./nightKey", "./random"]);
    // summarizeVariable tek bir kayıt listesi alır; ruh hali ya da enerji alan adı bilmez.
    const summarize = source.slice(source.indexOf("function summarizeVariable"),
        source.indexOf("function earlierNight"));
    expect(summarize).not.toMatch(/mood|energy|evening|morning/);
  });
});

describe("küçük değişimler yön üretmez", () => {
  test("özellik: stable bir durumda tek bir son kaydı ±1 değiştirmek higher/lower yapmaz", () => {
    const rng = mulberry32(42);
    let checked = 0;
    // Rastgele geçmişlerin yalnız küçük bir kısmı "stable" çıkıyor; yeterli
    // örnek toplamak için deneme sayısı yüksek tutuldu (iddia gevşetilmedi).
    for (let trial = 0; trial < 4000; trial++) {
      const pairs = [];
      for (let back = 0; back < 28; back++) {
        if (back < 7 ? rng() < 0.95 : rng() < 0.8) pairs.push([back, 2 + Math.floor(rng() * 3)]);
      }
      pairs.push([27, 3]);
      const unique = [...new Map(pairs.map((p) => [p[0], p])).values()];
      const before = energyOf(mornings(unique));
      if (before.change !== "stable") continue;
      checked += 1;
      const idx = unique.findIndex(([back]) => back < 7);
      for (const delta of [-1, 1]) {
        const changed = unique.map((p, i) => (i === idx ? [p[0], Math.max(1, Math.min(5, p[1] + delta))] : p));
        expect(["stable", "none", "mixed"]).toContain(energyOf(mornings(changed)).change);
      }
    }
    expect(checked).toBeGreaterThan(20);
  });
});

describe("belirlilik ve girdi doğrulama", () => {
  const nights = Array.from({length: 35}, (_, i) =>
    night(addDays(AS_OF, -i), {mood: (i % 5) + 1, energy: ((i * 2) % 5) + 1}));

  test("aynı girdi, farklı sıra: birebir aynı çıktı ve inputHash", () => {
    const a = computePersonalState({nights});
    const b = computePersonalState({nights: [...nights].reverse()});
    const c = computePersonalState({nights});
    expect(b).toEqual(a);
    expect(c).toEqual(a);
  });

  test("bir değer değişince inputHash değişir", () => {
    const before = computePersonalState({nights}).inputHash;
    const edited = nights.map((n, i) => (i === 3 ? {...n, morning: {...n.morning, energy: n.morning.energy === 5 ? 4 : 5}} : n));
    expect(computePersonalState({nights: edited}).inputHash).not.toBe(before);
  });

  test("aynı nightKey iki kez gelirse hata (Firestore'da doküman kimliği, olamaz)", () => {
    expect(() => computePersonalState({nights: [night(AS_OF, {mood: 3}), night(AS_OF, {energy: 3})]}))
        .toThrow(TypeError);
  });

  test("ilk kayıt: önceki durumla girdinin erken olanı", () => {
    const state = computePersonalState({nights: mornings([[0, 3]]),
      previous: {firstMorningNight: "2026-08-01", firstEveningNight: "bozuk"}});
    expect(state.firstMorningNight).toBe("2026-08-01");
    expect(state.firstEveningNight).toBeNull();
    const earlier = computePersonalState({nights: mornings([[0, 3], [40, 3]]),
      previous: {firstMorningNight: AS_OF}});
    expect(earlier.firstMorningNight).toBe(addDays(AS_OF, -40));
  });

  test("çıktıda ham ortalama ya da standart sapma yok", () => {
    const text = JSON.stringify(computePersonalState({nights}));
    expect(text).not.toMatch(/mean|sd|average|std/i);
  });
});

describe("tazelik (ürün kuralı)", () => {
  test("3 gece fark → taze, 4 gece → bayat", () => {
    expect(isStale("2026-09-27", "2026-09-30")).toBe(false);
    expect(isStale("2026-09-26", "2026-09-30")).toBe(true);
    expect(isStale("2026-09-30", "2026-09-29")).toBe(false);
  });

  test("geçersiz tarih hata (boş kullanıcı istemcide ayrı ele alınır)", () => {
    expect(() => isStale(null, "2026-09-30")).toThrow(TypeError);
  });

  test("nightsBetween ay ve yıl sınırı", () => {
    expect(nightsBetween("2026-03-01", "2026-02-28")).toBe(1);
    expect(nightsBetween("2027-01-01", "2026-12-31")).toBe(1);
  });
});

describe("sabitler ADR-0010 ile aynı", () => {
  test("eşikler", () => {
    expect(THRESHOLDS).toEqual({
      WEEK_NIGHTS: 7, WEEK_MIN_RECORDS: 5,
      DAYS14_NIGHTS: 14, DAYS14_MIN_RECORDS: 9, DAYS14_MIN_HISTORY: 14,
      USUAL_NIGHTS: 28, USUAL_MIN_RECORDS: 10, USUAL_MIN_HISTORY: 28,
      RECENT_NIGHTS: 7, RECENT_MIN_RECORDS: 5, PREVIOUS_FIRST_OFFSET: 27, PREVIOUS_LAST_OFFSET: 7,
      PREVIOUS_MIN_RECORDS: 10, LAST_VALUES_MAX: 6, STALE_AFTER_NIGHTS: 3,
    });
  });

  test("summarizeVariable asOf yoksa boş bölüm döner", () => {
    expect(summarizeVariable([], {asOfNight: null, firstNight: null})).toEqual({
      stage: "empty", lastValues: [], week: null, days14: null, usual: null, change: "insufficient",
    });
  });
});
