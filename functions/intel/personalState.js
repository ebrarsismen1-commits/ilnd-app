/**
 * Seviye 2 Kişisel Durum: saf, deterministik hesap (ADR-0010).
 *
 * Akşam ruh hali ve sabah enerjisi birbirinden BAĞIMSIZ işlenir. Buradaki
 * hiçbir fonksiyon iki değişkeni birlikte kullanmaz, karşılaştırmaz ya da
 * ilişkilendirmez; değişkenler arası analiz yalnız Pattern Engine'e aittir
 * (ADR-0011, henüz yok). İki değişkenin paylaştığı tek şey `asOfNight`
 * takvim referansıdır (ADR-0010 §5).
 *
 * Kullanıcıya metin üretilmez: çıktı yalnız anlamsal kodlar ve sayılardır,
 * dile çeviri istemcidedir. Saat okunmaz, ağa çıkılmaz, LLM çağrılmaz.
 *
 * Eşikler ondalık yerine tam sayı aritmetiğiyle karşılaştırılır: ADR'daki
 * 0.25, 0.5 ve ±0.15 sınırları kayan nokta hatası olmadan birebir uygulanır.
 */

const {isNightKey, addDays, eveningNightKey, morningNightKey} = require("./nightKey");
const {fnv1a32} = require("./random");

const ENGINE_VERSION = "personal-state-v0.1.0";

const WEEK_NIGHTS = 7;
const WEEK_MIN_RECORDS = 5;
const DAYS14_NIGHTS = 14;
const DAYS14_MIN_RECORDS = 9;
const DAYS14_MIN_HISTORY = 14;
const USUAL_NIGHTS = 28;
const USUAL_MIN_RECORDS = 10;
const USUAL_MIN_HISTORY = 28;
const RECENT_NIGHTS = 7;
const RECENT_MIN_RECORDS = 5;
// Önceki 21 gece: asOfNight − 27 … asOfNight − 7.
const PREVIOUS_FIRST_OFFSET = 27;
const PREVIOUS_LAST_OFFSET = 7;
const PREVIOUS_MIN_RECORDS = 10;
const LAST_VALUES_MAX = 6;
// Tazelik bir ÜRÜN kuralıdır, istatistik eşiği değil (ADR-0010 §7).
const STALE_AFTER_NIGHTS = 3;

/**
 * @param {unknown} value aday puan
 * @return {boolean} 1..5 tam sayı mı
 */
function isScore(value) {
  return Number.isInteger(value) && value >= 1 && value <= 5;
}

/**
 * İki gece anahtarı arasındaki takvim gecesi farkı (a − b).
 * @param {string} a YYYY-MM-DD
 * @param {string} b YYYY-MM-DD
 * @return {number} gün farkı
 */
function nightsBetween(a, b) {
  const [ay, am, ad] = a.split("-").map(Number);
  const [by, bm, bd] = b.split("-").map(Number);
  return Math.round((Date.UTC(ay, am - 1, ad) - Date.UTC(by, bm - 1, bd)) / 86400000);
}

/**
 * Bir tarafın geçerli kayıtları. Diğer tarafa hiç bakılmaz.
 *
 * Geçerli kayıt: gece anahtarı gerçek bir tarih, değer 1..5 tam sayı ve
 * kayıt zamanı o gecenin penceresine düşüyor (`invalid_time` değil).
 * Seyahat gecesi Seviye 2'ye dahildir; seyahat bayrağı burada hesaplanmaz.
 * @param {Array<object>} nights ham geceler
 * @param {string} side "evening" | "morning"
 * @param {string} field "mood" | "energy"
 * @param {function(unknown, unknown): (string|null)} deriveKey saat kuralı
 * @return {Array<{nightKey: string, value: number}>} nightKey'e göre artan
 */
function extractRecords(nights, side, field, deriveKey) {
  const records = [];
  for (const night of nights) {
    if (!night || !isNightKey(night.nightKey)) continue;
    const entry = night[side];
    if (!entry || typeof entry !== "object" || !isScore(entry[field])) continue;
    if (deriveKey(entry.createdAtMs, entry.tzOffsetMin) !== night.nightKey) continue;
    records.push({nightKey: night.nightKey, value: entry[field]});
  }
  return records.sort((x, y) => (x.nightKey < y.nightKey ? -1 : x.nightKey > y.nightKey ? 1 : 0));
}

/**
 * @param {Array<object>} nights ham geceler
 * @return {Array<{nightKey: string, value: number}>} geçerli akşam ruh halleri
 */
function eveningRecords(nights) {
  return extractRecords(nights, "evening", "mood", eveningNightKey);
}

/**
 * @param {Array<object>} nights ham geceler
 * @return {Array<{nightKey: string, value: number}>} geçerli sabah enerjileri
 */
function morningRecords(nights) {
  return extractRecords(nights, "morning", "energy", morningNightKey);
}

/**
 * Bant (ADR-0010 §4). Ortalama m = sum / n.
 * |m − (k + 0.5)| ≤ 0.15 ⇔ |20·sum − (20k + 10)·n| ≤ 3n  → "k_k+1"
 * aksi halde round(m) = floor((2·sum + n) / (2n)); x.5 bu dala hiç düşmez.
 * @param {number} sum değerlerin toplamı
 * @param {number} n kayıt sayısı (>0)
 * @return {string} "1".."5" ya da "k_k+1"
 */
function bandOf(sum, n) {
  for (let k = 1; k <= 4; k++) {
    if (Math.abs(20 * sum - (20 * k + 10) * n) <= 3 * n) return `${k}_${k + 1}`;
  }
  return String(Math.floor((2 * sum + n) / (2 * n)));
}

/**
 * Olağana göre durum (ADR-0010 §6), yalnız sayım koşulları sağlandıktan sonra.
 * Δ = sumRecent/nRecent − sumPrevious/nPrevious; D = Δ·nRecent·nPrevious.
 * @param {{sumRecent: number, nRecent: number, sumPrevious: number,
 *   nPrevious: number, recentHasLow: boolean, recentHasHigh: boolean}} input
 * @return {string} "higher" | "lower" | "mixed" | "stable" | "none"
 */
function classifyChange({sumRecent, nRecent, sumPrevious, nPrevious, recentHasLow, recentHasHigh}) {
  const scaled = sumRecent * nPrevious - sumPrevious * nRecent;
  const denominator = nRecent * nPrevious;
  if (2 * scaled >= denominator) return "higher";
  if (2 * scaled <= -denominator) return "lower";
  if (recentHasLow && recentHasHigh) return "mixed";
  if (4 * Math.abs(scaled) < denominator) return "stable";
  return "none";
}

/**
 * @param {Array<{nightKey: string, value: number}>} records artan kayıtlar
 * @param {string} from dahil
 * @param {string} to dahil
 * @return {number[]} penceredeki değerler (artan)
 */
function valuesBetween(records, from, to) {
  return records.filter((r) => r.nightKey >= from && r.nightKey <= to).map((r) => r.value);
}

/**
 * @param {number[]} values değerler
 * @return {number} toplam
 */
function sumOf(values) {
  let total = 0;
  for (const value of values) total += value;
  return total;
}

/**
 * TEK bir değişkenin Seviye 2 özeti.
 * @param {Array<{nightKey: string, value: number}>} records o değişkenin
 *   geçerli kayıtları (artan)
 * @param {{asOfNight: (string|null), firstNight: (string|null)}} context
 *   ortak takvim referansı ve o değişkenin ilk geçerli kaydı
 * @return {object} bölüm
 */
function summarizeVariable(records, {asOfNight, firstNight}) {
  if (!asOfNight) {
    return {stage: "empty", lastValues: [], week: null, days14: null, usual: null,
      change: "insufficient"};
  }

  const last28 = valuesBetween(records, addDays(asOfNight, -(USUAL_NIGHTS - 1)), asOfNight);
  const lastValues = last28.slice(-LAST_VALUES_MAX);
  const historyNights = firstNight ? nightsBetween(asOfNight, firstNight) + 1 : 0;

  const weekValues = valuesBetween(records, addDays(asOfNight, -(WEEK_NIGHTS - 1)), asOfNight);
  const week = weekValues.length >= WEEK_MIN_RECORDS ? {
    n: weekValues.length,
    band: bandOf(sumOf(weekValues), weekValues.length),
    min: Math.min(...weekValues),
    max: Math.max(...weekValues),
  } : null;

  const days14Values = valuesBetween(records, addDays(asOfNight, -(DAYS14_NIGHTS - 1)), asOfNight);
  const days14 = historyNights >= DAYS14_MIN_HISTORY && days14Values.length >= DAYS14_MIN_RECORDS ? {
    n: days14Values.length,
    band: bandOf(sumOf(days14Values), days14Values.length),
    low: days14Values.filter((v) => v <= 2).length,
    mid: days14Values.filter((v) => v === 3).length,
    high: days14Values.filter((v) => v >= 4).length,
  } : null;

  const usual = historyNights >= USUAL_MIN_HISTORY && last28.length >= USUAL_MIN_RECORDS ? {
    n: last28.length,
    band: bandOf(sumOf(last28), last28.length),
  } : null;

  let change = "insufficient";
  if (usual) {
    const recent = valuesBetween(records, addDays(asOfNight, -(RECENT_NIGHTS - 1)), asOfNight);
    const previous = valuesBetween(records, addDays(asOfNight, -PREVIOUS_FIRST_OFFSET),
        addDays(asOfNight, -PREVIOUS_LAST_OFFSET));
    if (recent.length >= RECENT_MIN_RECORDS && previous.length >= PREVIOUS_MIN_RECORDS) {
      change = classifyChange({
        sumRecent: sumOf(recent),
        nRecent: recent.length,
        sumPrevious: sumOf(previous),
        nPrevious: previous.length,
        recentHasLow: recent.some((v) => v <= 2),
        recentHasHigh: recent.some((v) => v >= 4),
      });
    }
  }

  let stage = "empty";
  if (usual) stage = "usual";
  else if (days14) stage = "days14";
  else if (week) stage = "week";
  else if (lastValues.length > 0) stage = "recent";

  return {stage, lastValues, week, days14, usual, change};
}

/**
 * @param {string|null|undefined} a gece
 * @param {string|null|undefined} b gece
 * @return {string|null} erken olan
 */
function earlierNight(a, b) {
  const valid = [a, b].filter((x) => isNightKey(x));
  if (valid.length === 0) return null;
  return valid.sort()[0];
}

/**
 * `users/{uid}/intel/state` dokümanının Seviye 2 içeriği.
 *
 * Firestore'da nightKey doküman kimliğidir; aynı anahtar iki kez gelemez.
 * Gelirse bu çağıran hatasıdır ve sessizce birini seçmek yerine hata atılır.
 * @param {{nights: Array<object>, previous?: (object|null)}} input ham geceler
 *   (pencere dışındakiler yok sayılır) ve önceki durum
 * @return {object} kişisel durum
 */
function computePersonalState({nights, previous = null}) {
  const list = Array.isArray(nights) ? nights : [];
  const seen = new Set();
  for (const night of list) {
    if (!night || typeof night.nightKey !== "string") continue;
    if (seen.has(night.nightKey)) {
      throw new TypeError(`computePersonalState: nightKey tekrar ediyor (${night.nightKey})`);
    }
    seen.add(night.nightKey);
  }

  const evenings = eveningRecords(list);
  const mornings = morningRecords(list);

  const lastEvening = evenings.length ? evenings[evenings.length - 1].nightKey : null;
  const lastMorning = mornings.length ? mornings[mornings.length - 1].nightKey : null;
  // Yalnız takvim referansı: iki listenin değerleri değil, en son tarihi.
  const asOfNight = [lastEvening, lastMorning].filter(Boolean).sort().pop() || null;

  const prior = previous && typeof previous === "object" ? previous : {};
  const firstEveningNight = earlierNight(prior.firstEveningNight,
      evenings.length ? evenings[0].nightKey : null);
  const firstMorningNight = earlierNight(prior.firstMorningNight,
      mornings.length ? mornings[0].nightKey : null);

  const mood = summarizeVariable(evenings, {asOfNight, firstNight: firstEveningNight});
  const energy = summarizeVariable(mornings, {asOfNight, firstNight: firstMorningNight});

  const windowFrom = asOfNight ? addDays(asOfNight, -(USUAL_NIGHTS - 1)) : null;
  const inWindow = (records) => (asOfNight ?
    records.filter((r) => r.nightKey >= windowFrom && r.nightKey <= asOfNight)
        .map((r) => [r.nightKey, r.value]) :
    []);
  const inputHash = fnv1a32(JSON.stringify([
    ENGINE_VERSION, asOfNight, firstEveningNight, firstMorningNight,
    inWindow(evenings), inWindow(mornings),
  ])).toString(16).padStart(8, "0");

  return {
    engineVersion: ENGINE_VERSION,
    asOfNight,
    inputHash,
    mood,
    energy,
    firstEveningNight,
    firstMorningNight,
  };
}

/**
 * İstemcinin uygulayacağı tazelik kuralının başvuru uygulaması (ADR-0010 §7).
 * Seviye 2 yorumu, cihazın yerel bugünü ile asOfNight arasında 3'ten fazla
 * takvim gecesi varsa gizlenir. Kaydı hiç olmayan kullanıcı (asOfNight yok)
 * "boş" durumdur, "bayat" değildir; o ayrımı istemci yapar.
 * @param {string} asOfNight geçerli gece
 * @param {string} localToday cihazın yerel tarihi (YYYY-MM-DD)
 * @return {boolean} bayat mı
 */
function isStale(asOfNight, localToday) {
  if (!isNightKey(asOfNight) || !isNightKey(localToday)) {
    throw new TypeError("isStale: asOfNight ve localToday geçerli YYYY-MM-DD olmalı");
  }
  return nightsBetween(localToday, asOfNight) > STALE_AFTER_NIGHTS;
}

module.exports = {
  ENGINE_VERSION,
  THRESHOLDS: Object.freeze({
    WEEK_NIGHTS, WEEK_MIN_RECORDS,
    DAYS14_NIGHTS, DAYS14_MIN_RECORDS, DAYS14_MIN_HISTORY,
    USUAL_NIGHTS, USUAL_MIN_RECORDS, USUAL_MIN_HISTORY,
    RECENT_NIGHTS, RECENT_MIN_RECORDS, PREVIOUS_FIRST_OFFSET, PREVIOUS_LAST_OFFSET,
    PREVIOUS_MIN_RECORDS, LAST_VALUES_MAX, STALE_AFTER_NIGHTS,
  }),
  nightsBetween,
  eveningRecords,
  morningRecords,
  bandOf,
  classifyChange,
  summarizeVariable,
  computePersonalState,
  isStale,
};
