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
async function getIdTokenForUid(uid) {
  const customToken = await admin.auth().createCustomToken(uid);
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
 * Mints a real App Check token via the Admin SDK for tests, since
 * `anthropicProxy`/`redeemReferralCode`/`deleteAccount` now run with
 * `enforceAppCheck: true` (functions/index.js). The Admin SDK can mint
 * these directly server-side — no client App Check SDK round-trip needed,
 * same pattern as `createCustomToken` for Auth above.
 *
 * Requires a real Firebase App ID via the FIREBASE_APP_CHECK_TEST_APP_ID
 * env var (the same app id from google-services.json /
 * GoogleService-Info.plist — NOT verified working against the emulator
 * suite in this environment; flagging as unconfirmed). If unset, returns
 * an empty header object and the App-Check-enforced calls will 401 — set
 * this in CI once a real app id is available.
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

module.exports = {getIdTokenForUid, getAppCheckHeaderForTests};
