/**
 * AI acil durum anahtarı ve günlük harcama tavanı ayarı.
 *
 * `config/ai` dokümanı yalnız konsoldan / Admin SDK'dan yazılır; istemciye
 * kural yok (varsayılan deny). Alanlar:
 *   enabled: false      → proxy 503 döner, Anthropic'e hiç gidilmez
 *   dailyUsdLimit: 5    → kullanıcı başı günlük tahmini dolar tavanı
 *
 * Her istekte okumamak için örnek başına 60 sn önbelleklenir: anahtar en geç
 * bir dakikada tüm örneklerde devreye girer.
 */

const CACHE_MS = 60 * 1000;

let cached = null;
let cachedAt = 0;

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {number} [now] epoch ms (test için)
 * @return {Promise<{enabled?: boolean, dailyUsdLimit?: number}>} ayar
 */
async function getAiConfig(db, now = Date.now()) {
  if (cached && now - cachedAt < CACHE_MS) return cached;
  try {
    const snap = await db.collection("config").doc("ai").get();
    cached = snap.exists ? (snap.data() || {}) : {};
  } catch (err) {
    // Okunamazsa son bilinen değer; hiç yoksa varsayılanlar. Anahtarın
    // okunamaması tüm AI'ı kapatmamalı, günlük tavanlar zaten devrede.
    console.warn("getAiConfig failed:", err.message || err);
    cached = cached || {};
  }
  cachedAt = now;
  return cached;
}

/** Testlerde önbelleği boşaltır. */
function resetAiConfigCache() {
  cached = null;
  cachedAt = 0;
}

module.exports = {getAiConfig, resetAiConfigCache, CACHE_MS};
