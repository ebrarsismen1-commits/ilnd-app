import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ilnd_app/core/services/app_config.dart';

/// ILND auth Supabase üzerinden yapılıyor, ama Firestore güvenlik kuralları
/// Firebase'in kendi `request.auth`'una bakıyor. Bu köprü olmadan
/// `request.auth` hep null kalır ve TÜM Firestore okuma/yazmaları
/// permission-denied ile başarısız olur (journal, referral, vibe card,
/// check-in — hepsi).
///
/// `functions/index.js`'teki `mintFirebaseToken` Cloud Function'ı Supabase
/// JWT'sini doğrulayıp aynı user id ile bir Firebase custom token üretir;
/// burada o token'la Firebase Auth'a girilir. AUTH_BRIDGE_URL boşken
/// (fonksiyon henüz deploy edilmediyse) sessizce no-op olur.
abstract final class FirebaseAuthBridge {
  static Future<void> syncFromSupabase(String supabaseAccessToken) async {
    if (!AppConfig.isAuthBridgeConfigured) return;
    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.authBridgeUrl),
            headers: {'Authorization': 'Bearer $supabaseAccessToken'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint(
          '[FirebaseAuthBridge] mintFirebaseToken ${response.statusCode}: ${response.body}',
        );
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final firebaseToken = data['firebaseToken'] as String?;
      if (firebaseToken == null) return;

      await fb_auth.FirebaseAuth.instance.signInWithCustomToken(firebaseToken);
    } catch (e) {
      debugPrint('[FirebaseAuthBridge] sync failed: $e');
    }
  }

  static Future<void> signOut() async {
    try {
      await fb_auth.FirebaseAuth.instance.signOut();
    } catch (_) {
      // zaten çıkış yapılmışsa veya hiç girilmediyse sessizce yut
    }
  }
}
