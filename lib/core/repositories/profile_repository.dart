import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ilnd_app/features/auth/auth_provider.dart';

/// Supabase `profiles` satırının uygulama-tarafı görünümü — onboarding
/// bayrakları + profil verisi. Gerçeğin kaynağı budur (ADR-0003); yerel
/// SharedPreferences yalnız cache'tir.
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
  final int? height;
  final int? weight;

  /// Supabase satırından toleranslı okuma. `doc.data()!` yasağının Supabase
  /// karşılığı: satır Map? kabul edilir, her alan `?? default`. Eksik kolon
  /// (migration henüz koşulmadıysa) crash değil, default demektir.
  factory ProfileData.fromRow(Map<String, dynamic>? raw) {
    final row = raw ?? const {};
    List<String> strList(Object? v) =>
        v is List ? v.map((e) => e.toString()).toList() : const [];
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    String? nonEmpty(Object? v) {
      final s = v as String?;
      return (s == null || s.isEmpty) ? null : s;
    }

    return ProfileData(
      name: nonEmpty(row['name']),
      onboardingDone: row['onboarding_done'] as bool? ?? false,
      firstEntryDone: row['first_entry_done'] as bool? ?? false,
      goals: strList(row['goals']),
      activityLevel: nonEmpty(row['activity_level']),
      diet: nonEmpty(row['diet']),
      allergies: strList(row['allergies']),
      age: asInt(row['age']),
      height: asInt(row['height']),
      weight: asInt(row['weight']),
    );
  }

  /// `profiles.upsert` için gönderilecek map — `id` çağıran tarafından eklenir.
  /// Null profil alanları gönderilmez (mevcut sunucu değerini ezmesin), ama
  /// bayraklar ve listeler her zaman yazılır (flush anında kesin durum).
  Map<String, dynamic> toUpsert() => {
    if (name != null && name!.isNotEmpty) 'name': name,
    'onboarding_done': onboardingDone,
    'first_entry_done': firstEntryDone,
    'goals': goals,
    if (activityLevel != null) 'activity_level': activityLevel,
    if (diet != null) 'diet': diet,
    'allergies': allergies,
    if (age != null) 'age': age,
    if (height != null) 'height': height,
    if (weight != null) 'weight': weight,
  };
}

// ─── Repository ───────────────────────────────────────────────────────────────

class ProfileRepository {
  ProfileRepository(this._client, this._uid);

  final SupabaseClient _client;
  final String _uid;

  /// Bu hesabın profil satırını çeker. Satır yoksa (yeni kullanıcı) null.
  /// Hata (ağ / eksik kolon) durumunda null döner — çağıran taraf yerel
  /// akışa düşer, onboarding bloklanmaz.
  Future<ProfileData?> fetch() async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', _uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      if (row == null) return null;
      return ProfileData.fromRow(row);
    } catch (e) {
      debugPrint('[Profile] fetch failed: $e');
      return null;
    }
  }

  /// Onboarding tamamlanınca yerel cevapların tamamını sunucuya flush eder.
  /// Başarısızlık onboarding'i bloklamamalı — hata yutulur, yerel cache gerçeği
  /// taşımaya devam eder ve sonraki girişte tekrar denenir.
  Future<void> upsert(ProfileData data) async {
    await _update(data.toUpsert());
  }

  /// Yalnız verilen kolonları günceller (upsert on-conflict yalnız gönderilen
  /// alanları yazar; diğer kolonlar korunur). İlk-günlük gibi tekil bayrak
  /// güncellemelerinde, tam flush'ın boş listelerle sunucudaki goals/allergies'i
  /// ezmesini önler.
  Future<void> updateFields(Map<String, dynamic> fields) async {
    await _update(fields);
  }

  Future<void> _update(Map<String, dynamic> fields) async {
    try {
      await _client
          .from('profiles')
          .upsert({'id': _uid, ...fields})
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[Profile] upsert failed: $e');
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// uid Supabase auth'tan gelir — Firestore köprüsüne bağlı değil (ADR-0003),
/// bu yüzden yalnız `authNotifierProvider`'ı izlemek yeterli.
final profileRepositoryProvider = Provider<ProfileRepository?>((ref) {
  final uid = ref.watch(
    authNotifierProvider.select(
      (s) => s is AuthAuthenticated ? s.user.id : null,
    ),
  );
  if (uid == null) return null;
  return ProfileRepository(Supabase.instance.client, uid);
});
