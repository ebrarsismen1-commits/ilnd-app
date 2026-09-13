import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ilnd_app/core/services/app_check_headers.dart';
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
            headers: {
              'Authorization': 'Bearer $supabaseAccessToken',
              // Sunucu bu uçta App Check'i yalnız izler, reddetmez; token
              // gönderilmezse doğrulanmış istek oranı ölçülemez (denetim H-5).
              ...await appCheckHeaders(),
            },
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

  /// İki oturum aynı hesaba mı ait?
  ///
  /// Güvenlik denetimi M-8: köprü hata verince sessizce dönüyor ve önceki
  /// kullanıcının Firebase oturumu açık kalabiliyordu. O durumda ekranda B
  /// görünürken hesap silme ya da davet kodu A'nın token'ıyla gidiyordu.
  @visibleForTesting
  static bool sessionsMatch({
    required String? firebaseUid,
    required String? supabaseUid,
  }) =>
      firebaseUid != null && supabaseUid != null && firebaseUid == supabaseUid;

  /// Hesabı etkileyen bir çağrıdan önce: Firebase oturumu [supabaseUid] ile
  /// eşleşmiyorsa onu kapatır ve false döner (çağrı yapılmamalı; köprü bir
  /// sonraki auth olayında doğru hesapla yeniden kurulur).
  static Future<bool> ensureSameAccount(String? supabaseUid) async {
    final firebaseUid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    if (sessionsMatch(firebaseUid: firebaseUid, supabaseUid: supabaseUid)) {
      return true;
    }
    if (firebaseUid != null) {
      debugPrint(
        '[FirebaseAuthBridge] session mismatch — signing out Firebase',
      );
      await signOut();
    }
    return false;
  }

  static Future<void> signOut() async {
    try {
      await fb_auth.FirebaseAuth.instance.signOut();
    } catch (_) {
      // zaten çıkış yapılmışsa veya hiç girilmediyse sessizce yut
    }
  }
}
