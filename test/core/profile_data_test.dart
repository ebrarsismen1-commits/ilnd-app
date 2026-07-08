import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/repositories/profile_repository.dart';

void main() {
  group('ProfileData.fromRow tolerates missing/partial rows (ADR-0003)', () {
    test('null row → all defaults, never throws', () {
      final d = ProfileData.fromRow(null);
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

    test(
      'row missing onboarding columns (migration not yet run) → defaults',
      () {
        // Yalnız eski şema (name) döndüğünde crash yok, yeni alanlar default.
        final d = ProfileData.fromRow({'id': 'u1', 'name': 'Ada'});
        expect(d.name, 'Ada');
        expect(d.onboardingDone, isFalse);
        expect(d.goals, isEmpty);
      },
    );

    test('empty-string name is normalized to null', () {
      expect(ProfileData.fromRow({'name': ''}).name, isNull);
    });

    test('full row parses every field', () {
      final d = ProfileData.fromRow({
        'name': 'Ada',
        'onboarding_done': true,
        'first_entry_done': true,
        'goals': ['daha_iyi_uyku', 'stres'],
        'activity_level': 'orta',
        'diet': 'vejetaryen',
        'allergies': ['gluten', 'yumurta'],
        'age': 29,
        'height': 170,
        'weight': 62,
      });
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

    test('numeric fields coming back as num are coerced to int', () {
      final d = ProfileData.fromRow({'age': 30.0, 'height': 175.0});
      expect(d.age, 30);
      expect(d.height, 175);
    });

    test('list fields with dynamic entries are stringified', () {
      final d = ProfileData.fromRow({
        'goals': ['a', 'b'],
        'allergies': const [],
      });
      expect(d.goals, ['a', 'b']);
      expect(d.allergies, isEmpty);
    });
  });

  group('ProfileData.toUpsert', () {
    test('always writes flags and lists; omits null optionals', () {
      final map = const ProfileData(
        onboardingDone: true,
        goals: ['x'],
      ).toUpsert();
      expect(map['onboarding_done'], isTrue);
      expect(map['first_entry_done'], isFalse);
      expect(map['goals'], ['x']);
      expect(map['allergies'], isEmpty);
      // Null opsiyoneller gönderilmez ki sunucudaki mevcut değeri ezmesin.
      expect(map.containsKey('diet'), isFalse);
      expect(map.containsKey('activity_level'), isFalse);
      expect(map.containsKey('age'), isFalse);
      expect(map.containsKey('name'), isFalse);
    });

    test('includes optionals when present', () {
      final map = const ProfileData(
        name: 'Ada',
        diet: 'vegan',
        activityLevel: 'aktif',
        age: 25,
      ).toUpsert();
      expect(map['name'], 'Ada');
      expect(map['diet'], 'vegan');
      expect(map['activity_level'], 'aktif');
      expect(map['age'], 25);
    });
  });
}
