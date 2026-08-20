import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tipografi koruması.
///
/// Tarihçe: 2026-08-11 denetiminde kod tabanında 33 ayrı `fontSize` vardı ve
/// her çağrı yeri kendi sayısını uyduruyordu — "her ekranda farklı yazı tipi
/// varmış gibi" hissinin sebebi buydu. O zaman ölçek 10 role indirilip sert
/// bir testle kilitlenmişti.
///
/// 2026-08-18 tasarım handoff'u ekran başına kendi puntolarını getirdiği için
/// (owner kararı: handoff birebir uygulanacak) o kilit kalktı. Yerine iki
/// daha zayıf ama hâlâ işe yarayan koruma var:
///
/// 1. **Aile kilidi** — lib/ içinde yalnız üç aile kullanılabilir. Dördüncü
///    bir font ya da eski Sora/Inter'e sessiz dönüş CI'da kırılır.
/// 2. **Ölçek kümesi** — puntolar handoff'un belgelenmiş kümesinden gelmeli.
///    Serbest bırakılan şey ölçeğin genişliği, keyfîliği değil: rastgele bir
///    37 hâlâ kırılır.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      // Üretilen l10n dosyaları taranmaz.
      .where((f) => !f.path.contains('app_localizations'))
      .toList();

  test('lib/ yalnız Noto Serif + DM Sans + IBM Plex Mono kullanır', () {
    const allowed = {'notoSerif', 'dmSans', 'ibmPlexMono'};
    final pattern = RegExp(r'GoogleFonts\.([a-zA-Z]+)\(');
    final offenders = <String>[];

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in pattern.allMatches(lines[i])) {
          // `dmSansTextTheme` gibi çağrılar da aynı aileye sayılır.
          final family = m.group(1)!.replaceFirst(RegExp(r'TextTheme$'), '');
          if (!allowed.contains(family)) {
            offenders.add('${file.path}:${i + 1} → $family');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Onaylı üçlü dışında font kullanımı var. Başlık/editoryal an →\n'
          'notoSerif, gövde/etiket → dmSans, sayı → ibmPlexMono.\n\n'
          '${offenders.join('\n')}',
    );
  });

  test('fontSize değerleri handoff ölçeğinden gelir', () {
    // Handoff'un (design_handoff_ilnd_redesign/README.md) belgelediği punto
    // kümesi. Yeni bir boyut gerçekten gerekiyorsa önce buraya eklenir ve
    // gerekçesi commit mesajına yazılır.
    final handoff = <double>{
      8.5, 9, 9.5, 10, 10.5, 11, 11.5, 12, 12.5, 13, 13.5, 14, 14.5, 15, //
      15.5, 16, 16.5, 17, 18, 19, 20, 22, 24, 26, 28, 29, 30, 31, 32, 34, //
      42, 56,
    };
    // Handoff öncesinden kalan iki metrik boyutu (AppTextStyles.sizeMetric*).
    // İlgili ekranlar handoff'a çevrildikçe bu ikisi listeden düşecek.
    final legacy = <double>{40, 44};

    final allowed = {...handoff, ...legacy};
    final pattern = RegExp(r'fontSize:\s*([0-9]+(?:\.[0-9]+)?)');
    final offenders = <String>[];

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in pattern.allMatches(lines[i])) {
          final value = double.parse(m.group(1)!);
          if (!allowed.contains(value)) {
            offenders.add('${file.path}:${i + 1} → $value');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Handoff ölçeği dışında ${offenders.length} punto var.\n'
          '${offenders.take(40).join('\n')}',
    );
  });
}
