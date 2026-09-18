import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';

/// `users/{uid}` dokümanındaki profil alanlarının adları. Firestore'un mevcut
/// adlandırması camelCase (`photoBase64`, `photoUpdatedAt`); firestore.rules
/// ve functions/scripts/migrateSupabaseProfiles.js aynı adları kullanır.
abstract final class ProfileFields {
  static const name = 'name';
  static const onboardingDone = 'onboardingDone';
  static const firstEntryDone = 'firstEntryDone';
  static const goals = 'goals';
  static const activityLevel = 'activityLevel';
  static const diet = 'diet';
  static const allergies = 'allergies';
  static const age = 'age';
  static const heightCm = 'heightCm';
  static const weightKg = 'weightKg';

  /// İstemcinin her profil yazımında sunucu saatiyle koyduğu damga. Kurallar
  /// `request.time`'a eşit olmasını ister; migration script'i bu alanı gören
  /// kullanıcıyı atlar (Firestore'daki profil Supabase'tekinden yenidir).
  static const updatedAt = 'profileUpdatedAt';
}

/// Kullanıcı profilinin uygulama-tarafı görünümü: onboarding bayrakları +
/// profil verisi. Gerçeğin kaynağı Firestore `users/{uid}` (eskiden Supabase
/// `profiles`, ADR-0003); yerel SharedPreferences yalnız cache'tir.
@immutable
class ProfileData {
  const ProfileData({
    this.name,
    this.onboardingDone = false,
    this.firstEntryDone = false,
    this.goals = const [],
    this.activityLevel,
    this.diet,
    this.allergies = const [],
    this.age,
    this.height,
    this.weight,
  });

  final String? name;
  final bool onboardingDone;
  final bool firstEntryDone;
  final List<String> goals;
  final String? activityLevel;
  final String? diet;
  final List<String> allergies;
  final int? age;

  /// cm — Firestore'da [ProfileFields.heightCm].
  final int? height;

  /// kg — Firestore'da [ProfileFields.weightKg].
  final int? weight;

  /// Dokümandan toleranslı okuma (Sert Kural #3: `doc.data()!` yasak). Eksik
  /// alan crash değil, default demektir; aynı dokümanda profil dışı alanlar
  /// (fotoğraf) da bulunur ve yok sayılır.
  factory ProfileData.fromDoc(Map<String, dynamic>? raw) {
    final d = raw ?? const {};
    List<String> strList(Object? v) =>
        v is List ? v.map((e) => e.toString()).toList() : const [];
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    String? nonEmpty(Object? v) => (v is String && v.isNotEmpty) ? v : null;

    return ProfileData(
      name: nonEmpty(d[ProfileFields.name]),
      onboardingDone: d[ProfileFields.onboardingDone] as bool? ?? false,
      firstEntryDone: d[ProfileFields.firstEntryDone] as bool? ?? false,
      goals: strList(d[ProfileFields.goals]),
      activityLevel: nonEmpty(d[ProfileFields.activityLevel]),
      diet: nonEmpty(d[ProfileFields.diet]),
      allergies: strList(d[ProfileFields.allergies]),
      age: asInt(d[ProfileFields.age]),
      height: asInt(d[ProfileFields.heightCm]),
      weight: asInt(d[ProfileFields.weightKg]),
    );
  }

  /// Merge ile yazılacak alanlar. Null profil alanları gönderilmez (mevcut
  /// sunucu değerini ezmesin), ama bayraklar ve listeler her zaman yazılır
  /// (flush anında kesin durum).
  Map<String, dynamic> toDoc() => {
    if (name != null && name!.isNotEmpty) ProfileFields.name: name,
    ProfileFields.onboardingDone: onboardingDone,
    ProfileFields.firstEntryDone: firstEntryDone,
    ProfileFields.goals: goals,
    if (activityLevel != null) ProfileFields.activityLevel: activityLevel,
    if (diet != null) ProfileFields.diet: diet,
    ProfileFields.allergies: allergies,
    if (age != null) ProfileFields.age: age,
    if (height != null) ProfileFields.heightCm: height,
    if (weight != null) ProfileFields.weightKg: weight,
  };
}

// ─── Store ────────────────────────────────────────────────────────────────────

/// Profil dokümanına ham erişim. Testte bellek içi sahteyle değiştirilir.
abstract interface class ProfileStore {
  /// Doküman yoksa null.
  Future<Map<String, dynamic>?> read(String uid);

  /// Yalnız verilen alanları yazar (merge); diğer alanlar korunur.
  Future<void> merge(String uid, Map<String, dynamic> fields);
}

class FirestoreProfileStore implements ProfileStore {
  FirestoreProfileStore({this.bridgeTimeout = const Duration(seconds: 15)});

  /// Köprü girişini bekleme süresi. Aşılırsa istek hiç gönderilmez (kurallar
  /// zaten reddederdi) ve çağıran "sunucu yanıt vermedi" yoluna düşer.
  final Duration bridgeTimeout;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseService.firestore.collection('users').doc(uid);

  /// Firestore kuralları `request.auth.uid == uid` ister. Auth Supabase'te,
  /// Firebase oturumu ise köprüyle (FirebaseAuthBridge) birkaç yüz ms sonra
  /// gelir; beklemeden okursak permission-denied alır ve kayıtlı kullanıcıyı
  /// yeni cihazda onboarding'e düşürürdük.
  Future<void> _waitForBridge(String uid) async {
    final auth = fb_auth.FirebaseAuth.instance;
    if (auth.currentUser?.uid == uid) return;
    await auth
        .authStateChanges()
        .firstWhere((u) => u?.uid == uid)
        .timeout(bridgeTimeout);
  }

  @override
  Future<Map<String, dynamic>?> read(String uid) async {
    await _waitForBridge(uid);
    final snap = await _doc(uid).get().timeout(const Duration(seconds: 15));
    return snap.exists ? snap.data() : null;
  }

  @override
  Future<void> merge(String uid, Map<String, dynamic> fields) async {
    await _waitForBridge(uid);
    await _doc(uid)
        .set({
          ...fields,
          ProfileFields.updatedAt: FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .timeout(const Duration(seconds: 15));
  }
}

// ─── Repository ───────────────────────────────────────────────────────────────

class ProfileRepository {
  ProfileRepository(this._uid, [ProfileStore? store])
    : _store = store ?? FirestoreProfileStore();

  final String _uid;
  final ProfileStore _store;

  /// Bu hesabın profilini çeker. Doküman yoksa (yeni kullanıcı) null.
  /// Hata (ağ / köprü gecikmesi / kural) durumunda null döner — çağıran taraf
  /// yerel akışa düşer, onboarding bloklanmaz.
  Future<ProfileData?> fetch() async {
    try {
      final doc = await _store.read(_uid);
      if (doc == null) return null;
      return ProfileData.fromDoc(doc);
    } catch (e) {
      debugPrint('[Profile] fetch failed: $e');
      return null;
    }
  }

  /// Onboarding tamamlanınca yerel cevapların tamamını sunucuya flush eder.
  /// Başarısızlık onboarding'i bloklamamalı — hata yutulur, yerel cache gerçeği
  /// taşımaya devam eder ve sonraki girişte tekrar denenir.
  Future<void> upsert(ProfileData data) async {
    await _update(data.toDoc());
  }

  /// Yalnız verilen alanları günceller (merge; diğer alanlar korunur). İlk-
  /// günlük gibi tekil bayrak güncellemelerinde, tam flush'ın boş listelerle
  /// sunucudaki goals/allergies'i ezmesini önler. Anahtarlar [ProfileFields].
  Future<void> updateFields(Map<String, dynamic> fields) async {
    await _update(fields);
  }

  Future<void> _update(Map<String, dynamic> fields) async {
    try {
      await _store.merge(_uid, fields);
    } catch (e) {
      debugPrint('[Profile] write failed: $e');
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// uid Supabase auth'tan gelir. Firestore köprüsünü (Firebase oturumu)
/// beklemek [FirestoreProfileStore]'un işi: hidratlama auth'a geçildiği anda
/// başlamalı ki router splash'te beklesin.
final profileRepositoryProvider = Provider<ProfileRepository?>((ref) {
  final uid = ref.watch(
    authNotifierProvider.select(
      (s) => s is AuthAuthenticated ? s.user.id : null,
    ),
  );
  if (uid == null) return null;
  return ProfileRepository(uid);
});
