/**
 * Intelligence Layer için deterministik rastgelelik (ADR-0009 §5).
 *
 * Math.random bilerek kullanılmaz: aynı veri her hesapta aynı p değerini
 * vermeli, yoksa bir kullanıcının örüntüsü sayfa yenilendikçe gelip gider ve
 * testler tekrar üretilemez.
 */

/**
 * FNV-1a 32 bit özet, UTF-8 baytları üzerinden.
 * @param {string} text girdi
 * @return {number} işaretsiz 32 bit tam sayı
 */
function fnv1a32(text) {
  const bytes = Buffer.from(String(text), "utf8");
  let hash = 0x811c9dc5;
  for (const byte of bytes) {
    hash ^= byte;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}

/**
 * mulberry32 PRNG.
 * @param {number} seed 32 bit tohum
 * @return {function(): number} [0, 1) aralığında sayı üreten fonksiyon
 */
function mulberry32(seed) {
  let state = seed >>> 0;
  return function next() {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

module.exports = {fnv1a32, mulberry32};
