import 'package:firebase_app_check/firebase_app_check.dart';

/// HTTP header carrying the current App Check token, for calls to the
/// Cloud Functions that enforce it (`anthropicProxy`, `redeemReferralCode`,
/// `deleteAccount` — see functions/index.js's `enforceAppCheck: true`).
///
/// Returns an empty map (never throws) if a token can't be obtained —
/// App Check might not be activated yet (e.g. Firebase init failed and the
/// app is mid-retry) or the call might be racing app startup. The function
/// itself rejects the request with its own clear error in that case; this
/// just avoids crashing the request before it's even sent.
Future<Map<String, String>> appCheckHeaders() async {
  try {
    final token = await FirebaseAppCheck.instance.getToken();
    if (token == null) return const {};
    return {'X-Firebase-AppCheck': token};
  } catch (_) {
    return const {};
  }
}
