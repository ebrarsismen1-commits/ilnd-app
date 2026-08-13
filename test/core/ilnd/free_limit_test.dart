import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';

/// Sunucu iki farklı sebeple 429 döndürür ve ikisinin kullanıcı karşılığı
/// taban tabana zıttır:
///   free-weekly-limit  → PAYWALL  ("yükselt" — para kazandıran an)
///   daily-tier-limit   → "yarın tekrar dene" (kötüye kullanım tavanı)
/// Bu ayrımı yapan tek nokta [isFreeWeeklyLimit]. Yanlış tarafa düşerse ya
/// ödeme anı kaçar ya da kötüye kullanan kullanıcıya paywall gösterilir.
http.Response _r(String body, {int code = 429}) =>
    http.Response.bytes(utf8.encode(body), code);

void main() {
  group('isFreeWeeklyLimit', () {
    test('haftalık kota sebebi paywall sinyalidir', () {
      final res = _r('{"error":"limit","reason":"free-weekly-limit"}');
      expect(isFreeWeeklyLimit(res), isTrue);
    });

    test('günlük tavan paywall DEĞİLDİR', () {
      final res = _r('{"error":"limit","reason":"daily-tier-limit"}');
      expect(
        isFreeWeeklyLimit(res),
        isFalse,
        reason: 'Kötüye kullanım tavanına takılana paywall gösterilmez',
      );
    });

    test('sebep alanı yoksa paywall sayılmaz', () {
      expect(isFreeWeeklyLimit(_r('{"error":"limit"}')), isFalse);
    });

    test('bozuk gövde patlatmaz, false döner', () {
      // Ağ araya girip HTML hata sayfası döndürebilir; burada atılan bir
      // exception kullanıcının mesajını sessizce yutardı.
      expect(isFreeWeeklyLimit(_r('<html>502 Bad Gateway</html>')), isFalse);
      expect(isFreeWeeklyLimit(_r('')), isFalse);
      expect(isFreeWeeklyLimit(_r('null')), isFalse);
      expect(isFreeWeeklyLimit(_r('[1,2,3]')), isFalse);
    });

    test('Türkçe karakterli gövde UTF-8 olarak çözülür', () {
      // bodyBytes + utf8.decode şart: `response.body` latin-1 varsayar ve
      // Türkçe içeren bir gövdede JSON çözümlemesi bozulabilir.
      final res = _r('{"reason":"free-weekly-limit","detail":"kota doldu ç"}');
      expect(isFreeWeeklyLimit(res), isTrue);
    });
  });
}
