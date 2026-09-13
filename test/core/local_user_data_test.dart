import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/services/local_user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Güvenlik denetimi H-2: hesap değişiminde önceki kişinin yerel verisi
// sonraki hesaba görünmemeli ya da senkronize edilmemeli.
void main() {
  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('clearPersonalLocalData', () {
    test('kişisel anahtarları, su kayıtlarını ve eski tek anahtarları siler; '
        'cihaz ayarlarına ve uid kapsamlı veriye dokunmaz', () async {
      final prefs = await prefsWith({
        'onboarding_done': true,
        'user_name': 'Ela',
        'onboarding_weight': 72,
        'onboarding_height': 168,
        'onboarding_age': 31,
        'onboarding_allergies': <String>['gluten'],
        'onboarding_goals': <String>['uyku'],
        'onboarding_diet': 'vegan',
        'is_premium': true,
        'longest_streak': 12,
        'mood_checkin_value': 'yorgun',
        'sleep_ritual_done': true,
        'water_2026-09-12': 1500,
        'water_2026-09-13': 500,
        'pending_referral_code': 'ABCDEFGH',
        'local_profile_owner': 'uid-A',
        'ilnd_memory': '{"name":"Ela"}',
        'chat_sessions': '[]',
        // korunacaklar
        'reminder_enabled': true,
        'reminder_hour': 21,
        'weekly_checkin_cache_count': 40,
        'ilnd_memory_uid-A': '{"name":"Ela"}',
        'chat_sessions_uid-A': '[]',
      });

      await clearPersonalLocalData(prefs);

      expect(prefs.getKeys(), {
        'reminder_enabled',
        'reminder_hour',
        'weekly_checkin_cache_count',
        'ilnd_memory_uid-A',
        'chat_sessions_uid-A',
      });
    });

    test('bellekteki değer çağrı döner dönmez temizdir', () async {
      final prefs = await prefsWith({'user_name': 'Ela'});
      final pending = clearPersonalLocalData(prefs);
      expect(prefs.getString('user_name'), isNull);
      await pending;
    });
  });

  test('clearUidScopedLocalData yalnız o hesabın sohbetini ve hafızasını '
      'siler', () async {
    final prefs = await prefsWith({
      'ilnd_memory_uid-A': 'a',
      'chat_sessions_uid-A': 'a',
      'chat_history_uid-A': 'a',
      'ilnd_memory_uid-B': 'b',
      'chat_sessions_uid-B': 'b',
    });
    await clearUidScopedLocalData(prefs, 'uid-A');
    expect(prefs.getKeys(), {'ilnd_memory_uid-B', 'chat_sessions_uid-B'});
  });

  group('yerel profil sahipliği', () {
    test('sahipsiz profil ilk hesaba aittir ve sahiplenilir', () async {
      final prefs = await prefsWith({'onboarding_done': true});
      expect(localProfileBelongsTo(prefs, 'uid-A'), isTrue);
      await claimLocalProfile(prefs, 'uid-A');
      expect(localProfileBelongsTo(prefs, 'uid-A'), isTrue);
      expect(localProfileBelongsTo(prefs, 'uid-B'), isFalse);
    });

    test('sahipsiz eski kurulum oturumsuzken yetim sayılır', () async {
      final legacy = await prefsWith({'onboarding_done': true});
      expect(isLegacyOrphanedProfile(legacy, hasSession: false), isTrue);
      expect(isLegacyOrphanedProfile(legacy, hasSession: true), isFalse);

      final fresh = await prefsWith({
        'onboarding_done': true,
        kLocalDataSchema: kLocalDataSchemaVersion,
      });
      expect(isLegacyOrphanedProfile(fresh, hasSession: false), isFalse);

      final empty = await prefsWith({});
      expect(isLegacyOrphanedProfile(empty, hasSession: false), isFalse);
    });
  });

  group('LocalDataGuard', () {
    test('ilk giriş silmez', () {
      final g = LocalDataGuard();
      expect(g.observe(uid: null, transient: false), LocalDataAction.none);
      expect(g.observe(uid: 'A', transient: false), LocalDataAction.none);
    });

    test('çıkış siler', () {
      final g = LocalDataGuard()..observe(uid: 'A', transient: false);
      expect(g.observe(uid: null, transient: false), LocalDataAction.wipe);
      // sonraki girişte tekrar silmez
      expect(g.observe(uid: 'B', transient: false), LocalDataAction.none);
    });

    test('çıkışsız hesap değişimi de siler', () {
      final g = LocalDataGuard()..observe(uid: 'A', transient: false);
      expect(g.observe(uid: 'B', transient: false), LocalDataAction.wipe);
    });

    test('geçici durumlar (yükleniyor/hata) silmez', () {
      final g = LocalDataGuard()..observe(uid: 'A', transient: false);
      expect(g.observe(uid: null, transient: true), LocalDataAction.none);
      expect(g.observe(uid: 'A', transient: false), LocalDataAction.none);
    });

    test('aynı hesabın token yenilemesi silmez', () {
      final g = LocalDataGuard()..observe(uid: 'A', transient: false);
      expect(g.observe(uid: 'A', transient: false), LocalDataAction.none);
    });
  });
}
