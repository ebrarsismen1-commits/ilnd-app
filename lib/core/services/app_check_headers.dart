import 'package:firebase_app_check/firebase_app_check.dart';

/// HTTP header carrying the current App Check token, sent on every Cloud
/// Functions call. The functions are `onRequest` handlers, so App Check is
/// verified manually in functions/appCheck.js and its behaviour depends on
/// the server's `APP_CHECK_MODE` (monitor by default, enforce once the
/// verified-request rate is healthy). It is never authorization: every
/// endpoint still checks the Firebase ID token and only touches the caller's
/// own data.
///
/// Returns an empty map (never throws) if a token can't be obtained —
/// App Check might not be activated yet (e.g. Firebase init failed and the
/// app is mid-retry) or the call might be racing app startup. In enforce
/// mode the function answers 401 in that case; this just avoids crashing
/// the request before it's even sent.
Future<Map<String, String>> appCheckHeaders() async {
  try {
    final token = await FirebaseAppCheck.instance.getToken();
    if (token == null) return const {};
    return {'X-Firebase-AppCheck': token};
  } catch (_) {
    return const {};
  }
}
