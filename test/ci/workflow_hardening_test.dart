import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Güvenlik denetimi M-12: CI tedarik zinciri.
///   - Actions değişebilen etiketlerle (@v4) çekiliyordu; etiket başka bir
///     commit'e taşınırsa CI o kodu sırlarla birlikte çalıştırır.
///   - GITHUB_TOKEN yetkisi tanımsızdı (depo varsayılanı).
///   - İmza anahtarı sırrı kabuk betiğinin metnine gömülüyordu.
void main() {
  final workflows = Directory('.github/workflows')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
      .toList();

  test('iş akışları bulundu', () {
    expect(workflows, isNotEmpty);
  });

  for (final file in workflows) {
    final name = file.uri.pathSegments.last;
    final lines = file.readAsLinesSync();

    test('$name: her action tam commit SHA\'sına sabitli', () {
      final uses = lines.where((l) => RegExp(r'^\s*-?\s*uses:').hasMatch(l));
      expect(uses, isNotEmpty);
      for (final line in uses) {
        expect(
          RegExp(
            r'uses:\s*[\w.-]+/[\w.-]+(/[\w./-]+)?@[0-9a-f]{40}(\s|$)',
          ).hasMatch(line),
          isTrue,
          reason: 'Sabitlenmemiş action: ${line.trim()}',
        );
      }
    });

    test('$name: GITHUB_TOKEN yetkisi açıkça yalnız okuma', () {
      final text = lines.join('\n');
      expect(
        RegExp(
          r'^permissions:\s*\n\s+contents:\s*read',
          multiLine: true,
        ).hasMatch(text),
        isTrue,
      );
      expect(text, isNot(contains('write-all')));
    });

    test('$name: sırlar yalnız env eşlemesiyle geçer, betiğe gömülmez', () {
      for (final line in lines.where((l) => l.contains(r'${{ secrets.'))) {
        expect(
          RegExp(
            r'^\s+[A-Z][A-Z0-9_]*:\s*\$\{\{\s*secrets\.[A-Z0-9_]+\s*\}\}\s*$',
          ).hasMatch(line),
          isTrue,
          reason: 'Sır env eşlemesi dışında kullanılmış: ${line.trim()}',
        );
      }
    });

    test('$name: global araçlar sürüm sabitli kurulur', () {
      for (final line in lines.where((l) => l.contains('npm install -g'))) {
        expect(
          RegExp(r'npm install -g [\w@/.-]+@\d+\.\d+\.\d+').hasMatch(line),
          isTrue,
          reason: 'Sürümsüz global kurulum: ${line.trim()}',
        );
      }
    });
  }

  test('Dependabot npm, pub ve Actions için tanımlı', () {
    final config = File('.github/dependabot.yml').readAsStringSync();
    for (final ecosystem in ['npm', 'pub', 'github-actions']) {
      expect(config, contains('package-ecosystem: $ecosystem'));
    }
  });
}
