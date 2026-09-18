import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/repositories/profile_repository.dart';

/// Firestore `users/{uid}` dokümanlarının bellek içi karşılığı: merge
/// semantiği (yalnız verilen alanlar yazılır, diğerleri korunur).
class _MemoryStore implements ProfileStore {
  final docs = <String, Map<String, dynamic>>{};
  Object? failWith;

  @override
  Future<Map<String, dynamic>?> read(String uid) async {
    if (failWith != null) throw failWith!;
    final d = docs[uid];
    return d == null ? null : Map.of(d);
  }

  @override
  Future<void> merge(String uid, Map<String, dynamic> fields) async {
    if (failWith != null) throw failWith!;
    (docs[uid] ??= {}).addAll(fields);
  }
}

void main() {
  late _MemoryStore store;
  setUp(() => store = _MemoryStore());

  test('profile save → load restores every field (app restart)', () async {
    const saved = ProfileData(
      name: 'Ela',
      onboardingDone: true,
      goals: ['uyku'],
      activityLevel: 'aktif',
      diet: 'vegan',
      allergies: ['gluten'],
      age: 31,
      height: 168,
      weight: 72,
    );
    await ProfileRepository('uid-A', store).upsert(saved);

    // Yeni repository örneği = uygulama yeniden başlatıldı.
    final loaded = await ProfileRepository('uid-A', store).fetch();
    expect(loaded, isNotNull);
    expect(loaded!.toDoc(), saved.toDoc());
  });

  test('missing doc (new user) → null', () async {
    expect(await ProfileRepository('uid-new', store).fetch(), isNull);
  });

  test(
    'update keeps fields it does not mention (merge, no overwrite)',
    () async {
      store.docs['uid-A'] = {
        'photoBase64': 'AAAA',
        'goals': ['uyku'],
        'allergies': ['gluten'],
        'weightKg': 72,
      };
      await ProfileRepository('uid-A', store).updateFields({
        ProfileFields.onboardingDone: true,
        ProfileFields.firstEntryDone: true,
      });
      expect(store.docs['uid-A'], {
        'photoBase64': 'AAAA',
        'goals': ['uyku'],
        'allergies': ['gluten'],
        'weightKg': 72,
        'onboardingDone': true,
        'firstEntryDone': true,
      });
    },
  );

  test('onboarding completion is visible on the next fetch', () async {
    final repo = ProfileRepository('uid-A', store);
    await repo.upsert(const ProfileData(onboardingDone: true, weight: 60));
    await repo.updateFields({ProfileFields.firstEntryDone: true});
    final p = (await repo.fetch())!;
    expect(p.onboardingDone, isTrue);
    expect(p.firstEntryDone, isTrue);
    expect(p.weight, 60);
  });

  test('each repository only touches its own uid', () async {
    await ProfileRepository(
      'uid-A',
      store,
    ).upsert(const ProfileData(name: 'A', onboardingDone: true));
    await ProfileRepository(
      'uid-B',
      store,
    ).upsert(const ProfileData(name: 'B'));
    expect((await ProfileRepository('uid-A', store).fetch())!.name, 'A');
    expect((await ProfileRepository('uid-B', store).fetch())!.name, 'B');
    expect(store.docs.keys, unorderedEquals(['uid-A', 'uid-B']));
  });

  test('store errors are swallowed: fetch → null, write → no throw', () async {
    store.failWith = StateError('permission-denied / bridge timeout');
    final repo = ProfileRepository('uid-A', store);
    expect(await repo.fetch(), isNull);
    await expectLater(repo.upsert(const ProfileData()), completes);
    await expectLater(repo.updateFields({'name': 'x'}), completes);
  });
}
