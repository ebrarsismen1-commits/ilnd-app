import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Emoji yasağı (owner kararı 2026-08-19: "emoji hastalığına son").
///
/// Uygulama emojiyi üç ayrı yerde biriktirmişti ve her biri farklı bir
/// gerekçeyle geldiği için kimse toplamını görmüyordu:
///   1. ikon yerine geçenler (hareket havuzu, hedef listesi, rozetler),
///   2. .arb dizelerinin sonuna eklenen dekoratif kuyruklar (🌿 👋 🎉),
///   3. paylaşım metinleri.
/// Toplamı 59 satırdı; ekranlar arası ton farkının bir sebebi buydu.
///
/// Kural: ikon gerekiyorsa `Icons.*`, sembol gerekiyorsa palet-uyumlu
/// geometrik glif. Mood glifleri (☾ ◍ ◐ ✦ ☁) ve tasarımdaki diğer geometrik
/// işaretler emoji DEĞİLDİR — onlar bu yasağın dışında, çünkü tek renkli
/// tipografik işaretler; renkli piktogramlar değil.
void main() {
  // Astral düzlemdeki piktogram blokları. Geometrik gliflerin yaşadığı
  // U+2600–27BF bilerek kapsam dışı.
  final emoji = RegExp(r'[\u{1F000}-\u{1FAFF}\u{FE0F}]', unicode: true);

  test('lib/ içinde emoji yok', () {
    final offenders = <String>[];

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') || f.path.endsWith('.arb'))
        // Üretilen l10n dosyaları .arb'nin kopyası — kaynağı denetlemek yeter.
        .where((f) => !f.path.contains('app_localizations'));

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (emoji.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1} → ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Emoji kullanımı var. İkon gerekiyorsa Icons.*, sembol gerekiyorsa\n'
          'geometrik glif kullan.\n\n${offenders.take(20).join('\n')}',
    );
  });
}
