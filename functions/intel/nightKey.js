/**
 * Gece anahtarı ve yerel saat pencereleri (ADR-0009 §2).
 *
 * Bir "gece" akşamın yerel tarihidir: pazartesi 23:30'daki akşam kaydı ile
 * salı 08:00'deki sabah kaydı aynı gecedir. Saf: saat, ağ ya da Firebase
 * okumaz. Aynı kurallar ileride Flutter'da da uygulanacak; iki uygulama
 * `functions/test/fixtures/night_key_vectors.json` ile kilitlenir.
 */

const EVENING_START_HOUR = 17;
// Akşam penceresi gece yarısından sonra bu saate kadar sürer (hariç).
const EVENING_END_HOUR = 4;
const MORNING_START_HOUR = 4;
const MORNING_END_HOUR = 14;
const MIN_TZ_OFFSET_MIN = -720;
const MAX_TZ_OFFSET_MIN = 840;

const NIGHT_KEY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

/**
 * Takvimde gerçekten var olan bir YYYY-MM-DD mi? 2026-02-30 reddedilir.
 * @param {unknown} value aday
 * @return {boolean} geçerli mi
 */
function isNightKey(value) {
  if (typeof value !== "string" || !NIGHT_KEY_PATTERN.test(value)) return false;
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day;
}

/**
 * @param {string} nightKey geçerli YYYY-MM-DD
 * @param {number} days eklenecek gün (negatif olabilir)
 * @return {string} YYYY-MM-DD
 */
function addDays(nightKey, days) {
  const [year, month, day] = nightKey.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, day + days)).toISOString().slice(0, 10);
}

/**
 * @param {unknown} value dakika cinsinden UTC farkı
 * @return {boolean} kabul edilen aralıkta tam sayı mı
 */
function isValidTzOffset(value) {
  return Number.isInteger(value) && value >= MIN_TZ_OFFSET_MIN && value <= MAX_TZ_OFFSET_MIN;
}

/**
 * Kaydın yerel tarihi ve saati. Sunucu zamanı + cihazın UTC farkı.
 * @param {unknown} createdAtMs epoch ms
 * @param {unknown} tzOffsetMin dakika
 * @return {{date: string, hour: number}|null} geçersiz girdide null
 */
function localDateAndHour(createdAtMs, tzOffsetMin) {
  if (typeof createdAtMs !== "number" || !Number.isFinite(createdAtMs)) return null;
  if (!isValidTzOffset(tzOffsetMin)) return null;
  const local = new Date(createdAtMs + tzOffsetMin * 60000);
  if (!Number.isFinite(local.getTime())) return null;
  return {date: local.toISOString().slice(0, 10), hour: local.getUTCHours()};
}

/**
 * Akşam kaydının ait olduğu gece; pencere dışındaysa null.
 * @param {unknown} createdAtMs epoch ms
 * @param {unknown} tzOffsetMin dakika
 * @return {string|null} nightKey
 */
function eveningNightKey(createdAtMs, tzOffsetMin) {
  const local = localDateAndHour(createdAtMs, tzOffsetMin);
  if (!local) return null;
  if (local.hour >= EVENING_START_HOUR) return local.date;
  if (local.hour < EVENING_END_HOUR) return addDays(local.date, -1);
  return null;
}

/**
 * Sabah kaydının ait olduğu gece (bir önceki akşam); pencere dışındaysa null.
 * @param {unknown} createdAtMs epoch ms
 * @param {unknown} tzOffsetMin dakika
 * @return {string|null} nightKey
 */
function morningNightKey(createdAtMs, tzOffsetMin) {
  const local = localDateAndHour(createdAtMs, tzOffsetMin);
  if (!local) return null;
  if (local.hour >= MORNING_START_HOUR && local.hour < MORNING_END_HOUR) {
    return addDays(local.date, -1);
  }
  return null;
}

module.exports = {
  EVENING_START_HOUR,
  EVENING_END_HOUR,
  MORNING_START_HOUR,
  MORNING_END_HOUR,
  MIN_TZ_OFFSET_MIN,
  MAX_TZ_OFFSET_MIN,
  isNightKey,
  addDays,
  isValidTzOffset,
  localDateAndHour,
  eveningNightKey,
  morningNightKey,
};
