/**
 * P5: zor akşam ruh hali → ertesi sabah enerjisi (ADR-0009 §5–§7).
 *
 * Kişi içi, geçmişe dönük bir eşleşme testi; nedensellik ya da tahmin değil.
 * Buradaki sabitler ADR-0009'da simülasyon sonucu görülmeden donduruldu.
 * Değişirse ENGINE_VERSION artar ve simülasyon kapısı yeniden koşulur.
 */

const {addDays} = require("./nightKey");
const {fnv1a32, mulberry32} = require("./random");

const PATTERN_TYPE = "low_evening_mood_morning_energy";
const P5_WINDOW_DAYS = 60;
const LOW_MOOD_MAX = 2;
const DEFAULT_PERMUTATIONS = 2000;
const EPS = 1e-9;

const THRESHOLDS = Object.freeze({
  minPairs: 10,
  minEach: 4,
  minSd: 0.5,
  pTrigger: Object.freeze({negative: -0.5, positive: 0.75}),
  strong: Object.freeze({pairs: 21, each: 7, d: -0.75, p: 0.05}),
  opposite: Object.freeze({d: 0.75, p: 0.05}),
  emerging: Object.freeze({pairs: 14, each: 5, d: -0.5, p: 0.1}),
  candidate: Object.freeze({d: -0.5, p: 0.2}),
  notObserved: Object.freeze({d: -0.5}),
  halfMinEach: 3,
});

/**
 * P5 penceresindeki eşleşmiş geceler: kaymasız, iki tarafı geçerli.
 * @param {Array<object>} derived deriveNights çıktısı (artan sıralı)
 * @param {string} asOfNight en son geçerli gece
 * @return {Array<{nightKey: string, mood: number, energy: number}>} artan
 */
function pairsInWindow(derived, asOfNight) {
  const from = addDays(asOfNight, -(P5_WINDOW_DAYS - 1));
  return derived
      .filter((night) => !night.tzShift && night.mood !== null && night.energy !== null &&
        night.nightKey >= from && night.nightKey <= asOfNight)
      .map((night) => ({nightKey: night.nightKey, mood: night.mood, energy: night.energy}));
}

/**
 * LOW ile OTHER ortalamalarının farkı; iki gruptan biri boşsa null.
 * @param {Array<{mood: number, energy: number}>} pairs geceler
 * @param {number} minEach her grupta gereken en az gece
 * @return {number|null} fark
 */
function groupDifference(pairs, minEach) {
  let nLow = 0;
  let sumLow = 0;
  let sumOther = 0;
  for (const pair of pairs) {
    if (pair.mood <= LOW_MOOD_MAX) {
      nLow += 1;
      sumLow += pair.energy;
    } else {
      sumOther += pair.energy;
    }
  }
  const nOther = pairs.length - nLow;
  if (nLow < minEach || nOther < minEach) return null;
  return sumLow / nLow - sumOther / nOther;
}

/**
 * İki yarının farkı da aynı yönde mi? Geceler zamana göre ikiye bölünür.
 * @param {Array<{mood: number, energy: number}>} pairs nightKey'e göre artan
 * @param {number} sign -1 negatif yön, +1 pozitif yön
 * @return {boolean} kararlı mı
 */
function halfStable(pairs, sign) {
  const half = Math.floor(pairs.length / 2);
  const first = groupDifference(pairs.slice(0, half), THRESHOLDS.halfMinEach);
  const second = groupDifference(pairs.slice(half), THRESHOLDS.halfMinEach);
  if (first === null || second === null) return false;
  return sign < 0 ? first < 0 && second < 0 : first > 0 && second > 0;
}

/**
 * İki yönlü permütasyon testi. Her permütasyonda bir index dizisinin ilk
 * nLow konumu kısmi Fisher–Yates ile seçilir; dizi permütasyonlar arasında
 * sıfırlanmaz (her başlangıç düzeninden sonuç yine düzgün dağılır).
 * @param {number[]} energies eşleşmiş gecelerin enerjileri
 * @param {number} nLow LOW grubu büyüklüğü
 * @param {number} observed gözlenen fark
 * @param {number} seed PRNG tohumu
 * @param {number} permutations permütasyon sayısı
 * @return {number} p = (1 + uç sayısı) / (B + 1)
 */
function permutationP(energies, nLow, observed, seed, permutations) {
  const n = energies.length;
  const nOther = n - nLow;
  const rng = mulberry32(seed);
  const index = new Int32Array(n);
  let total = 0;
  for (let i = 0; i < n; i++) {
    index[i] = i;
    total += energies[i];
  }
  const threshold = Math.abs(observed) - EPS;
  let extreme = 0;
  for (let b = 0; b < permutations; b++) {
    let sumLow = 0;
    for (let i = 0; i < nLow; i++) {
      const j = i + Math.floor(rng() * (n - i));
      const swap = index[i];
      index[i] = index[j];
      index[j] = swap;
      sumLow += energies[index[i]];
    }
    const difference = sumLow / nLow - (total - sumLow) / nOther;
    if (Math.abs(difference) >= threshold) extreme += 1;
  }
  return (1 + extreme) / (permutations + 1);
}

/**
 * Metriklerden iç durumu seçer (ADR-0009 §6 tablosu, yukarıdan aşağı).
 * @param {{n: number, nLow: number, nOther: number, sd: number,
 *   d: (number|null), p: (number|null), halfStableNegative: boolean,
 *   halfStablePositive: boolean}} m metrikler
 * @return {string} durum
 */
function classifyStatus(m) {
  if (m.n < THRESHOLDS.minPairs || m.nLow < THRESHOLDS.minEach ||
      m.nOther < THRESHOLDS.minEach || m.sd < THRESHOLDS.minSd - EPS) {
    return "insufficient";
  }
  const hasP = typeof m.p === "number";
  const full = m.n >= THRESHOLDS.strong.pairs &&
    m.nLow >= THRESHOLDS.strong.each && m.nOther >= THRESHOLDS.strong.each;

  if (full && hasP && m.d <= THRESHOLDS.strong.d + EPS &&
      m.p < THRESHOLDS.strong.p && m.halfStableNegative) {
    return "strong";
  }
  if (full && hasP && m.d >= THRESHOLDS.opposite.d - EPS &&
      m.p < THRESHOLDS.opposite.p && m.halfStablePositive) {
    return "opposite";
  }
  if (m.n >= THRESHOLDS.emerging.pairs && m.nLow >= THRESHOLDS.emerging.each &&
      m.nOther >= THRESHOLDS.emerging.each && hasP &&
      m.d <= THRESHOLDS.emerging.d + EPS && m.p < THRESHOLDS.emerging.p) {
    return "emerging";
  }
  if (hasP && m.d <= THRESHOLDS.candidate.d + EPS && m.p < THRESHOLDS.candidate.p) {
    return "candidate";
  }
  if (full && m.d > THRESHOLDS.notObserved.d + EPS) {
    return "not_observed";
  }
  return "inconclusive";
}

/**
 * Bir eşleşmiş gece setini değerlendirir.
 * @param {Array<{nightKey: string, mood: number, energy: number}>} pairs
 *   nightKey'e göre artan
 * @param {{uid: string, permutations?: number}} options tohum ve B
 * @return {object} metrikler ve durum
 */
function evaluateP5(pairs, {uid, permutations = DEFAULT_PERMUTATIONS}) {
  const n = pairs.length;
  const energies = new Array(n);
  let nLow = 0;
  let sumLow = 0;
  let sumAll = 0;
  for (let i = 0; i < n; i++) {
    energies[i] = pairs[i].energy;
    sumAll += pairs[i].energy;
    if (pairs[i].mood <= LOW_MOOD_MAX) {
      nLow += 1;
      sumLow += pairs[i].energy;
    }
  }
  const nOther = n - nLow;

  let sd = 0;
  if (n >= 2) {
    const mean = sumAll / n;
    let squares = 0;
    for (const energy of energies) squares += (energy - mean) * (energy - mean);
    sd = Math.sqrt(squares / (n - 1));
  }

  const meanLow = nLow > 0 ? sumLow / nLow : null;
  const meanOther = nOther > 0 ? (sumAll - sumLow) / nOther : null;
  const d = meanLow !== null && meanOther !== null ? meanLow - meanOther : null;

  let p = null;
  if (d !== null && (d <= THRESHOLDS.pTrigger.negative + EPS ||
      d >= THRESHOLDS.pTrigger.positive - EPS)) {
    const seed = fnv1a32(`${uid}|p5|${pairs[n - 1].nightKey}|${n}`);
    p = permutationP(energies, nLow, d, seed, permutations);
  }

  const metrics = {
    n,
    nLow,
    nOther,
    sd,
    d,
    meanLow,
    meanOther,
    p,
    permutations,
    halfStableNegative: halfStable(pairs, -1),
    halfStablePositive: halfStable(pairs, 1),
  };
  return {...metrics, status: classifyStatus(metrics)};
}

/**
 * Kullanıcıya gösterilecek durum (ADR-0009 §7).
 * @param {{status: string, n: number, nLow: number}} now S(N)
 * @param {string} prevStatus S(N−1) durumu
 * @param {boolean} everShown daha önce strong gösterildi mi
 * @return {string} shownState
 */
function shownStateFor(now, prevStatus, everShown) {
  if (now.status === "strong" && (prevStatus === "strong" || everShown)) return "strong";
  if (everShown && ["emerging", "candidate", "inconclusive"].includes(now.status)) {
    return "weakened";
  }
  if (everShown) return "faded";
  if (now.status === "not_observed" && prevStatus === "not_observed") return "not_observed";
  if (now.n >= THRESHOLDS.strong.pairs && now.nLow < THRESHOLDS.strong.each) return "few_low";
  return "forming";
}

module.exports = {
  PATTERN_TYPE,
  P5_WINDOW_DAYS,
  LOW_MOOD_MAX,
  DEFAULT_PERMUTATIONS,
  EPS,
  THRESHOLDS,
  pairsInWindow,
  groupDifference,
  halfStable,
  permutationP,
  classifyStatus,
  evaluateP5,
  shownStateFor,
};
