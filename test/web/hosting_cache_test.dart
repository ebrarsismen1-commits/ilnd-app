import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Flutter web'de hiçbir çıktı dosyasının adında içerik özeti (hash) YOK:
/// `main.dart.js` da, `assets/fonts/MaterialIcons-Regular.otf` da her
/// derlemede aynı yolda gelir. Uzun ömürlü önbellek bu yüzden tehlikeli,
/// ve iki kez ısırdı:
///
///   2026-08-14: yazı tipi değişikliği "uygulanmamış" göründü.
///   2026-09-02: yeni eklenen sohbetler ikonu kullanıcıda GÖRÜNMEZ çıktı.
///     Release derlemesi ikon fontunu yalnız o an kullanılan ikonlara göre
///     buduyor; tarayıcıdaki bir haftalık eski font yeni glifi içermiyordu.
///     Renk sorunu gibi görünen şey aslında eksik bir glifti.
///
/// Kural: build/web altındaki hiçbir şey doğrulanmadan önbellekten
/// servis edilmez. `no-cache, must-revalidate` bedava değil ama ucuz:
/// tarayıcı sorar, değişmediyse 304 alır, indirme olmaz.
void main() {
  test('hosting başlıkları hiçbir yolu doğrulamasız önbelleğe almaz', () {
    final config =
        jsonDecode(File('firebase.json').readAsStringSync())
            as Map<String, dynamic>;
    final hosting = config['hosting'] as Map<String, dynamic>;
    final headers = (hosting['headers'] as List).cast<Map<String, dynamic>>();

    expect(
      headers,
      isNotEmpty,
      reason:
          'Cache-Control başlıkları silinirse Hosting varsayılanı '
          '(1 saat) geri gelir ve deploy sonrası eski sürüm görünür.',
    );

    for (final rule in headers) {
      final source = rule['source'] as String;
      for (final header
          in (rule['headers'] as List).cast<Map<String, dynamic>>()) {
        if ((header['key'] as String).toLowerCase() != 'cache-control') {
          continue;
        }
        final value = (header['value'] as String).toLowerCase();

        // max-age > 0 ancak yolun adında içerik özeti varsa güvenli.
        // Flutter web'de böyle bir yol yok.
        final maxAge = RegExp(r'max-age=(\d+)').firstMatch(value);
        final seconds = maxAge == null ? 0 : int.parse(maxAge.group(1)!);

        expect(
          seconds == 0 || value.contains('must-revalidate'),
          isTrue,
          reason:
              '$source için "$value": Flutter web dosyalarının adında hash '
              'yok, doğrulamasız uzun önbellek kullanıcıyı eski sürümde '
              'bırakır (ikon fontu dahil).',
        );
      }
    }
  });
}
