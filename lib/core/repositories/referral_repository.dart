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

// ─── Redeem sonucu ────────────────────────────────────────────────────────────

/// Davet kodu redeem denemesinin sonucu — kullanıcı metni TAŞIMAZ (Sert
/// Kural #1); UI her durumu kendi l10n mesajına çevirir. Sunucunun döndürdüğü
/// `reason` bilgisini tek bir `bool false`'a indirmemek için var: "kendi
/// kodun", "zaten kullandın", "böyle kod yok" ve "bağlanamadık" birbirinden
/// ayrılamazsa alan "çalışmıyor" gibi görünür (yaşandı).
enum RedeemResult {
  success,
  selfReferral,
  alreadyRedeemed,
  invalidCode,

  /// Köprü/oturum henüz hazır değil ya da ağ/sunucu hatası — kod GEÇERSİZ
  /// değildir, sonra tekrar denenmelidir (pending kod silinmemeli).
  notReady,
  failed;

  /// Terminal sonuçlar tekrar denemekle değişmez → bekleyen kod temizlenir.
  /// notReady/failed geçicidir → kod korunur, ileride yeniden denenir.
  bool get isTerminal =>
      this == success ||
      this == selfReferral ||
      this == alreadyRedeemed ||
      this == invalidCode;
}

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
  // 8 karakter = 32^8 ≈ 1.1 trilyon kombinasyon. Uzunluk 6'dan 8'e çıktı
  // çünkü çakışma kontrolü kaldırıldı: o kontrol koleksiyon-geneli okuma
  // gerektiriyordu ve bu, herkesin davet kodunu görünür kılıyordu (güvenlik
  // denetimi 2026-07-24). 8 karakterde 100 bin kullanıcıda bile çakışma
  // olasılığı binde 5'in altında. Mevcut 6 karakterli kodlar geçerli kalır.
  static const _codeLength = 8;

  CollectionReference<Map<String, dynamic>> get _userGrowthCol =>
      FirebaseService.firestore.collection('user_growth');

  /// Kullanıcının zaten bir referral kodu varsa onu döner; yoksa benzersiz
  /// bir kod üretip user_growth/{userId} dokümanını oluşturur. Kayıt
  /// sırasında bir kez çağrılması yeterlidir, idempotent'tir.
  Future<String> ensureReferralCode() async {
    final existing = await _userGrowthCol.doc(_userId).get();
    final existingCode = existing.data()?['referral_code'] as String?;
    if (existingCode != null && existingCode.isNotEmpty) return existingCode;

    // Çakışma sorgusu bilerek YOK: koleksiyon-geneli okuma gerektiriyordu,
    // o da tüm kullanıcıların davet kodunu okunabilir yapıyordu. Kod uzunluğu
    // 8'e çıkarılarak çakışma olasılığı ihmal edilebilir seviyeye indirildi.
    final code = _generateCode();

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
  Future<RedeemResult> redeemCode(String code) async {
    // Köprü kapalı / oturum yok → kod geçersiz DEĞİL, henüz hazır değil.
    if (!AppConfig.isAuthBridgeConfigured) return RedeemResult.notReady;

    final idToken = await fb_auth.FirebaseAuth.instance.currentUser
        ?.getIdToken();
    if (idToken == null) return RedeemResult.notReady;

    try {
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
        if (data['redeemed'] == true) return RedeemResult.success;
        // Sunucu iş-kuralı reddi: nedeni koru (UI ayrı mesaj gösterir).
        return switch (data['reason']) {
          'self-referral' => RedeemResult.selfReferral,
          'already-redeemed' => RedeemResult.alreadyRedeemed,
          'invalid-code' => RedeemResult.invalidCode,
          _ => RedeemResult.failed,
        };
      }
      // 400 = kod boş/bozuk → geçersiz; 401 = token reddedildi → hazır değil;
      // diğer 4xx/5xx → sunucu hatası, tekrar denenebilir.
      if (response.statusCode == 400) return RedeemResult.invalidCode;
      if (response.statusCode == 401) return RedeemResult.notReady;
      return RedeemResult.failed;
    } catch (_) {
      // Ağ/timeout/parse — geçici, kod korunmalı.
      return RedeemResult.failed;
    }
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
