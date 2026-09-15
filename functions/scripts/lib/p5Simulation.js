/**
 * P5 simülasyon paketi (ADR-0009 "Preregistered simulation").
 *
 * İstatistik burada YENİDEN yazılmaz: her sentetik kullanıcının geceleri
 * üretimdeki `computeIntelState`'e aynen verilir. Bu dosyanın tek işi veri
 * üretmek, sonuçları saymak ve önceden kayda geçirilmiş ölçütlere karşı
 * değerlendirmek. Ölçütler ADR'da donduruldu; buradaki sabitler onun kopyası
 * ve `intelP5Simulation.test.js` ikisinin aynı kaldığını kilitler.
 */

const {computeIntelState, ENGINE_VERSION} = require("../../intel/state");
const {fnv1a32, mulberry32} = require("../../intel/random");
const {addDays} = require("../../intel/nightKey");

const START_NIGHT = "2026-01-05";
const SIM_NIGHTS = 90;
const OFFSET_MIN = 180;
const COMPLETE_P = 0.75;
const WEEKEND_COMPLETE_P = 0.5;

const MOOD_MARGINALS = Object.freeze({
  tipik: [0.08, 0.17, 0.35, 0.28, 0.12],
  nadiren: [0.02, 0.05, 0.33, 0.40, 0.20],
  sik: [0.15, 0.25, 0.30, 0.20, 0.10],
});
const ENERGY_MARGINAL = [0.08, 0.20, 0.37, 0.25, 0.10];

const CRITERIA = Object.freeze({
  G1: {maxRate: 0.05, maxWilsonUpper: 0.065},
  G2: {maxRate: 0.08},
  S1: {minRate: 0.60},
  S3: {minRate: 0.50},
});

/**
 * @param {string} mood marjinal adı
 * @param {number} rho AR(1) katsayısı
 * @param {object} [extra] ek alanlar
 * @return {object} senaryo
 */
function nullScenario(mood, rho, extra = {}) {
  const suffix = extra.weekend ? "-weekend" : "";
  return {id: `N-${mood}-r${rho}${suffix}`, kind: "null", mood, rho, beta: 0,
    weekend: false, switchNight: null, ...extra};
}

const SCENARIOS = Object.freeze([
  nullScenario("tipik", 0),
  nullScenario("tipik", 0.3),
  nullScenario("tipik", 0.6),
  nullScenario("nadiren", 0),
  nullScenario("nadiren", 0.3),
  nullScenario("nadiren", 0.6),
  nullScenario("sik", 0),
  nullScenario("sik", 0.3),
  nullScenario("sik", 0.6),
  nullScenario("tipik", 0, {weekend: true}),
  {id: "P-tipik-r0-b1.0", kind: "power", mood: "tipik", rho: 0, beta: -1,
    weekend: false, switchNight: null},
  {id: "P-tipik-r0-b0.5", kind: "power", mood: "tipik", rho: 0, beta: -0.5,
    weekend: false, switchNight: null},
  {id: "W-tipik-r0-b1.0-s30", kind: "weaken", mood: "tipik", rho: 0, beta: -1,
    weekend: false, switchNight: 30},
]);

/**
 * Standart normalin ters CDF'i (Acklam yaklaşımı, göreli hata ~1e-9).
 * @param {number} p (0, 1)
 * @return {number} z
 */
function probit(p) {
  const a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
    1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00];
  const b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
    6.680131188771972e+01, -1.328068155288572e+01];
  const c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
    -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00];
  const d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
    3.754408661907416e+00];
  const low = 0.02425;
  if (p < low) {
    const q = Math.sqrt(-2 * Math.log(p));
    return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
      ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }
  if (p <= 1 - low) {
    const q = p - 0.5;
    const r = q * q;
    return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
      (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
  }
  const q = Math.sqrt(-2 * Math.log(1 - p));
  return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
    ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
}

/**
 * @param {number[]} marginal 5 olasılık
 * @return {number[]} 4 kesim noktası
 */
function cutoffs(marginal) {
  const cuts = [];
  let cumulative = 0;
  for (let k = 0; k < 4; k++) {
    cumulative += marginal[k];
    cuts.push(probit(cumulative));
  }
  return cuts;
}

/**
 * @param {number} z gizli değer
 * @param {number[]} cuts kesim noktaları
 * @return {number} 1..5
 */
function category(z, cuts) {
  let value = 1;
  for (const cut of cuts) if (z > cut) value += 1;
  return value;
}

/**
 * Box–Muller; iki uniform tüketir.
 * @param {function(): number} rng [0,1)
 * @return {number} N(0,1)
 */
function normal(rng) {
  const u1 = rng();
  const u2 = rng();
  return Math.sqrt(-2 * Math.log(1 - u1)) * Math.cos(2 * Math.PI * u2);
}

/**
 * Bir kullanıcının 90 gecesini üretir. Tüketim sırası ADR'da sabit.
 * @param {object} scenario senaryo
 * @param {number} userIndex kullanıcı numarası
 * @return {Array<{night: number, doc: object, mood: number, energy: number}>}
 *   tamamlanmış geceler
 */
function generateUserNights(scenario, userIndex) {
  const rng = mulberry32(fnv1a32(`sim|${scenario.id}|${userIndex}`));
  const moodCuts = cutoffs(MOOD_MARGINALS[scenario.mood]);
  const energyCuts = cutoffs(ENERGY_MARGINAL);
  const innovation = Math.sqrt(1 - scenario.rho * scenario.rho);
  let zMood = 0;
  let zEnergy = 0;
  const nights = [];

  for (let night = 0; night < SIM_NIGHTS; night++) {
    const eMood = normal(rng);
    const eEnergy = normal(rng);
    zMood = night === 0 ? eMood : scenario.rho * zMood + innovation * eMood;
    zEnergy = night === 0 ? eEnergy : scenario.rho * zEnergy + innovation * eEnergy;
    const uComplete = rng();
    const uEffect = rng();

    const nightKey = addDays(START_NIGHT, night);
    const weekday = new Date(`${nightKey}T00:00:00Z`).getUTCDay();
    const isWeekend = weekday === 0 || weekday === 6;
    const pComplete = scenario.weekend && isWeekend ? WEEKEND_COMPLETE_P : COMPLETE_P;
    if (uComplete >= pComplete) continue;

    const mood = category(zMood, moodCuts);
    let energy = category(zEnergy, energyCuts);
    const effectActive = scenario.beta !== 0 &&
      (scenario.switchNight === null || night < scenario.switchNight);
    if (mood <= 2 && effectActive) {
      if (scenario.beta <= -1) energy -= 1;
      else if (uEffect < 0.5) energy -= 1;
      energy = Math.max(1, energy);
    }

    const eveningLocal = Date.parse(`${nightKey}T21:00:00Z`);
    const morningLocal = Date.parse(`${addDays(nightKey, 1)}T08:00:00Z`);
    nights.push({
      night,
      mood,
      energy,
      doc: {
        nightKey,
        evening: {mood, tzOffsetMin: OFFSET_MIN, createdAtMs: eveningLocal - OFFSET_MIN * 60000},
        morning: {energy, tzOffsetMin: OFFSET_MIN, createdAtMs: morningLocal - OFFSET_MIN * 60000},
      },
    });
  }
  return nights;
}

/**
 * Bir kullanıcıyı üretimdeki gibi gece gece değerlendirir.
 * @param {object} scenario senaryo
 * @param {number} userIndex numara
 * @param {{permutations: number}} options B
 * @return {object} kullanıcı özeti
 */
function simulateUser(scenario, userIndex, {permutations}) {
  const uid = `sim-${scenario.id}-${userIndex}`;
  const docs = [];
  let previous = null;
  let firstStrongNight = null;
  let everStrong60 = false;
  let weakenedAfterStrong = false;
  let everEmergingStatus = false;
  let everCandidateStatus = false;
  let everNotObservedShown = false;

  for (const item of generateUserNights(scenario, userIndex)) {
    docs.push(item.doc);
    const state = computeIntelState({uid, nights: docs, previous, permutations});
    previous = state;
    const shown = state.p5.shownState;
    if (shown === "strong") {
      if (firstStrongNight === null) firstStrongNight = item.night;
      if (item.night < 60) everStrong60 = true;
    }
    if (firstStrongNight !== null && (shown === "weakened" || shown === "faded")) {
      weakenedAfterStrong = true;
    }
    if (state.p5.status === "emerging") everEmergingStatus = true;
    if (state.p5.status === "candidate") everCandidateStatus = true;
    if (shown === "not_observed") everNotObservedShown = true;
  }

  return {
    pairs: docs.length,
    firstStrongNight,
    everStrong90: firstStrongNight !== null,
    everStrong60,
    weakenedAfterStrong,
    everEmergingStatus,
    everCandidateStatus,
    everNotObservedShown,
    finalShown: previous ? previous.p5.shownState : "forming",
  };
}

/**
 * Wilson %95 aralığı.
 * @param {number} k başarı
 * @param {number} n deneme
 * @return {{lower: number, upper: number}} aralık
 */
function wilson(k, n) {
  if (n === 0) return {lower: 0, upper: 1};
  const z = 1.959963984540054;
  const p = k / n;
  const denominator = 1 + z * z / n;
  const center = (p + z * z / (2 * n)) / denominator;
  const half = z * Math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denominator;
  return {lower: Math.max(0, center - half), upper: Math.min(1, center + half)};
}

/**
 * @param {number} count sayı
 * @param {number} total toplam
 * @return {{count: number, total: number, rate: number,
 *   wilsonLower: number, wilsonUpper: number}} oran
 */
function proportion(count, total) {
  const interval = wilson(count, total);
  return {
    count,
    total,
    rate: total === 0 ? 0 : count / total,
    wilsonLower: interval.lower,
    wilsonUpper: interval.upper,
  };
}

/**
 * Bir senaryoyu çalıştırır.
 * @param {object} scenario senaryo
 * @param {{users: number, permutations: number}} options boyut
 * @return {object} toplu sonuç
 */
function runScenario(scenario, {users, permutations}) {
  const summaries = [];
  for (let i = 0; i < users; i++) summaries.push(simulateUser(scenario, i, {permutations}));
  const count = (field) => summaries.filter((s) => s[field]).length;
  const strongUsers = summaries.filter((s) => s.everStrong90);
  const totalPairs = summaries.reduce((sum, s) => sum + s.pairs, 0);
  return {
    id: scenario.id,
    kind: scenario.kind,
    users,
    permutations,
    meanPairs: totalPairs / users,
    everStrong90: proportion(count("everStrong90"), users),
    everStrong60: proportion(count("everStrong60"), users),
    everEmergingStatus: proportion(count("everEmergingStatus"), users),
    everCandidateStatus: proportion(count("everCandidateStatus"), users),
    everNotObservedShown: proportion(count("everNotObservedShown"), users),
    weakenedAfterStrong: proportion(strongUsers.filter((s) => s.weakenedAfterStrong).length,
        strongUsers.length),
    summaryHash: fnv1a32(JSON.stringify(summaries)).toString(16).padStart(8, "0"),
  };
}

/**
 * Sonuçları önceden kayda geçirilmiş ölçütlere göre değerlendirir.
 * @param {object[]} results runScenario çıktıları (tüm senaryolar)
 * @param {{pass: boolean, detail: string}} determinism G3 sonucu
 * @return {{criteria: object[], gate: string}} karar
 */
function evaluateGate(results, determinism) {
  const byId = new Map(results.map((r) => [r.id, r]));
  const scenario = (id) => SCENARIOS.find((s) => s.id === id);
  const criteria = [];

  const g1 = results.filter((r) => r.kind === "null" && [0, 0.3].includes(scenario(r.id).rho));
  criteria.push({
    code: "G1",
    type: "primary",
    scenarios: g1.map((r) => r.id),
    pass: g1.length === 10 - 3 &&
      g1.every((r) => r.everStrong90.rate <= CRITERIA.G1.maxRate &&
        r.everStrong90.wilsonUpper <= CRITERIA.G1.maxWilsonUpper),
  });

  const g2 = results.filter((r) => r.kind === "null" && scenario(r.id).rho === 0.6);
  criteria.push({
    code: "G2",
    type: "primary-conditional",
    scenarios: g2.map((r) => r.id),
    pass: g2.length === 3 && g2.every((r) => r.everStrong90.rate <= CRITERIA.G2.maxRate),
  });

  criteria.push({code: "G3", type: "primary", pass: determinism.pass, detail: determinism.detail});

  const s1 = byId.get("P-tipik-r0-b1.0");
  criteria.push({
    code: "S1",
    type: "secondary",
    scenarios: ["P-tipik-r0-b1.0"],
    pass: Boolean(s1) && s1.everStrong60.rate >= CRITERIA.S1.minRate,
  });

  const s2 = byId.get("P-tipik-r0-b0.5");
  criteria.push({code: "S2", type: "report", scenarios: ["P-tipik-r0-b0.5"],
    pass: null, value: s2 ? s2.everStrong60.rate : null});

  const s3 = byId.get("W-tipik-r0-b1.0-s30");
  criteria.push({
    code: "S3",
    type: "secondary",
    scenarios: ["W-tipik-r0-b1.0-s30"],
    pass: Boolean(s3) && s3.weakenedAfterStrong.total > 0 &&
      s3.weakenedAfterStrong.rate >= CRITERIA.S3.minRate,
  });

  const passed = (code) => criteria.find((c) => c.code === code).pass;
  let gate = "PASS";
  if (!passed("G1") || !passed("G3")) gate = "FAIL";
  else if (!passed("G2") || !passed("S1") || !passed("S3")) gate = "NEEDS OWNER DECISION";
  return {criteria, gate};
}

module.exports = {
  ENGINE_VERSION,
  START_NIGHT,
  SIM_NIGHTS,
  MOOD_MARGINALS,
  ENERGY_MARGINAL,
  CRITERIA,
  SCENARIOS,
  probit,
  cutoffs,
  category,
  generateUserNights,
  simulateUser,
  wilson,
  runScenario,
  evaluateGate,
};
