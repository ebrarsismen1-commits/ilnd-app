import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/services/app_config.dart';

void main() {
  String base(String b, String legacy) =>
      AppConfig.functionsBaseFrom(base: b, legacyBridge: legacy);

  test('FUNCTIONS_BASE_URL öncelikli, sonuna / eklenir', () {
    const b = 'https://europe-west1-p.cloudfunctions.net';
    expect(base(b, ''), '$b/');
    expect(base('$b/', 'https://x/mintFirebaseToken'), '$b/');
  });

  test('eski .env: AUTH_BRIDGE_URL tabanından türetilir', () {
    expect(
      base('', 'https://europe-west1-p.cloudfunctions.net/mintFirebaseToken'),
      'https://europe-west1-p.cloudfunctions.net/',
    );
  });

  test('ikisi de yoksa boş: fonksiyonlar yapılandırılmamış', () {
    expect(base('', ''), '');
  });
}
