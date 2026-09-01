import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/health/daily_target.dart';

/// Günlük kalori ve makro hedefi.
///
/// Onboarding yaş/boy/kilo/hareket topluyordu ama hiçbir yerde kullanmıyordu.
/// Bu hesap o dört alana karşılık veriyor; sağlık iddiası taşıdığı için
/// sınırları ve güvenlik tabanı kodda, kafada değil.
void main() {
  group('BMR (Mifflin-St Jeor)', () {
    test('erkek ve kadın denklemleri bilinen değeri verir', () {
      // 30 yaş, 180 cm, 80 kg → 10*80 + 6.25*180 - 5*30 = 1775
      const base = 1775.0;
      expect(
        basalMetabolicRate(
          age: 30,
          heightCm: 180,
          weightKg: 80,
          sex: BodySex.erkek,
        ),
        base + 5,
      );
      expect(
        basalMetabolicRate(
          age: 30,
          heightCm: 180,
          weightKg: 80,
          sex: BodySex.kadin,
        ),
        base - 161,
      );
    });

    test('belirtilmemiş cinsiyet iki denklemin ortasında durur', () {
      final erkek = basalMetabolicRate(
        age: 30,
        heightCm: 170,
        weightKg: 65,
        sex: BodySex.erkek,
      );
      final kadin = basalMetabolicRate(
        age: 30,
        heightCm: 170,
        weightKg: 65,
        sex: BodySex.kadin,
      );
      final belirtilmemis = basalMetabolicRate(
        age: 30,
        heightCm: 170,
        weightKg: 65,
        sex: BodySex.belirtilmemis,
      );

      expect(belirtilmemis, lessThan(erkek));
      expect(belirtilmemis, greaterThan(kadin));
      expect(belirtilmemis, (erkek + kadin) / 2);
    });
  });

  group('eksik ya da saçma veri', () {
    test('zorunlu alan eksikse hedef üretilmez', () {
      expect(
        calculateDailyTarget(
          age: null,
          heightCm: 170,
          weightKg: 65,
          activityKey: 'orta',
        ),
        isNull,
        reason: 'eksik veriyle uydurulmuş hedef göstermek yanlış olurdu',
      );
      expect(
        calculateDailyTarget(
          age: 30,
          heightCm: null,
          weightKg: 65,
          activityKey: 'orta',
        ),
        isNull,
      );
      expect(
        calculateDailyTarget(
          age: 30,
          heightCm: 170,
          weightKg: null,
          activityKey: 'orta',
        ),
        isNull,
      );
    });

    test('akla yatkın sınırların dışı reddedilir', () {
      // Yazım hatası (boy 17 cm, kilo 650 kg) hesaba girerse saçma bir
      // sayı üretir ve kullanıcı ona güvenir.
      for (final bad in [
        (age: 5, h: 170, w: 65),
        (age: 130, h: 170, w: 65),
        (age: 30, h: 17, w: 65),
        (age: 30, h: 300, w: 65),
        (age: 30, h: 170, w: 5),
        (age: 30, h: 170, w: 650),
      ]) {
        expect(
          calculateDailyTarget(
            age: bad.age,
            heightCm: bad.h,
            weightKg: bad.w,
            activityKey: 'orta',
          ),
          isNull,
          reason: 'sınır dışı giriş hedef üretmemeli: $bad',
        );
      }
    });

    test('bilinmeyen hareket anahtarı orta seviyeye düşer', () {
      final bilinmeyen = calculateDailyTarget(
        age: 30,
        heightCm: 170,
        weightKg: 65,
        activityKey: 'bilinmeyen_anahtar',
      );
      final orta = calculateDailyTarget(
        age: 30,
        heightCm: 170,
        weightKg: 65,
        activityKey: 'orta',
      );
      expect(bilinmeyen!.kalori, orta!.kalori);
    });
  });

  group('hareket ve hedef', () {
    DailyTarget target({String activity = 'orta', WeightGoal? goal}) =>
        calculateDailyTarget(
          age: 30,
          heightCm: 170,
          weightKg: 65,
          activityKey: activity,
          goal: goal ?? WeightGoal.koru,
        )!;

    test('hareket arttıkça hedef artar', () {
      expect(
        target(activity: 'az_hareketli').kalori,
        lessThan(target(activity: 'orta').kalori),
      );
      expect(
        target(activity: 'orta').kalori,
        lessThan(target(activity: 'aktif').kalori),
      );
    });

    test('kilo vermek açık, almak fazla verir', () {
      final koru = target().kalori;
      expect(target(goal: WeightGoal.ver).kalori, koru - 500);
      expect(target(goal: WeightGoal.al).kalori, koru + 300);
    });
  });

  group('güvenlik tabanı', () {
    test('hesap ne çıkarsa çıksın 1200 kcal altına inilmez', () {
      // Küçük, hafif, hareketsiz bir profilde "kilo ver" açığı hedefi
      // tehlikeli bir sayıya indiriyordu. Sağlık iddiası taşıyan bir üründe
      // o sayı ekrana yazılamaz.
      final t = calculateDailyTarget(
        age: 60,
        heightCm: 150,
        weightKg: 45,
        activityKey: 'az_hareketli',
        sex: BodySex.kadin,
        goal: WeightGoal.ver,
      )!;
      expect(t.kalori, greaterThanOrEqualTo(kMinDailyKcal));
    });
  });

  group('makro dağılımı', () {
    test('protein vücut ağırlığına bağlı, yüzdeye değil', () {
      // Düşük kalorili hedefte yüzdeye bağlı protein eziliyordu.
      final hafif = calculateDailyTarget(
        age: 30,
        heightCm: 160,
        weightKg: 50,
        activityKey: 'orta',
      )!;
      final agir = calculateDailyTarget(
        age: 30,
        heightCm: 190,
        weightKg: 95,
        activityKey: 'orta',
      )!;
      expect(hafif.protein, (50 * 1.6).round());
      expect(agir.protein, (95 * 1.6).round());
    });

    test('makrolar toplam kaloriye yakın toplanır', () {
      final t = calculateDailyTarget(
        age: 30,
        heightCm: 170,
        weightKg: 65,
        activityKey: 'orta',
      )!;
      final fromMacros = t.protein * 4 + t.karbonhidrat * 4 + t.yag * 9;
      // Yuvarlama payı: gram başına en fazla birkaç kcal sapabilir.
      expect((fromMacros - t.kalori).abs(), lessThan(20));
    });

    test('hiçbir makro negatif olamaz', () {
      final t = calculateDailyTarget(
        age: 60,
        heightCm: 150,
        weightKg: 45,
        activityKey: 'az_hareketli',
        sex: BodySex.kadin,
        goal: WeightGoal.ver,
      )!;
      expect(t.protein, greaterThan(0));
      expect(t.yag, greaterThan(0));
      expect(t.karbonhidrat, greaterThanOrEqualTo(0));
    });
  });
}
