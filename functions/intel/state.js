/**
 * Intelligence Layer V0 durumunu tek bir saf çağrıyla hesaplar (ADR-0009 §8).
 *
 * Girdi: bir kullanıcının ham geceleri ve (varsa) bir önceki durumu. Çıktı:
 * `users/{uid}/intel/state` dokümanının içeriği. Saat okumaz, ağa çıkmaz,
 * LLM çağırmaz; aynı girdi her zaman aynı çıktıyı verir. Firestore'a yazma
 * ve rıza kontrolü bu dosyanın işi değil (sonraki commit'ler).
 */

const {addDays} = require("./nightKey");
const {deriveNights, computeBaseline} = require("./nights");
const {fnv1a32} = require("./random");
const {
  PATTERN_TYPE,
  P5_WINDOW_DAYS,
  DEFAULT_PERMUTATIONS,
  pairsInWindow,
  evaluateP5,
  shownStateFor,
} = require("./p5");

const ENGINE_VERSION = "intel-v0.1.0";

/**
 * @param {number|null} value sayı
 * @param {number} digits ondalık hane
 * @return {number|null} yuvarlanmış değer
 */
function round(value, digits) {
  if (value === null || value === undefined) return null;
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

/**
 * @param {number|null} d fark
 * @return {string|null} yön
 */
function directionOf(d) {
  if (d === null) return null;
  if (d < 0) return "lower";
  if (d > 0) return "higher";
  return "none";
}

/**
 * @param {{uid: string, nights: Array<object>, previous?: (object|null),
 *   permutations?: number}} input hesap girdisi
 * @return {object} intel state
 */
function computeIntelState({uid, nights, previous = null, permutations = DEFAULT_PERMUTATIONS}) {
  if (typeof uid !== "string" || uid.length === 0) {
    throw new TypeError("computeIntelState: uid gerekli (permütasyon tohumu)");
  }
  if (!Number.isInteger(permutations) || permutations < 1) {
    throw new TypeError("computeIntelState: permutations pozitif tam sayı olmalı");
  }

  const derived = deriveNights(nights);
  const asOfNight = derived.length > 0 ? derived[derived.length - 1].nightKey : null;
  const baseline = computeBaseline(derived, asOfNight);
  const pairs = asOfNight ? pairsInWindow(derived, asOfNight) : [];

  const now = evaluateP5(pairs, {uid, permutations});
  const prev = evaluateP5(pairs.slice(0, -1), {uid, permutations});

  const previousP5 = previous && previous.p5 ? previous.p5 : {};
  const everShown = Boolean(previousP5.firstShownStrongNight);
  const shownState = shownStateFor(now, prev.status, everShown);

  let firstShownStrongNight = previousP5.firstShownStrongNight || null;
  let lastShownStrongNight = previousP5.lastShownStrongNight || null;
  if (shownState === "strong") {
    lastShownStrongNight = asOfNight;
    if (!firstShownStrongNight) firstShownStrongNight = asOfNight;
  }

  const windowFrom = asOfNight ? addDays(asOfNight, -(P5_WINDOW_DAYS - 1)) : null;
  const hashedNights = asOfNight ?
    derived
        .filter((night) => night.nightKey >= windowFrom)
        .map((night) => [night.nightKey, night.mood, night.energy, night.tzShift]) :
    [];
  const inputHash = fnv1a32(JSON.stringify(
      [ENGINE_VERSION, asOfNight, everShown, permutations, hashedNights],
  )).toString(16).padStart(8, "0");

  const halfStableForDirection = now.d !== null && now.d > 0 ?
    now.halfStablePositive :
    now.halfStableNegative;

  return {
    engineVersion: ENGINE_VERSION,
    asOfNight,
    inputHash,
    baseline: {
      windowDays: baseline.windowDays,
      energyMean: round(baseline.energyMean, 1),
      energyN: baseline.energyN,
    },
    progress: {pairs: now.n, lowNights: now.nLow, otherNights: now.nOther},
    p5: {
      patternType: PATTERN_TYPE,
      shownState,
      status: now.status,
      statusPrev: prev.status,
      pairs: now.n,
      lowNights: now.nLow,
      otherNights: now.nOther,
      window: {from: windowFrom, to: asOfNight, days: P5_WINDOW_DAYS},
      direction: directionOf(now.d),
      effect: round(now.d, 1),
      meanLow: round(now.meanLow, 1),
      meanOther: round(now.meanOther, 1),
      evidence: {
        permutationP: round(now.p, 4),
        permutations,
        halfStable: halfStableForDirection,
      },
      firstShownStrongNight,
      lastShownStrongNight,
    },
  };
}

module.exports = {ENGINE_VERSION, computeIntelState};
