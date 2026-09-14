import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/core/services/crash_reporting.dart';

// Güvenlik denetimi L-1 / L-2.
void main() {
  group('scrubForCrashReport', () {
    test('FormatException ayrıştırılamayan kullanıcı/AI metnini taşımaz', () {
      const secret = '{"alerjiler": "gluten", "kilo": 72, "not": "intihar"}';
      final scrubbed = scrubForCrashReport(
        const FormatException('Unexpected character', secret, 3),
      );
      expect(scrubbed.toString(), 'ScrubbedError(FormatException)');
      expect(scrubbed.toString(), isNot(contains('gluten')));
    });

    test('ağ hatası adresi taşımaz', () {
      final scrubbed = scrubForCrashReport(
        http.ClientException(
          'boom',
          Uri.parse('https://x.example/deleteAccount?uid=abc'),
        ),
      );
      expect(scrubbed.toString(), isNot(contains('uid=abc')));
    });

    test('içerik taşımayan hatalar olduğu gibi kalır', () {
      final state = StateError('bad state');
      expect(identical(scrubForCrashReport(state), state), isTrue);
      const service = IlndServiceException('Bağlantı kurulamadı');
      expect(identical(scrubForCrashReport(service), service), isTrue);
    });
  });

  group('silenceDebugPrintInRelease', () {
    late DebugPrintCallback original;
    setUp(() => original = debugPrint);
    tearDown(() => debugPrint = original);

    test('yayında debugPrint hiçbir şey yazmaz', () {
      final printed = <String?>[];
      debugPrint = (m, {wrapWidth}) => printed.add(m);

      silenceDebugPrintInRelease(isRelease: true);
      debugPrint('[FirebaseAuthBridge] mintFirebaseToken 401: {"error":"x"}');

      expect(printed, isEmpty);
    });

    test('debug derlemesinde dokunmaz', () {
      final printed = <String?>[];
      debugPrint = (m, {wrapWidth}) => printed.add(m);

      silenceDebugPrintInRelease(isRelease: false);
      debugPrint('görünür');

      expect(printed, ['görünür']);
    });
  });
}
