const admin = require("firebase-admin");

/**
 * Exchanges a freshly-minted custom token for a real, verifiable ID token
 * via the Auth Emulator's REST API. The Admin SDK can mint custom tokens
 * but can't produce an ID token directly — only a client sign-in flow can,
 * which is exactly what `signInWithCustomToken` against the emulator does.
 * Every test that needs `Authorization: Bearer <idToken>` goes through this.
 * @param {string} uid Firebase uid to mint a token for.
 * @return {Promise<string>} a verifiable Firebase ID token for that uid.
 */
async function getIdTokenForUid(uid, claims = {provider: "supabase"}) {
  // Üretimde her Firebase oturumu mintFirebaseToken'dan gelir ve bu claim'i
  // taşır; uçlar başka oturumu reddeder (denetim H-5).
  const customToken = await admin.auth().createCustomToken(uid, claims);
  const authEmulatorHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  if (!authEmulatorHost) {
    throw new Error(
        "FIREBASE_AUTH_EMULATOR_HOST is not set — these tests must run " +
        "via `firebase emulators:exec` (see functions/package.json's " +
        "`test` script and the root README/CI workflow), not plain jest.",
    );
  }

  const res = await fetch(
      `http://${authEmulatorHost}/identitytoolkit.googleapis.com/v1/` +
      "accounts:signInWithCustomToken?key=fake-api-key",
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({token: customToken, returnSecureToken: true}),
      },
  );
  const data = await res.json();
  if (!data.idToken) {
    throw new Error(`Emulator sign-in failed: ${JSON.stringify(data)}`);
  }
  return data.idToken;
}

/**
 * Anonim bir Firebase oturumu açar (Auth emülatörü REST). Uçların yalnız
 * Supabase köprüsünden gelen oturumu kabul ettiğini kanıtlamak için.
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

module.exports = {getIdTokenForUid, getAnonymousIdToken, getAppCheckHeaderForTests};
