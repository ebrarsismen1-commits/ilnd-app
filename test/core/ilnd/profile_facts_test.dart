import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/repositories/profile_repository.dart';
import 'package:ilnd_app/features/onboarding/profile_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yapısal profilin ILND hafızasına yazılması.
///
/// `addFact` yalnız birebir aynı dizeyi eler. Kullanıcı kilosunu
/// güncellediğinde "Kilo: 70 kg" listede kalıp yanına "Kilo: 71 kg"
/// ekleniyordu, yani ILND aynı anda iki kiloyu biliyordu. Ayarlar ekranı bu
/// güncellemeyi sıradan bir işlem hâline getirdiği için değiştirme
/// (replaceFacts) şart oldu.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  IlndMemoryNotifier memory() => IlndMemoryNotifier(prefs, '', 'u1');

  group('replaceFacts', () {
    test('profil gerçeğini günceller, eskisini bırakmaz', () async {
      final m = memory();
      await m.replaceFacts(
        prefixes: kProfileFactPrefixes,
        facts: const ['Kilo: 70 kg'],
      );
      await m.replaceFacts(
        prefixes: kProfileFactPrefixes,
        facts: const ['Kilo: 71 kg'],
      );

      expect(m.state.facts, const ['Kilo: 71 kg']);
      expect(
        m.state.facts.where((f) => f.contains('70')),
        isEmpty,
        reason: 'eski kilo hafızada kalmamalı',
      );
    });

    test('sohbetten öğrenilen gerçeklere dokunmaz', () async {
      final m = memory();
      await m.addFact('Sabahları koşuyor');
      await m.addFact('Kedisi var');

      await m.replaceFacts(
        prefixes: kProfileFactPrefixes,
        facts: const ['Kilo: 70 kg'],
      );

      expect(m.state.facts, contains('Sabahları koşuyor'));
      expect(m.state.facts, contains('Kedisi var'));
      expect(m.state.facts, contains('Kilo: 70 kg'));
    });

    test('alan silinirse gerçek de silinir', () async {
      final m = memory();
      await m.replaceFacts(
        prefixes: kProfileFactPrefixes,
        facts: const ['Kilo: 70 kg', 'Boy: 170 cm'],
      );
      // Kullanıcı kilo alanını boşalttı: yalnız boy kaldı.
      await m.replaceFacts(
        prefixes: kProfileFactPrefixes,
        facts: const ['Boy: 170 cm'],
      );

      expect(m.state.facts, const ['Boy: 170 cm']);
    });

    test('değişiklik yoksa yazma yapılmaz', () async {
      final m = memory();
      await m.replaceFacts(
        prefixes: kProfileFactPrefixes,
        facts: const ['Kilo: 70 kg'],
      );
      final before = prefs.getString('ilnd_memory_u1');

      await m.replaceFacts(
        prefixes: kProfileFactPrefixes,
        facts: const ['Kilo: 70 kg'],
      );

      expect(prefs.getString('ilnd_memory_u1'), before);
    });
  });

  group('profileFacts', () {
    test('dolu alanları gerçeğe çevirir', () {
      final facts = profileFacts(
        const ProfileData(
          onboardingDone: true,
          age: 28,
          height: 170,
          weight: 62,
          diet: 'vegan',
          allergies: ['kuruyemis'],
          activityLevel: 'orta',
        ),
      );

      expect(facts, contains('Yaş: 28'));
      expect(facts, contains('Boy: 170 cm'));
      expect(facts, contains('Kilo: 62 kg'));
      expect(facts.any((f) => f.startsWith('Beslenme tercihi:')), isTrue);
      expect(facts.any((f) => f.startsWith('Alerjiler:')), isTrue);
      expect(facts.any((f) => f.startsWith('Aktivite seviyesi:')), isTrue);
    });

    test('boş alanlar gerçek üretmez', () {
      final facts = profileFacts(const ProfileData(onboardingDone: true));
      expect(facts, isEmpty);
    });

    test('"diyet yok" bir tercih değildir, gerçek üretmez', () {
      final facts = profileFacts(
        const ProfileData(onboardingDone: true, diet: 'yok'),
      );
      expect(facts, isEmpty);
    });

    test('üretilen her gerçeğin öneki listede tanımlı', () {
      // Önek listesi eksik kalırsa o alan güncellenemez, hafızada takılı
      // kalır. Bu test yeni bir profil gerçeği eklendiğinde uyarır.
      final facts = profileFacts(
        const ProfileData(
          onboardingDone: true,
          age: 28,
          height: 170,
          weight: 62,
          diet: 'vegan',
          allergies: ['sut'],
          activityLevel: 'aktif',
        ),
      );

      for (final fact in facts) {
        expect(
          kProfileFactPrefixes.any(fact.startsWith),
          isTrue,
          reason: '"$fact" için kProfileFactPrefixes içinde önek yok',
        );
      }
    });
  });
}
