/**
 * Kimlik köprüsünün iddia (claim) kontrolleri.
 *
 * Güvenlik denetimi H-5 / L-6 (2026-09-13):
 *   - mintFirebaseToken yalnız imza + issuer'a bakıyordu; aud/role/anonim
 *     oturum kontrolü yoktu.
 *   - Diğer uçlar HERHANGİ bir Firebase ID token'ını kabul ediyordu. Konsolda
 *     Firebase'in kendi Anonymous ya da E-posta sağlayıcısı açık olsaydı
 *     (bugün ya da yanlışlıkla ileride), herkes public web API key ile
 *     Supabase'i hiç görmeden hesap açıp AI kotası, davet ödülü ve Firestore
 *     erişimi alabilirdi. Artık yalnız köprünün ürettiği oturum geçer.
 */

// Firebase Auth uid üst sınırı.
const MAX_UID_LENGTH = 128;

/**
 * Supabase erişim JWT'sinin yükü köprüden geçmeye uygun mu?
 * @param {object} payload doğrulanmış JWT yükü
 * @return {{ok: true, uid: string}|{ok: false, reason: string}} karar
 */
function validateSupabaseClaims(payload) {
  if (!payload || typeof payload !== "object") {
    return {ok: false, reason: "no-payload"};
  }
  const sub = payload.sub;
  if (typeof sub !== "string" || sub.length === 0 || sub.length > MAX_UID_LENGTH) {
    return {ok: false, reason: "bad-subject"};
  }
  const aud = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
  if (!aud.includes("authenticated")) {
    return {ok: false, reason: "bad-audience"};
  }
  if (payload.role !== "authenticated") {
    return {ok: false, reason: "bad-role"};
  }
  if (payload.is_anonymous === true) {
    return {ok: false, reason: "anonymous"};
  }
  return {ok: true, uid: sub};
}

/**
 * Firebase ID token'ı mintFirebaseToken'ın ürettiği custom token'dan mı geliyor?
 * @param {object} decoded verifyIdToken çıktısı
 * @return {boolean} köprü oturumuysa true
 */
function isBridgedSession(decoded) {
  return Boolean(
      decoded &&
      decoded.firebase &&
      decoded.firebase.sign_in_provider === "custom" &&
      decoded.provider === "supabase",
  );
}

module.exports = {MAX_UID_LENGTH, validateSupabaseClaims, isBridgedSession};
