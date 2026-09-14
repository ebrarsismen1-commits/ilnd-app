/**
 * HTTP fonksiyonları için App Check doğrulaması.
 *
 * Güvenlik denetimi H-5 (2026-09-13): kodda ve belgelerde "enforceAppCheck:
 * true" geçiyordu ama o seçenek YALNIZ onCall (callable) fonksiyonlarda
 * çalışır. ILND'nin tüm uçları onRequest; yani App Check hiçbir zaman
 * uygulanmamıştı. Token burada elle doğrulanır.
 *
 * App Check YETKİLENDİRME DEĞİLDİR: yalnız isteğin gerçek uygulamadan geldiğini
 * gösterir. Kimlik (Firebase ID token), sahiplik ve kota her uçta ayrıca
 * kontrol edilir; App Check kapalı olsa bile başka kullanıcının verisine
 * erişilemez.
 *
 * Mod `APP_CHECK_MODE` ortam değişkeninden, her istekte okunur:
 *   off      doğrulama yok
 *   monitor  (varsayılan) doğrular, eksik/geçersiz tokenı loglar, reddetmez
 *   enforce  eksik/geçersiz token → 401
 * Tanınmayan değer (yazım hatası) enforce sayılır: yanlış yazılmış bir ayar
 * korumayı sessizce kapatmamalı.
 */

const MODES = ["off", "monitor", "enforce"];

/**
 * @param {object} [env] ortam
 * @return {"off"|"monitor"|"enforce"} mod
 */
function appCheckMode(env = process.env) {
  const raw = env.APP_CHECK_MODE;
  if (raw === undefined || raw === null || String(raw).trim() === "") {
    return "monitor";
  }
  const mode = String(raw).trim().toLowerCase();
  return MODES.includes(mode) ? mode : "enforce";
}

/**
 * Başlığı büyük/küçük harf duyarsız okur.
 * @param {{headers?: object}} req istek
 * @return {string|null} token
 */
function appCheckToken(req) {
  const headers = (req && req.headers) || {};
  for (const [key, value] of Object.entries(headers)) {
    if (key.toLowerCase() === "x-firebase-appcheck") {
      return typeof value === "string" && value.length > 0 ? value : null;
    }
  }
  return null;
}

/**
 * @param {{headers?: object}} req istek
 * @param {{mode: string, verify: function(string): Promise<unknown>,
 *   fn?: string, log?: {warn: function(string): void}}} opts ayarlar
 * @return {Promise<{ok: boolean, status: string}>} karar; status
 *   verified | missing | invalid | skipped
 */
async function checkAppCheck(req, {mode, verify, fn = "unknown", log = console}) {
  if (mode === "off") return {ok: true, status: "skipped"};

  const token = appCheckToken(req);
  let status;
  if (!token) {
    status = "missing";
  } else {
    try {
      await verify(token);
      status = "verified";
    } catch (err) {
      status = "invalid";
    }
  }

  if (status !== "verified") {
    // Yapılandırılmış log: Cloud Logging'de log tabanlı metrik kurulup
    // enforce'a geçmeden önce doğrulanmış istek oranı izlenir.
    log.warn(JSON.stringify({event: "app_check", fn, status, mode}));
  }
  return {ok: status === "verified" || mode === "monitor", status};
}

module.exports = {MODES, appCheckMode, appCheckToken, checkAppCheck};
