import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ilnd_app/core/services/app_check_headers.dart';
import 'package:ilnd_app/core/services/app_config.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class UserGrowthProfile {
  const UserGrowthProfile({
    required this.referralCode,
    this.referredByCode,
    required this.foundingMember,
    this.premiumAccessUntil,
  });

  final String referralCode;
  final String? referredByCode;
  final bool foundingMember;
  final DateTime? premiumAccessUntil;

  factory UserGrowthProfile.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return UserGrowthProfile(
      referralCode: data['referral_code'] as String? ?? '',
      referredByCode: data['referred_by_code'] as String?,
      foundingMember: data['founding_member'] as bool? ?? false,
      premiumAccessUntil: (data['premium_access_until'] as Timestamp?)
          ?.toDate(),
    );
  }

  bool get hasActivePremiumReward =>
      premiumAccessUntil != null && premiumAccessUntil!.isAfter(DateTime.now());
}

// ─── Repository ───────────────────────────────────────────────────────────────

class ReferralRepository {
  ReferralRepository(this._userId);

  final String _userId;

  static const _codeChars =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 0/O, 1/I/L hariç
  static const _codeLength = 6;

  CollectionReference<Map<String, dynamic>> get _userGrowthCol =>
      FirebaseService.firestore.collection('user_growth');

  /// Kullanıcının zaten bir referral kodu varsa onu döner; yoksa benzersiz
  /// bir kod üretip user_growth/{userId} dokümanını oluşturur. Kayıt
  /// sırasında bir kez çağrılması yeterlidir, idempotent'tir.
  Future<String> ensureReferralCode() async {
    final existing = await _userGrowthCol.doc(_userId).get();
    final existingCode = existing.data()?['referral_code'] as String?;
    if (existingCode != null && existingCode.isNotEmpty) return existingCode;

    String code = _generateCode();
    for (var attempt = 0; attempt < 5; attempt++) {
      final clash = await _userGrowthCol
          .where('referral_code', isEqualTo: code)
          .limit(1)
          .get();
      if (clash.docs.isEmpty) break;
      code = _generateCode();
    }

    await _userGrowthCol.doc(_userId).set({
      'referral_code': code,
      'referred_by_code': null,
      'founding_member': false,
      'premium_access_until': null,
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return code;
  }

  Future<UserGrowthProfile?> getMyGrowthProfile() async {
    final doc = await _userGrowthCol.doc(_userId).get();
    if (!doc.exists) return null;
    return UserGrowthProfile.fromDoc(doc);
  }

  /// Bir davet kodunu kullanıcı adına redeem eder.
  ///
  /// Bütün doğrulama + yazma işi sunucuda (functions/index.js'teki
  /// redeemReferralCode, Admin SDK + transaction) yapılır — Firestore rules
  /// client'ın founding_member/premium_access_until alanlarını yazmasına izin
  /// vermiyor, bu yüzden client artık ödülü kendisi hesaplayıp yazamaz.
  Future<bool> redeemCode(String code) async {
    if (!AppConfig.isAuthBridgeConfigured) return false;

    final idToken = await fb_auth.FirebaseAuth.instance.currentUser
        ?.getIdToken();
    if (idToken == null) return false;

    final response = await http
        .post(
          Uri.parse(AppConfig.redeemReferralCodeUrl),
          headers: {
            'Authorization': 'Bearer $idToken',
            'content-type': 'application/json',
            ...await appCheckHeaders(),
          },
          body: jsonEncode({'code': code.trim().toUpperCase()}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return false;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['redeemed'] == true;
  }

  static String _generateCode() {
    final rand = Random.secure();
    return List.generate(
      _codeLength,
      (_) => _codeChars[rand.nextInt(_codeChars.length)],
    ).join();
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final referralRepositoryProvider = Provider<ReferralRepository?>((ref) {
  final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
  if (fbUid == null) return null; // köprü girişi bekleniyor
  final auth = ref.watch(authNotifierProvider);
  if (auth is AuthAuthenticated) {
    return ReferralRepository(auth.user.id);
  }
  return null;
});

final myGrowthProfileProvider = FutureProvider<UserGrowthProfile?>((ref) {
  final repo = ref.watch(referralRepositoryProvider);
  if (repo == null) return Future.value(null);
  return repo.getMyGrowthProfile();
});
