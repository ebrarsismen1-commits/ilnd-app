import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/repositories/profile_repository.dart';

void main() {
  group('ProfileData.fromDoc tolerates missing/partial docs', () {
    test('null doc → all defaults, never throws', () {
      final d = ProfileData.fromDoc(null);
      expect(d.name, isNull);
      expect(d.onboardingDone, isFalse);
      expect(d.firstEntryDone, isFalse);
      expect(d.goals, isEmpty);
      expect(d.activityLevel, isNull);
      expect(d.diet, isNull);
      expect(d.allergies, isEmpty);
      expect(d.age, isNull);
      expect(d.height, isNull);
      expect(d.weight, isNull);
    });

    test('photo-only users doc (profile never written) → defaults', () {
      // users/{uid} profil fotoğrafını da taşıyor; profil alanı yoksa
      // onboarding tamamlanmamış sayılır, crash yok.
      final d = ProfileData.fromDoc({'photoBase64': 'AAAA', 'name': 'Ada'});
      expect(d.name, 'Ada');
      expect(d.onboardingDone, isFalse);
      expect(d.goals, isEmpty);
    });

    test('empty-string and wrong-typed name is normalized to null', () {
      expect(ProfileData.fromDoc({'name': ''}).name, isNull);
      expect(ProfileData.fromDoc({'name': 42}).name, isNull);
    });

    test('full doc parses every field (camelCase, heightCm/weightKg)', () {
      final d = ProfileData.fromDoc({
        'name': 'Ada',
        'onboardingDone': true,
        'firstEntryDone': true,
        'goals': ['daha_iyi_uyku', 'stres'],
        'activityLevel': 'orta',
        'diet': 'vejetaryen',
        'allergies': ['gluten', 'yumurta'],
        'age': 29,
        'heightCm': 170,
        'weightKg': 62,
      });
      expect(d.name, 'Ada');
      expect(d.onboardingDone, isTrue);
      expect(d.firstEntryDone, isTrue);
      expect(d.goals, ['daha_iyi_uyku', 'stres']);
      expect(d.activityLevel, 'orta');
      expect(d.diet, 'vejetaryen');
      expect(d.allergies, ['gluten', 'yumurta']);
      expect(d.age, 29);
      expect(d.height, 170);
      expect(d.weight, 62);
    });

    test('legacy snake_case keys are NOT read (no silent dual schema)', () {
      final d = ProfileData.fromDoc({
        'onboarding_done': true,
        'height': 170,
        'weight': 62,
      });
      expect(d.onboardingDone, isFalse);
      expect(d.height, isNull);
      expect(d.weight, isNull);
    });

    test('numeric fields coming back as num are coerced to int', () {
      final d = ProfileData.fromDoc({'age': 30.0, 'heightCm': 175.0});
      expect(d.age, 30);
      expect(d.height, 175);
    });
  });

  group('ProfileData.toDoc', () {
    test('always writes flags and lists; omits null optionals', () {
      final map = const ProfileData(onboardingDone: true, goals: ['x']).toDoc();
      expect(map['onboardingDone'], isTrue);
      expect(map['firstEntryDone'], isFalse);
      expect(map['goals'], ['x']);
      expect(map['allergies'], isEmpty);
      // Null opsiyoneller gönderilmez ki sunucudaki mevcut değeri ezmesin.
      for (final k in ['diet', 'activityLevel', 'age', 'name', 'heightCm']) {
        expect(map.containsKey(k), isFalse, reason: k);
      }
    });

    test('includes optionals when present with Firestore names', () {
      final map = const ProfileData(
        name: 'Ada',
        diet: 'vegan',
        activityLevel: 'aktif',
        age: 25,
        height: 180,
        weight: 70,
      ).toDoc();
      expect(map, {
        'name': 'Ada',
        'onboardingDone': false,
        'firstEntryDone': false,
        'goals': <String>[],
        'activityLevel': 'aktif',
        'diet': 'vegan',
        'allergies': <String>[],
        'age': 25,
        'heightCm': 180,
        'weightKg': 70,
      });
    });

    test('round-trips through fromDoc', () {
      const original = ProfileData(
        name: 'Ada',
        onboardingDone: true,
        firstEntryDone: true,
        goals: ['a'],
        activityLevel: 'orta',
        diet: 'vegan',
        allergies: ['gluten'],
        age: 40,
        height: 160,
        weight: 55,
      );
      final back = ProfileData.fromDoc(original.toDoc());
      expect(back.toDoc(), original.toDoc());
    });
  });
}
