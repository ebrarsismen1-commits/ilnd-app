const {
  THRESHOLDS,
  classifyStatus,
  evaluateP5,
  halfStable,
  permutationP,
  shownStateFor,
  pairsInWindow,
} = require("../intel/p5");
const {computeIntelState} = require("../intel/state");
const {deriveNights} = require("../intel/nights");
const {addDays} = require("../intel/nightKey");
const {fnv1a32, mulberry32} = require("../intel/random");

/**
 * P5 matematiği (ADR-0009 §5–§7). Eşik sınırları doğrudan classifyStatus
 * üzerinden, permütasyon ve uçtan uca davranış gerçek veriyle test edilir.
 */

const OFFSET = 180;
const localMs = (iso) => Date.parse(`${iso}Z`) - OFFSET * 60000;

/**
 * @param {Array<[number, number]>} values [mood, energy] çiftleri
 * @param {string} [start] ilk gece
 * @return {Array<{nightKey: string, mood: number, energy: number}>} artan
 */
function pairs(values, start = "2026-07-01") {
  return values.map(([mood, energy], i) => ({nightKey: addDays(start, i), mood, energy}));
}

/**
 * @param {Array<[number, number]>} values [mood, energy]
 * @param {string} [start] ilk gece
 * @return {Array<object>} ham geceler
 */
function rawNights(values, start = "2026-07-01") {
  return values.map(([mood, energy], i) => {
    const key = addDays(start, i);
    return {
      nightKey: key,
      evening: {mood, tzOffsetMin: OFFSET, createdAtMs: localMs(`${key}T21:00:00`)},
      morning: {energy, tzOffsetMin: OFFSET, createdAtMs: localMs(`${addDays(key, 1)}T08:00:00`)},
    };
  });
}

const base = {
  n: 25, nLow: 8, nOther: 17, sd: 1, d: -1, p: 0.01,
  halfStableNegative: true, halfStablePositive: false,
};

describe("random", () => {
  test("FNV-1a bilinen değerler", () => {
    expect(fnv1a32("")).toBe(0x811c9dc5);
    expect(fnv1a32("a")).toBe(0xe40c292c);
  });

  test("mulberry32 aynı tohumla aynı diziyi üretir ve [0,1) içinde kalır", () => {
    const a = mulberry32(42);
    const b = mulberry32(42);
    for (let i = 0; i < 1000; i++) {
      const x = a();
      expect(x).toBe(b());
      expect(x).toBeGreaterThanOrEqual(0);
      expect(x).toBeLessThan(1);
    }
  });
});

describe("gruplama ve etki", () => {
  test("mood 2 LOW, 3 OTHER", () => {
    const r = evaluateP5(pairs([[2, 1], [3, 5]]), {uid: "u"});
    expect(r.nLow).toBe(1);
    expect(r.nOther).toBe(1);
    expect(r.d).toBe(-4);
  });

  test("elle hesaplanan örnek: LOW 2.25, OTHER 52/15", () => {
    const low = [2, 3, 2, 2, 3, 1, 2, 3].map((e) => [1, e]);
    const other = [3, 4, 3, 4, 3, 3, 4, 5, 3, 2, 4, 3, 4, 3, 4].map((e) => [4, e]);
    const r = evaluateP5(pairs([...low, ...other]), {uid: "u"});
    expect(r.meanLow).toBeCloseTo(2.25, 12);
    expect(r.meanOther).toBeCloseTo(52 / 15, 12);
    expect(r.d).toBeCloseTo(2.25 - 52 / 15, 12);
  });

  test("p yalnız d ≤ −0.5 ya da d ≥ +0.75 iken hesaplanır", () => {
    const flat = pairs(Array.from({length: 20}, (_, i) => [i % 2 ? 1 : 4, (i % 3) + 2]));
    const r = evaluateP5(flat, {uid: "u"});
    expect(Math.abs(r.d)).toBeLessThan(0.5);
    expect(r.p).toBeNull();
  });
});

describe("permutationP", () => {
  test("aynı tohum aynı p, p hiçbir zaman 1/(B+1)'in altında değil", () => {
    const energies = [1, 1, 1, 1, 1, 5, 5, 5, 5, 5];
    const p1 = permutationP(energies, 5, -4, 7, 2000);
    const p2 = permutationP(energies, 5, -4, 7, 2000);
    expect(p1).toBe(p2);
    expect(p1).toBeGreaterThanOrEqual(1 / 2001);
  });

  test("tam ayrışmada p kesin değere yakın: 2/252", () => {
    const p = permutationP([1, 1, 1, 1, 1, 5, 5, 5, 5, 5], 5, -4, 123, 2000);
    expect(p).toBeGreaterThan(0.002);
    expect(p).toBeLessThan(0.02);
  });

  test("hiç fark yoksa p = 1", () => {
    expect(permutationP([3, 3, 3, 3, 3, 3], 3, 0, 1, 500)).toBe(1);
  });
});

describe("halfStable", () => {
  test("iki yarı da negatifse true, biri pozitifse false", () => {
    const half = [[1, 2], [1, 2], [1, 2], [4, 4], [4, 4], [4, 4]];
    expect(halfStable(pairs([...half, ...half]), -1)).toBe(true);
    const flipped = [[1, 5], [1, 5], [1, 5], [4, 2], [4, 2], [4, 2]];
    expect(halfStable(pairs([...half, ...flipped]), -1)).toBe(false);
  });

  test("bir yarıda grup başına 3'ten az gece varsa false", () => {
    const half = [[1, 2], [1, 2], [4, 4], [4, 4], [4, 4], [4, 4]];
    expect(halfStable(pairs([...half, ...half]), -1)).toBe(false);
  });
});

describe("classifyStatus sınırları", () => {
  test.each([
    ["N 9", {n: 9}, "insufficient"],
    ["nLow 3", {nLow: 3}, "insufficient"],
    ["nOther 3", {nOther: 3}, "insufficient"],
    ["sd 0.49", {sd: 0.49}, "insufficient"],
    ["temel strong", {}, "strong"],
    ["N 20 strong olamaz", {n: 20}, "emerging"],
    ["nLow 6 strong olamaz", {nLow: 6}, "emerging"],
    ["d −0.74 strong olamaz", {d: -0.74}, "emerging"],
    ["d −0.75 strong", {d: -0.75}, "strong"],
    ["p 0.05 strong olamaz", {p: 0.05}, "emerging"],
    ["p 0.049 strong", {p: 0.049}, "strong"],
    ["halfStable false strong olamaz", {halfStableNegative: false}, "emerging"],
    ["emerging p 0.10 olamaz", {n: 15, p: 0.1}, "candidate"],
    ["emerging N 13 olamaz", {n: 13, p: 0.09}, "candidate"],
    ["candidate p 0.20 olamaz", {n: 15, p: 0.2}, "inconclusive"],
    ["p null → candidate olamaz", {n: 15, p: null}, "inconclusive"],
    ["d −0.49 dolu veri", {d: -0.49, p: null}, "not_observed"],
    ["d −0.5 ve p 0.3 dolu veri", {d: -0.5, p: 0.3}, "inconclusive"],
    ["ters yön", {d: 0.9, p: 0.01, halfStableNegative: false, halfStablePositive: true}, "opposite"],
    ["ters yön kararsız", {d: 0.9, p: 0.01, halfStableNegative: false}, "not_observed"],
  ])("%s", (_, override, expected) => {
    expect(classifyStatus({...base, ...override})).toBe(expected);
  });

  test("eşikler ADR ile aynı", () => {
    expect(THRESHOLDS.strong).toEqual({pairs: 21, each: 7, d: -0.75, p: 0.05});
    expect(THRESHOLDS.emerging).toEqual({pairs: 14, each: 5, d: -0.5, p: 0.1});
    expect(THRESHOLDS.candidate).toEqual({d: -0.5, p: 0.2});
    expect(THRESHOLDS.minPairs).toBe(10);
  });
});

describe("shownStateFor", () => {
  const s = (status, n = 25, nLow = 8) => ({status, n, nLow});

  test.each([
    [s("strong"), "strong", false, "strong"],
    [s("strong"), "emerging", false, "forming"],
    [s("strong"), "emerging", true, "strong"],
    [s("emerging"), "strong", true, "weakened"],
    [s("inconclusive"), "strong", true, "weakened"],
    [s("not_observed"), "strong", true, "faded"],
    [s("insufficient"), "insufficient", true, "faded"],
    [s("not_observed"), "not_observed", false, "not_observed"],
    [s("not_observed"), "inconclusive", false, "forming"],
    [s("inconclusive", 30, 5), "inconclusive", false, "few_low"],
    [s("candidate", 15, 5), "candidate", false, "forming"],
  ])("%o prev=%s everShown=%s → %s", (now, prev, ever, expected) => {
    expect(shownStateFor(now, prev, ever)).toBe(expected);
  });
});

describe("pencere", () => {
  test("asOf − 59 dahil, asOf − 60 hariç", () => {
    const asOf = "2026-09-14";
    const derived = deriveNights(rawNights([[3, 3]], addDays(asOf, -60))
        .concat(rawNights([[3, 3]], addDays(asOf, -59)))
        .concat(rawNights([[3, 3]], asOf)));
    expect(pairsInWindow(derived, asOf).map((p) => p.nightKey)).toEqual([addDays(asOf, -59), asOf]);
  });
});

describe("uçtan uca", () => {
  const strongData = Array.from({length: 30}, (_, i) => (i % 3 === 0 ? [1, 1 + (i % 2)] : [4, 4 + (i % 2)]));

  test("belirgin etki iki ardışık hesapta strong gösterilir", () => {
    const state = computeIntelState({uid: "e2e", nights: rawNights(strongData)});
    expect(state.p5.status).toBe("strong");
    expect(state.p5.statusPrev).toBe("strong");
    expect(state.p5.shownState).toBe("strong");
    expect(state.p5.firstShownStrongNight).toBe(state.asOfNight);
    expect(state.p5.direction).toBe("lower");
    expect(state.p5.evidence.permutationP).toBeLessThan(0.05);
  });

  test("gösterilmiş örüntü çelişen veride zayıflar ya da kaybolur", () => {
    const first = computeIntelState({uid: "e2e", nights: rawNights(strongData)});
    const contradiction = Array.from({length: 40}, (_, i) => (i % 3 === 0 ? [1, 5] : [4, 2 + (i % 2)]));
    const nights = rawNights(strongData).concat(rawNights(contradiction, addDays("2026-07-01", 30)));
    const later = computeIntelState({uid: "e2e", nights, previous: first});
    expect(["weakened", "faded"]).toContain(later.p5.shownState);
    expect(later.p5.firstShownStrongNight).toBe(first.p5.firstShownStrongNight);
  });

  test("her gece aynı enerji: değişkenlik yok, örüntü yok", () => {
    const flat = Array.from({length: 30}, (_, i) => [i % 3 === 0 ? 1 : 4, 3]);
    const state = computeIntelState({uid: "flat", nights: rawNights(flat)});
    expect(state.p5.status).toBe("insufficient");
    expect(state.p5.shownState).toBe("forming");
  });

  test("zor akşam hiç yoksa strong olamaz", () => {
    const none = Array.from({length: 30}, (_, i) => [4, 1 + (i % 5)]);
    const state = computeIntelState({uid: "none", nights: rawNights(none)});
    expect(state.p5.lowNights).toBe(0);
    expect(state.p5.shownState).toBe("few_low");
  });
});
