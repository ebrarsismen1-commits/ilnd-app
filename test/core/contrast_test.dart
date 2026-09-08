import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/theme/app_colors.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';
import 'package:ilnd_app/features/adan/island_painter.dart';

/// Erişilebilirlik: paletin metin/zemin çiftleri WCAG AA'yı geçmeli.
///
/// Bu test bir denetimden doğdu: açık modda birincil buton (beyaz metin,
/// yeşil zemin) 3.49:1 idi, AA sınırı 4.5. Aynı anda ikincil metin 4.40'ta,
/// su ilerleme çubuğu kendi rayına karşı 1.21'de duruyordu. Koyu palet
/// zaten geçiyordu, yani sorun tek bir modda ve gözle fark edilmiyordu.
///
/// Palet geçmişte iki kez sessizce kaydı (mor dönemi, lavanta dönemi). Renk
/// bir daha değişirse bu test kaymayı yakalar.

/// Yarı saydam rengi zemine bindirir. Koyu palette `surface`/`border`
/// alfalı beyazdır (0x18FFFFFF gibi); alfayı yok sayarak ölçmek beyaz bir
/// yüzey varmış gibi yanlış sonuç verir.
Color _over(Color fg, Color bg) {
  final a = fg.a;
  return Color.from(
    alpha: 1,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

/// WCAG 2.1 göreli parlaklık.
double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  /// Normal boyutlu metin için AA.
  const aa = 4.5;

  /// Anlam taşıyan grafik ve arayüz bileşeni için AA (ikon, çubuk, sınır).
  const aaGraphic = 3.0;

  for (final entry in {
    'açık': AppPalette.light,
    'koyu': AppPalette.dark,
  }.entries) {
    final mode = entry.key;
    final p = entry.value;

    // Zeminler her zaman taban rengin üstünde ölçülür.
    Color bgOf(Color c) => _over(c, p.base);

    group('$mode palet', () {
      test('gövde metni tüm zeminlerde AA', () {
        for (final bg in {
          'base': p.base,
          'surface': bgOf(p.surface),
          'surfaceStrong': bgOf(p.surfaceStrong),
          'accentSoft': bgOf(p.accentSoft),
        }.entries) {
          expect(
            contrast(p.text, bg.value),
            greaterThanOrEqualTo(aa),
            reason: 'text / ${bg.key}',
          );
        }
      });

      test('ikincil metin tüm zeminlerde AA', () {
        for (final bg in {
          'base': p.base,
          'surface': bgOf(p.surface),
          'surfaceStrong': bgOf(p.surfaceStrong),
        }.entries) {
          expect(
            contrast(p.textMuted, bg.value),
            greaterThanOrEqualTo(aa),
            reason: 'textMuted / ${bg.key}, gri üstüne gri en sık kaçaktır',
          );
        }
      });

      test('vurgu renkleri metin olarak AA', () {
        for (final fg in {'accent': p.accent, 'amber': p.amber}.entries) {
          for (final bg in {
            'base': p.base,
            'surface': bgOf(p.surface),
            'surfaceStrong': bgOf(p.surfaceStrong),
          }.entries) {
            expect(
              contrast(fg.value, bg.value),
              greaterThanOrEqualTo(aa),
              reason: '${fg.key} / ${bg.key}',
            );
          }
        }
      });

      test('birincil buton yazısı AA', () {
        expect(
          contrast(p.onAccent, p.accent),
          greaterThanOrEqualTo(aa),
          reason: 'Her ekranın birincil eylemi, kaçarsa her yerde kaçar',
        );
      });

      test('hata rengi metin olarak AA', () {
        expect(contrast(p.danger, p.base), greaterThanOrEqualTo(aa));
        expect(contrast(p.danger, bgOf(p.surface)), greaterThanOrEqualTo(aa));
      });

      test('içgörü kartı zeminleri metni taşıyor', () {
        // Keşfet'in "Bugün senin için" rafı altı yumuşak zemin kullanıyor
        // (AppPalette.insight). Kural #19: yeni renk gözle değil ölçüyle
        // onaylanır. Kartların üstünde hem gövde hem ikincil metin, hem de
        // accent renkli CTA duruyor; üçü de ayrı ayrı ölçülür.
        for (final (i, tint) in p.insight.all.indexed) {
          final bg = bgOf(tint);
          expect(
            contrast(p.text, bg),
            greaterThanOrEqualTo(aa),
            reason: 'text / insight tint #$i',
          );
          expect(
            contrast(p.textMuted, bg),
            greaterThanOrEqualTo(aa),
            reason: 'textMuted / insight tint #$i',
          );
          expect(
            contrast(p.accent, bg),
            greaterThanOrEqualTo(aa),
            reason: 'accent (CTA metni ve işaretler) / insight tint #$i',
          );
        }
      });

      test('içgörü kartının kenarlığı zemininden ayrışır', () {
        // Kartı ayıran tek şey 0.5px hairline; zeminle aynı tona düşerse
        // kartın sınırı hiç görünmez. Anlam taşıyan arayüz sınırı: 3:1
        // değil ama en azından seçilebilir olmalı.
        for (final (i, tint) in p.insight.all.indexed) {
          expect(
            contrast(bgOf(p.border), bgOf(tint)),
            greaterThan(1.05),
            reason: 'border / insight tint #$i',
          );
        }
      });

      test('su çubuğu kendi rayından ayırt edilebilir', () {
        expect(
          contrast(p.water, bgOf(p.border)),
          greaterThanOrEqualTo(aaGraphic),
          reason: 'Dolgu ile ray aynı tonda olursa çubuk hiç okunmaz',
        );
      });

      // Ada illüstrasyonu zemini sessiz günlerde koyulaşıyor. Zemin
      // değişken olduğu için üç kademenin ÜÇÜ de ayrı ölçülür: yalnız
      // berrak hâli ölçmek, kuralın doğduğu hatayı tekrarlamak olurdu
      // (tek modda geçen renk aylarca fark edilmemişti).
      for (final depth in WaterDepth.values) {
        final ground = _over(IslandPainter.groundColor(p, depth), p.base);

        test('ada zemini (${depth.name}) metni taşıyor', () {
          expect(
            contrast(p.text, ground),
            greaterThanOrEqualTo(aa),
            reason: 'İlerleme satırı illüstrasyonun üstünde duruyor',
          );
        });

        test('ada çizgileri (${depth.name}) zeminden ayrışıyor', () {
          // Ay burada yok çünkü `text` ile çiziliyor — üstteki metin
          // testi onu zaten 4.5:1'de tutuyor. `water` ile çizilseydi
          // koyulaşan zeminle 2.99:1'e düşerdi.
          for (final fg in {
            'kıyı (accent)': p.accent,
            'fener (amber)': p.amber,
            'kilitli yer (textMuted)': p.textMuted,
          }.entries) {
            expect(
              contrast(fg.value, ground),
              greaterThanOrEqualTo(aaGraphic),
              reason: '${fg.key} / ada zemini ${depth.name}',
            );
          }
        });

        test('su halkaları (${depth.name}) alfayla birlikte ölçülür', () {
          // Halkalar yarı saydam: alfayı yok sayarak ölçmek yalan sonuç
          // verir (kural #19'un ikinci yarısı). Eşik 3:1 değil, çünkü
          // halkalar ortam dokusu — taşıdıkları bilgi (sessizlik) zaten
          // metinde de var. Yine de görünmek zorundalar: 1.43:1 ile
          // başlamıştı, yani hiç yoktular.
          final ring = _over(
            p.water.withValues(alpha: IslandPainter.seaOpacity(depth)),
            ground,
          );
          expect(
            contrast(ring, ground),
            greaterThanOrEqualTo(1.6),
            reason: 'En açık halka bile zeminden seçilebilmeli',
          );
        });
      }
    });
  }

  test('AppColors açık paletle birebir aynı kalır', () {
    // Sınıf dokümanı bunu şart koşuyor ama hiçbir şey doğrulamıyordu:
    // AppColors const olmak zorunda olduğu için AppPalette'e referans
    // veremiyor, yani ikisi elle senkron tutuluyor.
    const p = AppPalette.light;
    expect(AppColors.cream, p.base);
    expect(AppColors.creamDark, p.surfaceStrong);
    expect(AppColors.sage, p.accent);
    expect(AppColors.amber, p.amber);
    expect(AppColors.charcoal, p.text);
    expect(AppColors.muted, p.textMuted);
    expect(AppColors.white, p.surface);
    expect(AppColors.border, p.border);
  });
}
