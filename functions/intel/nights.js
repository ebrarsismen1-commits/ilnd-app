/**
 * Gece kayıtlarının kalite türetmesi ve kişisel baseline (ADR-0009 §2–§4).
 *
 * Kalite bayrakları dokümana yazılmaz, her hesapta buradan yeniden türetilir:
 * istemcinin sahip olduğu doküman temiz kalır, bir düzenleme bayrakları da
 * kendiliğinden düzeltir.
 */

const {isNightKey, addDays, eveningNightKey, morningNightKey} = require("./nightKey");

// Aynı gecenin iki tarafı ya da ardışık iki gece arasında bu kadar dakikalık
// UTC farkı değişimi seyahat sayılır. Yaz saati (60 dk) sayılmaz.
const TZ_SHIFT_MIN = 120;
const BASELINE_WINDOW_DAYS = 28;
const BASELINE_MIN_MORNINGS = 7;

/**
 * @param {unknown} value aday puan
 * @return {boolean} 1..5 tam sayı mı
 */
function isScore(value) {
  return Number.isInteger(value) && value >= 1 && value <= 5;
}

/**
 * Bir tarafı doğrular. Geçersiz değer ya da pencere dışı saat: null.
 * @param {unknown} side evening ya da morning nesnesi
 * @param {string} field "mood" | "energy"
 * @param {string} nightKey dokümanın anahtarı
 * @param {function(unknown, unknown): (string|null)} deriveKey pencere kuralı
 * @return {{value: number, tzOffsetMin: number}|null} geçerli taraf
 */
function validSide(side, field, nightKey, deriveKey) {
  if (!side || typeof side !== "object") return null;
  if (!isScore(side[field])) return null;
  if (deriveKey(side.createdAtMs, side.tzOffsetMin) !== nightKey) return null;
  return {value: side[field], tzOffsetMin: side.tzOffsetMin};
}

/**
 * Geceleri sıralar, geçersiz tarafları atar ve seyahat bayrağını türetir.
 *
 * Aynı nightKey birden fazla gelirse (Firestore'da olamaz, çağıran hatası)
 * hiçbiri kullanılmaz: hangisinin doğru olduğu girdi sırasına bağlı kalırdı.
 * @param {Array<object>} nights ham geceler
 * @return {Array<{nightKey: string, mood: (number|null),
 *   energy: (number|null), tzShift: boolean}>} en az bir geçerli tarafı olan
 *   geceler, nightKey'e göre artan
 */
function deriveNights(nights) {
  const list = Array.isArray(nights) ? nights : [];
  const counts = new Map();
  for (const night of list) {
    if (night && isNightKey(night.nightKey)) {
      counts.set(night.nightKey, (counts.get(night.nightKey) || 0) + 1);
    }
  }
  const unique = list
      .filter((night) => night && isNightKey(night.nightKey) && counts.get(night.nightKey) === 1)
      .sort((a, b) => (a.nightKey < b.nightKey ? -1 : a.nightKey > b.nightKey ? 1 : 0));

  const derived = [];
  let referenceOffset = null;
  for (const night of unique) {
    const evening = validSide(night.evening, "mood", night.nightKey, eveningNightKey);
    const morning = validSide(night.morning, "energy", night.nightKey, morningNightKey);
    if (!evening && !morning) continue;

    const firstOffset = evening ? evening.tzOffsetMin : morning.tzOffsetMin;
    let tzShift = false;
    if (evening && morning &&
        Math.abs(evening.tzOffsetMin - morning.tzOffsetMin) >= TZ_SHIFT_MIN) {
      tzShift = true;
    }
    if (referenceOffset !== null && Math.abs(firstOffset - referenceOffset) >= TZ_SHIFT_MIN) {
      tzShift = true;
    }
    // Seyahatten sonraki gece yeni saat dilimine göre karşılaştırılır: yalnız
    // geçişin olduğu gece hesaptan çıkar.
    referenceOffset = firstOffset;

    derived.push({
      nightKey: night.nightKey,
      mood: evening ? evening.value : null,
      energy: morning ? morning.value : null,
      tzShift,
    });
  }
  return derived;
}

/**
 * Sabah enerjisinin son 28 gecelik ortalaması. Akşam tarafı gerekmez.
 * @param {Array<object>} derived deriveNights çıktısı
 * @param {string|null} asOfNight en son geçerli gece
 * @return {{windowDays: number, energyMean: (number|null), energyN: number}}
 *   yuvarlanmamış baseline
 */
function computeBaseline(derived, asOfNight) {
  if (!asOfNight) return {windowDays: BASELINE_WINDOW_DAYS, energyMean: null, energyN: 0};
  const from = addDays(asOfNight, -(BASELINE_WINDOW_DAYS - 1));
  let sum = 0;
  let count = 0;
  for (const night of derived) {
    if (night.tzShift || night.energy === null) continue;
    if (night.nightKey < from || night.nightKey > asOfNight) continue;
    sum += night.energy;
    count += 1;
  }
  return {
    windowDays: BASELINE_WINDOW_DAYS,
    energyMean: count >= BASELINE_MIN_MORNINGS ? sum / count : null,
    energyN: count,
  };
}

module.exports = {
  TZ_SHIFT_MIN,
  BASELINE_WINDOW_DAYS,
  BASELINE_MIN_MORNINGS,
  isScore,
  deriveNights,
  computeBaseline,
};
