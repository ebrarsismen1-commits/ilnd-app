import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';

/// Şifre sıfırlama ve hesap onayı e-postalarındaki bağlantılar mobilde
/// uygulamaya dönebilsin diye özel URL şeması ÜÇ yerde birden tanımlı
/// olmalı: Dart (redirectTo), AndroidManifest intent-filter'ı ve iOS
/// CFBundleURLSchemes. Biri eksikse link yalnız tarayıcıda açılır; PKCE
/// code verifier uygulamanın deposunda kaldığı için oturum hiç kurulamaz
/// ve akış sessizce ölür (yaşandı: sıfırlama akışı mobilde hiç bitmiyordu).
void main() {
  test('Dart tarafındaki şema/host tutarlı bir redirect üretir', () {
    expect(authDeepLinkRedirect, '$authDeepLinkScheme://$authDeepLinkHost');

    final uri = Uri.parse(authDeepLinkRedirect);
    expect(uri.scheme, authDeepLinkScheme);
    expect(uri.host, authDeepLinkHost);

    // RFC 3986: şema yalnız harf/rakam/'+'/'-'/'.' içerebilir. Android
    // applicationId'si (com.ilnd.ilnd_app) alt çizgi taşıdığı için şema
    // olarak kullanılamaz — yanlışlıkla geri gelmesin.
    expect(
      RegExp(r'^[a-zA-Z][a-zA-Z0-9+\-.]*$').hasMatch(authDeepLinkScheme),
      isTrue,
      reason: 'Geçersiz URL şeması: $authDeepLinkScheme',
    );
  });

  test('AndroidManifest auth callback için BROWSABLE intent-filter içerir', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    // Şemayı taşıyan <intent-filter> bloğunu izole et: scheme/host doğru ama
    // BROWSABLE'ı olmayan bir filtre tarayıcıdan gelen linki hiç almaz.
    final filters = RegExp(
      r'<intent-filter[^>]*>.*?</intent-filter>',
      dotAll: true,
    ).allMatches(manifest).map((m) => m.group(0)!);

    final authFilter = filters.where(
      (f) => f.contains('android:scheme="$authDeepLinkScheme"'),
    );

    expect(
      authFilter,
      isNotEmpty,
      reason:
          'AndroidManifest.xml içinde android:scheme="$authDeepLinkScheme" '
          'taşıyan bir intent-filter yok — e-posta linki uygulamayı açamaz.',
    );

    final f = authFilter.first;
    expect(
      f.contains('android.intent.action.VIEW'),
      isTrue,
      reason: 'Auth intent-filter VIEW action içermeli.',
    );
    expect(
      f.contains('android.intent.category.BROWSABLE'),
      isTrue,
      reason: 'BROWSABLE olmadan tarayıcıdan/e-postadan gelen link ulaşmaz.',
    );
    expect(
      f.contains('android.intent.category.DEFAULT'),
      isTrue,
      reason: 'DEFAULT olmadan implicit intent eşleşmez.',
    );
    expect(
      f.contains('android:host="$authDeepLinkHost"'),
      isTrue,
      reason: 'Auth intent-filter host="$authDeepLinkHost" içermeli.',
    );
  });

  test(
    'iOS Info.plist auth callback şemasını CFBundleURLSchemes ile kaydeder',
    () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(
        plist.contains('CFBundleURLTypes'),
        isTrue,
        reason:
            'Info.plist CFBundleURLTypes içermiyor — iOS özel şemayı tanımaz.',
      );
      expect(
        plist.contains('<string>$authDeepLinkScheme</string>'),
        isTrue,
        reason:
            'CFBundleURLSchemes içinde $authDeepLinkScheme yok — e-posta linki '
            'uygulamayı açamaz.',
      );
    },
  );
}
