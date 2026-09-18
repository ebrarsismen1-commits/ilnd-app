import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/repositories/profile_repository.dart';
import 'package:ilnd_app/core/services/local_data_guard.dart';
import 'package:ilnd_app/core/services/streak_tracker.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/habits/habits_provider.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/onboarding/profile_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// Güvenlik denetimi H-2: paylaşılan bir cihazda A'nın yerel verisi
/// (onboarding cevapları, sağlık alanları, AI hafızası, sohbet, premium, su,
/// ruh hali) B'nin hesabında GÖRÜNMEMELİ ve B'nin sunucu profiline
/// SENKRONİZE EDİLMEMELİ.

/// Durumu testten sürülen AuthNotifier. Kurucu Supabase istemcisini okuyor
/// (oturum yok, ağ çağrısı yok) ve ilk durumu kurar; SONRASINI yalnız test
/// belirler.
///
/// Neden durum yazımı kilitli: gerçek notifier Supabase'in onAuthStateChange
/// akışına abone. O akış ilk olayını (initialSession, oturum yok) ASENKRON
/// yayıyor ve testin verdiği "B girdi" durumunu bir pompa sonra
/// "kimliksiz"e çeviriyordu; hidratlama yarıda kalıyor, testler yanlış
/// sebepten geçip kalabiliyordu. Kurucu bittikten sonra yalnız [emit] yazar.
class _FakeAuth extends AuthNotifier {
  _FakeAuth(super.ref) {
    _writable = false;
  }

  // Alan başlatıcısı süper kurucudan ÖNCE çalışır: _init'in ilk durumu
  // yazabilmesi için başta açık.
  bool _writable = true;

  void emit(AuthState s) {
    _writable = true;
    state = s;
    _writable = false;
  }

  @override
  set state(AuthState value) {
    if (_writable) super.state = value;
  }

  @override
  AuthState get state => super.state;
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(this.server, String uid) : super(uid, _NoStore());

  final ProfileData? server;
  final upserts = <Map<String, dynamic>>[];

  @override
  Future<ProfileData?> fetch() async => server;

  @override
  Future<void> upsert(ProfileData data) async => upserts.add(data.toDoc());

  @override
  Future<void> updateFields(Map<String, dynamic> fields) async =>
      upserts.add(fields);
}

/// Sahte repository hiçbir metodu üst sınıfa devretmez; store'a asla
/// ulaşılmamalı.
class _NoStore implements ProfileStore {
  @override
  Future<Map<String, dynamic>?> read(String uid) =>
      throw StateError('store kullanılmamalı');

  @override
  Future<void> merge(String uid, Map<String, dynamic> fields) =>
      throw StateError('store kullanılmamalı');
}

User _user(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  late SharedPreferences prefs;
  late ProviderContainer c;
  late _FakeAuth auth;
  late Map<String, _FakeProfileRepository> repos;

  Future<void> setUpContainer(
    Map<String, Object> initial, {
    ProfileData? serverB,
  }) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues(initial);
    prefs = await SharedPreferences.getInstance();

    repos = {
      'uid-A': _FakeProfileRepository(
        const ProfileData(
          name: 'Ela',
          onboardingDone: true,
          firstEntryDone: true,
          goals: ['uyku'],
          allergies: ['gluten'],
          age: 31,
          height: 168,
          weight: 72,
        ),
        'uid-A',
      ),
      // B yeni hesap: sunucuda profili yok.
      'uid-B': _FakeProfileRepository(serverB, 'uid-B'),
    };

    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authNotifierProvider.overrideWith((ref) => auth = _FakeAuth(ref)),
        profileRepositoryProvider.overrideWith((ref) {
          final s = ref.watch(authNotifierProvider);
          return s is AuthAuthenticated ? repos[s.user.id] : null;
        }),
      ],
    );
    addTearDown(c.dispose);
    // Uygulama kökündeki gibi canlı tutulur.
    c.listen(localDataGuardProvider, (_, _) {});
    c.listen(profileHydrationProvider, (_, _) {});
    c.listen(ilndMemoryProvider, (_, _) {});
  }

  /// Hidratlama bitene kadar bekler; "senkronize edilmedi" iddiaları senkron
  /// adımı hiç çalışmadığı için değil, çalışıp yazmadığı için geçsin.
  Future<void> settle() async {
    for (var i = 0; i < 100; i++) {
      await pumpEventQueue();
      if (c.read(profileHydrationProvider) != ProfileHydrationStatus.syncing) {
        break;
      }
    }
    expect(
      c.read(profileHydrationProvider),
      isNot(ProfileHydrationStatus.syncing),
      reason: 'hidratlama zaman aşımına uğradı',
    );
    await pumpEventQueue();
  }

  test('A girer, veri oluşur, çıkar; B girince A\'dan hiçbir şey görünmez '
      've B\'nin profiline gitmez', () async {
    await setUpContainer({});

    // 1. A girer: sunucu profili hidratlanır.
    auth.emit(AuthAuthenticated(_user('uid-A')));
    await settle();
    expect(c.read(profileHydrationProvider), ProfileHydrationStatus.done);
    expect(c.read(userNameProvider), 'Ela');
    expect(c.read(onboardingWeightProvider), 72);

    // 2. A veri üretir.
    await c.read(isPremiumProvider.notifier).setPremium(true);
    await c.read(todaysMoodProvider.notifier).record('yorgun');
    await c.read(waterTodayProvider.notifier).add(500);
    await c.read(ilndMemoryProvider.notifier).addFact('gece vardiyasında');
    await prefs.setString('chat_sessions_uid-A', '[{"id":"s1"}]');
    await c.read(referralCodeInputProvider.notifier).save('ABCDEFGH');
    expect(c.read(ilndMemoryProvider).facts, contains('gece vardiyasında'));

    // 3. A çıkar.
    auth.emit(const AuthUnauthenticated());
    await settle();

    // 4. B girer (sunucuda profil yok).
    auth.emit(AuthAuthenticated(_user('uid-B')));
    await settle();

    // 5. B, A'nın hiçbir yerel verisini görmez.
    expect(c.read(userNameProvider), isEmpty);
    expect(c.read(onboardingWeightProvider), isNull);
    expect(c.read(onboardingHeightProvider), isNull);
    expect(c.read(onboardingAgeProvider), isNull);
    expect(c.read(onboardingAllergiesProvider), isEmpty);
    expect(c.read(onboardingGoalsProvider), isEmpty);
    expect(c.read(onboardingDoneProvider), isFalse);
    expect(c.read(isPremiumProvider), isFalse);
    expect(c.read(todaysMoodProvider), isNull);
    expect(c.read(waterTodayProvider), 0);
    expect(c.read(referralCodeInputProvider), isNull);
    final memoryB = c.read(ilndMemoryProvider);
    expect(memoryB.name, isEmpty);
    expect(memoryB.facts, isEmpty);

    // ... ve B'nin sunucu profiline A'nın verisi yazılmaz.
    expect(repos['uid-B']!.upserts, isEmpty);

    // A'nın uid kapsamlı sohbeti B'nin anahtarında değil.
    expect(prefs.getString('chat_sessions_uid-B'), isNull);
    // Sahiplik de sıfırlandı.
    expect(prefs.getString('local_profile_owner'), isNull);
  });

  test('çıkış olayı gelmeden hesap değişse de A\'nın cevapları B\'ye '
      'senkronize edilmez', () async {
    await setUpContainer({
      'onboarding_done': true,
      'local_data_schema': 2,
      'local_profile_owner': 'uid-A',
      'user_name': 'Ela',
      'onboarding_weight': 72,
      'onboarding_allergies': <String>['gluten'],
    });

    auth.emit(AuthAuthenticated(_user('uid-B')));
    await settle();

    expect(repos['uid-B']!.upserts, isEmpty);
    expect(c.read(onboardingDoneProvider), isFalse);
    expect(c.read(onboardingWeightProvider), isNull);
    expect(c.read(ilndMemoryProvider).facts, isEmpty);
  });

  test('oturumsuz yapılan onboarding ilk giriş yapan hesaba senkronize '
      'olur (mevcut davranış korunur)', () async {
    await setUpContainer({
      'onboarding_done': true,
      'local_data_schema': 2,
      'user_name': 'Deniz',
      'onboarding_weight': 64,
    });

    auth.emit(AuthAuthenticated(_user('uid-B')));
    await settle();

    expect(repos['uid-B']!.upserts, hasLength(1));
    expect(repos['uid-B']!.upserts.single['weightKg'], 64);
    expect(prefs.getString('local_profile_owner'), 'uid-B');
    expect(c.read(onboardingDoneProvider), isTrue);
  });

  test('sahibi bilinmeyen eski kurulumun verisi (bu sürümden önce çıkış '
      'yapılmış) sonraki hesaba verilmez', () async {
    await setUpContainer({
      // şema işareti YOK: eski sürümün bıraktığı veri
      'onboarding_done': true,
      'user_name': 'Ela',
      'onboarding_weight': 72,
    });
    // Oturumsuz açılış.
    auth.emit(const AuthUnauthenticated());
    await settle();

    auth.emit(AuthAuthenticated(_user('uid-B')));
    await settle();

    expect(repos['uid-B']!.upserts, isEmpty);
    expect(c.read(userNameProvider), isEmpty);
  });

  test(
    'aynı hesabın geçici durumları (yükleniyor) yerel veriyi silmez',
    () async {
      await setUpContainer({});
      auth.emit(AuthAuthenticated(_user('uid-A')));
      await settle();
      expect(c.read(userNameProvider), 'Ela');

      auth.emit(const AuthLoading());
      await settle();
      auth.emit(AuthAuthenticated(_user('uid-A')));
      await settle();

      expect(c.read(userNameProvider), 'Ela');
      expect(c.read(onboardingWeightProvider), 72);
    },
  );

  // Staging doğrulaması (2026-09-13): A'nın oturumu uygulama KAPALIYKEN
  // bitti (token süresi, başka cihazda silme). Uygulama oturumsuz açılır,
  // çıkış olayı hiç görülmez; sonra sunucuda profili OLAN B girer. Hidratlama
  // yalnız sunucuda dolu alanları yazdığı için A'nın adı, aktivite seviyesi,
  // yerel premium bayrağı, su/seri kayıtları ve bekleyen davet kodu B'de
  // kalıyordu.
  test('soğuk açılış: A\'nın oturumu kapalıyken bitti, B sunucu profiliyle '
      'girer; A\'nın yerel verisi B\'de görünmez', () async {
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';
    await setUpContainer(
      {
        'onboarding_done': true,
        'first_entry_done': true,
        'local_data_schema': 2,
        'local_profile_owner': 'uid-A',
        'user_name': 'Ela',
        'onboarding_frequency': 'aktif',
        'onboarding_weight': 72,
        'is_premium': true,
        'pending_referral_code': 'ABCDEFGH',
        'longest_streak': 12,
        waterKey(today): 1500,
      },
      serverB: const ProfileData(
        onboardingDone: true,
        firstEntryDone: true,
        weight: 80,
      ),
    );

    auth.emit(AuthAuthenticated(_user('uid-B')));
    await settle();

    // Hidratlama çalıştı: B'nin sunucu verisi yerinde.
    expect(c.read(onboardingWeightProvider), 80);
    expect(c.read(onboardingDoneProvider), isTrue);
    expect(prefs.getString('local_profile_owner'), 'uid-B');

    // A'nın, B'nin sunucusunda karşılığı olmayan verisi kalmadı.
    expect(c.read(userNameProvider), isEmpty);
    expect(c.read(onboardingFrequencyProvider), isNull);
    expect(c.read(isPremiumProvider), isFalse);
    expect(c.read(referralCodeInputProvider), isNull);
    expect(c.read(waterTodayProvider), 0);
    expect(c.read(longestStreakProvider), 0);
    expect(c.read(ilndMemoryProvider).name, isEmpty);
    expect(repos['uid-B']!.upserts, isEmpty);
  });
}
