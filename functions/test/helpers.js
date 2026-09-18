const admin = require("firebase-admin");

/**
 * Emülatörde verilen uid için gerçek bir e-posta/şifre oturumu açar ve ID
 * token'ını döner. Üretimde her oturum Firebase Auth'tan doğrudan gelir
 * (ADR-0010); uçlar yalnız doğrulanmış e-postayı ya da Google/Apple'ı kabul
 * eder. Kullanıcı yoksa yaratılır, varsa e-posta/şifre eklenir (mevcut
 * `disabled` durumuna dokunulmaz).
 * @param {string} uid Firebase uid
 * @param {{emailVerified?: boolean}} [opts] seçenekler
 * @return {Promise<string>} doğrulanabilir ID token
 */
async function getIdTokenForUid(uid, {emailVerified = true} = {}) {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  if (!host) {
    throw new Error(
        "FIREBASE_AUTH_EMULATOR_HOST is not set — these tests must run " +
        "via `firebase emulators:exec` (see functions/package.json's " +
        "`test` script and the root README/CI workflow), not plain jest.",
    );
  }
  const email = `${uid.toLowerCase().replace(/[^a-z0-9._-]/g, "_")}@test.ilnd`;
  const password = "test-password-123";
  try {
    await admin.auth().updateUser(uid, {email, password, emailVerified});
  } catch (err) {
    if (err.code !== "auth/user-not-found") throw err;
    await admin.auth().createUser({uid, email, password, emailVerified});
  }
  const res = await fetch(
      `http://${host}/identitytoolkit.googleapis.com/v1/` +
      "accounts:signInWithPassword?key=fake-api-key",
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({email, password, returnSecureToken: true}),
      },
  );
  const data = await res.json();
  if (!data.idToken) {
    throw new Error(`Emulator sign-in failed: ${JSON.stringify(data)}`);
  }
  return data.idToken;
}

/**
 * Eski köprünün ürettiği türden bir custom-token oturumu (artık reddedilmeli).
 * @param {string} uid uid
 * @param {object} claims geliştirici claim'leri
 * @return {Promise<string>} ID token
 */
async function getCustomTokenIdToken(uid, claims = {}) {
  const customToken = await admin.auth().createCustomToken(uid, claims);
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const res = await fetch(
      `http://${host}/identitytoolkit.googleapis.com/v1/` +
      "accounts:signInWithCustomToken?key=fake-api-key",
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({token: customToken, returnSecureToken: true}),
      },
  );
  const data = await res.json();
  if (!data.idToken) throw new Error(`Emulator sign-in failed: ${JSON.stringify(data)}`);
  return data.idToken;
}

/**
 * Anonim bir Firebase oturumu açar (Auth emülatörü REST). Uçların anonim
 * oturumu reddettiğini kanıtlamak için.
 * @return {Promise<string>} anonim kullanıcının ID token'ı
 */
async function getAnonymousIdToken() {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const res = await fetch(
      `http://${host}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({returnSecureToken: true}),
      },
  );
  const data = await res.json();
  if (!data.idToken) throw new Error(`Anonymous sign-up failed: ${JSON.stringify(data)}`);
  return data.idToken;
}

/**
 * Mints a real App Check token via the Admin SDK for tests. App Check is
 * verified manually in functions/appCheck.js (onRequest functions cannot use
 * `enforceAppCheck`) and defaults to "monitor" mode, so tests pass without a
 * token. There is no App Check emulator: minting needs a real Firebase App
 * ID via FIREBASE_APP_CHECK_TEST_APP_ID and real credentials. If unset,
 * returns an empty header object.
 * @return {Promise<Object<string,string>>} headers object, possibly empty.
 */
async function getAppCheckHeaderForTests() {
  const appId = process.env.FIREBASE_APP_CHECK_TEST_APP_ID;
  if (!appId) return {};
  try {
    const {token} = await admin.appCheck().createToken(appId);
    return {"X-Firebase-AppCheck": token};
  } catch (err) {
    console.warn("getAppCheckHeaderForTests: createToken failed:", err.message);
    return {};
  }
}

module.exports = {getIdTokenForUid, getCustomTokenIdToken, getAnonymousIdToken, getAppCheckHeaderForTests};
