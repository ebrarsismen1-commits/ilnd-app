import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/repositories/profile_repository.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

/// Girişten sonra profil senkronizasyonunun durumu. Router, `done` olana kadar
/// authenticated kullanıcıyı yönlendirmez (sunucu gerçeği çözülsün) — ADR-0003.
enum ProfileHydrationStatus { idle, syncing, done }

/// Auth `AuthAuthenticated`'a geçtiğinde bir kez çalışır:
/// - Sunucuda onboarding tamamlanmışsa → yerel cache'i sunucudan **hidratla**.
/// - Aksi halde (bu cihazda yeni tamamlanmış onboarding) → yerel cevapları
///   sunucuya **flush** et.
/// uid değişince (çıkış / farklı hesap) sıfırlanır ki yeni hesap için yeniden
/// koşsun — Sert Kural #2 (kullanıcıya-bağlı provider auth'u izler).
final profileHydrationProvider =
    StateNotifierProvider<ProfileHydrationNotifier, ProfileHydrationStatus>((
      ref,
    ) {
      return ProfileHydrationNotifier(ref);
    });

class ProfileHydrationNotifier extends StateNotifier<ProfileHydrationStatus> {
  ProfileHydrationNotifier(this._ref) : super(ProfileHydrationStatus.idle) {
    _ref.listen<String?>(
      authNotifierProvider.select(
        (s) => s is AuthAuthenticated ? s.user.id : null,
      ),
      (_, next) => _onUid(next),
      fireImmediately: true,
    );
  }

  final Ref _ref;
  String? _handledUid;

  Future<void> _onUid(String? uid) async {
    if (uid == null) {
      _handledUid = null;
      if (mounted) state = ProfileHydrationStatus.idle;
      return;
    }
    if (uid == _handledUid) return; // aynı uid (token yenileme) — tekrar koşma
    _handledUid = uid;
    if (mounted) state = ProfileHydrationStatus.syncing;
    try {
      await _sync();
    } finally {
      if (mounted) state = ProfileHydrationStatus.done;
    }
  }

  Future<void> _sync() async {
    final repo = _ref.read(profileRepositoryProvider);
    if (repo == null) return;
    final server = await repo.fetch();
    if (server != null && server.onboardingDone) {
      await _hydrate(server);
    } else {
      await _flushIfOnboarded();
    }
  }

  /// Sunucu gerçeğini yerel cache'e uygular. `onboarding_done` en sona bırakılır
  /// ki router redirect'i her şey yerine oturduktan sonra tetiklensin.
  Future<void> _hydrate(ProfileData s) async {
    if (s.name != null) {
      await _ref.read(userNameProvider.notifier).save(s.name!);
    }
    await _ref.read(onboardingGoalsProvider.notifier).setAll(s.goals);
    if (s.activityLevel != null) {
      await _ref
          .read(onboardingFrequencyProvider.notifier)
          .select(s.activityLevel!);
    }
    await _ref.read(onboardingDietProvider.notifier).select(s.diet);
    await _ref.read(onboardingAllergiesProvider.notifier).setAll(s.allergies);
    await _ref.read(onboardingAgeProvider.notifier).save(s.age);
    await _ref.read(onboardingHeightProvider.notifier).save(s.height);
    await _ref.read(onboardingWeightProvider.notifier).save(s.weight);

    // AI-görünür gerçekler yeni cihazda boştur — yapısal profilden yeniden kur.
    final memory = _ref.read(ilndMemoryProvider.notifier);
    if (s.name != null) await memory.setName(s.name!);
    for (final fact in _profileFacts(s)) {
      await memory.addFact(fact);
    }

    if (s.firstEntryDone) {
      await _ref.read(firstEntryDoneProvider.notifier).setDone();
    }
    await _ref.read(onboardingDoneProvider.notifier).setDone();
  }

  Future<void> _flushIfOnboarded() async {
    // Onboarding henüz yapılmamışsa flush edilecek bir şey yok.
    if (!_ref.read(onboardingDoneProvider)) return;
    final repo = _ref.read(profileRepositoryProvider);
    if (repo == null) return;
    await repo.upsert(_snapshotLocal());
  }

  ProfileData _snapshotLocal() {
    return ProfileData(
      name: _ref.read(userNameProvider),
      onboardingDone: _ref.read(onboardingDoneProvider),
      firstEntryDone: _ref.read(firstEntryDoneProvider),
      goals: _ref.read(onboardingGoalsProvider),
      activityLevel: _ref.read(onboardingFrequencyProvider),
      diet: _ref.read(onboardingDietProvider),
      allergies: _ref.read(onboardingAllergiesProvider),
      age: _ref.read(onboardingAgeProvider),
      height: _ref.read(onboardingHeightProvider),
      weight: _ref.read(onboardingWeightProvider),
    );
  }
}

// ─── Yapısal profil → AI gerçekleri (kanonik TR, context-free) ────────────────
// quick_setup'ın ürettiği fact biçimiyle aynı kalıp; hidratlamada BuildContext
// olmadığı için etiketler burada sabit (AI kişiliği zaten TR).

const _dietLabels = {
  'vejetaryen': 'vejetaryen',
  'vegan': 'vegan',
  'glutensiz': 'glütensiz',
  'laktozsuz': 'laktozsuz',
};

const _allergyLabels = {
  'findik_kabuklu': 'fındık/kabuklu yemiş',
  'sut_laktoz': 'süt/laktoz',
  'gluten': 'gluten',
  'deniz_urunu': 'deniz ürünü',
  'yumurta': 'yumurta',
};

const _activityLabels = {
  'az_hareketli': 'az hareketli',
  'orta': 'orta',
  'aktif': 'aktif',
};

List<String> _profileFacts(ProfileData s) {
  final facts = <String>[];
  if (s.age != null) facts.add('Yaş: ${s.age}');
  if (s.height != null) facts.add('Boy: ${s.height} cm');
  if (s.weight != null) facts.add('Kilo: ${s.weight} kg');
  final diet = s.diet;
  if (diet != null && diet != 'yok') {
    facts.add('Beslenme tercihi: ${_dietLabels[diet] ?? diet}');
  }
  if (s.allergies.isNotEmpty) {
    final labels = s.allergies.map((a) => _allergyLabels[a] ?? a).join(', ');
    facts.add('Alerjiler: $labels');
  }
  final activity = s.activityLevel;
  if (activity != null) {
    facts.add('Aktivite seviyesi: ${_activityLabels[activity] ?? activity}');
  }
  return facts;
}
