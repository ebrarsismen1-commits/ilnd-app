/**
 * Hassas uçların kabul ettiği Firebase oturumu.
 *
 * Güvenlik denetimi H-5 (2026-09-13): uçlar HERHANGİ bir Firebase ID token'ını
 * kabul ediyordu; konsolda Anonymous ya da E-posta sağlayıcısı açık olsaydı
 * herkes public web API key ile hesap açıp AI kotası, davet ödülü alabilirdi.
 * O gün çözüm "yalnız Supabase köprüsünün custom token'ı" idi.
 *
 * ADR-0010 (2026-09-18): kimlik doğrudan Firebase Auth'ta, köprü kalktı. Kural
 * artık sağlayıcıya göre:
 *   - password: e-posta DOĞRULANMIŞ olmalı (istemci de aynı kuralı uygular;
 *     doğrulanmamış hesap toplu hesap açmanın ucuz yolu).
 *   - google.com / apple.com: sağlayıcı e-postayı zaten doğrulamış sayılır.
 *   - anonymous, custom (eski köprü dahil), phone ve diğerleri: reddedilir.
 */

const ALLOWED_PROVIDERS = new Set(["password", "google.com", "apple.com"]);

/**
 * @param {object} decoded verifyIdToken çıktısı
 * @return {{ok: true}|{ok: false, reason: string}} karar
 */
function checkSession(decoded) {
  const provider = decoded && decoded.firebase && decoded.firebase.sign_in_provider;
  if (!provider) return {ok: false, reason: "no-provider"};
  if (!ALLOWED_PROVIDERS.has(provider)) return {ok: false, reason: `provider-${provider}`};
  if (provider === "password" && decoded.email_verified !== true) {
    return {ok: false, reason: "email-not-verified"};
  }
  return {ok: true};
}

/**
 * @param {object} decoded verifyIdToken çıktısı
 * @return {boolean} uçlara girebilir mi
 */
function isAllowedSession(decoded) {
  return checkSession(decoded).ok;
}

module.exports = {ALLOWED_PROVIDERS, checkSession, isAllowedSession};
