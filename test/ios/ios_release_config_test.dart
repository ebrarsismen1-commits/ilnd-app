import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// iOS yayın yapılandırması: yetkiler (entitlements) ve Info.plist.
///
/// Buradaki her madde, ancak İMZALI bir derlemede ortaya çıkan ve simülatörde
/// ya da Flutter testlerinde asla görünmeyen bir kırılmayı kapatıyor. Hepsi
/// düz XML dosyasında yaşadığı için sessizce silinebilir veya Xcode'da bir
/// ayar değiştirilirken kaybolabilir; bu test onları yerinde tutar.
void main() {
  final entitlementsFile = File('ios/Runner/Runner.entitlements');
  final plistFile = File('ios/Runner/Info.plist');
  final pbxprojFile = File('ios/Runner.xcodeproj/project.pbxproj');
  final mainDart = File('lib/main.dart');

  test('yetki dosyası duruyor ve Runner hedefine bağlı', () {
    expect(entitlementsFile.existsSync(), isTrue);

    // Dosyanın var olması yetmez: derlemeye ancak CODE_SIGN_ENTITLEMENTS ile
    // girer. Üç yapılandırma da bağlanmalı (Debug, Release, Profile) —
    // yalnız Release'e bağlamak, hatayı ancak arşiv alırken gösterirdi.
    final pbxproj = pbxprojFile.readAsStringSync();
    final refs = RegExp(
      r'CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;',
    ).allMatches(pbxproj);
    expect(
      refs.length,
      3,
      reason:
          'Runner hedefinin üç yapılandırması da yetki dosyasını göstermeli',
    );
  });

  test('Apple ile giriş yetkisi var', () {
    final entitlements = entitlementsFile.readAsStringSync();
    expect(
      entitlements.contains('com.apple.developer.applesignin'),
      isTrue,
      reason:
          'Yetki yoksa "Apple ile devam et" imzalı derlemede hata döner; '
          'ayrıca Google ile giriş sunulduğu için App Store kuralı 4.8 '
          'gereği zorunlu',
    );
  });

  test('App Attest yetkisi main.dart\'taki sağlayıcıyla uyumlu', () {
    final entitlements = entitlementsFile.readAsStringSync();
    final main = mainDart.readAsStringSync();

    // Yayın derlemesi App Attest kullanıyorsa yetki ŞART: yoksa App Check
    // token üretilemez ve enforceAppCheck açık olan fonksiyonlar (yemek
    // analizi, davet kodu, hesap silme) isteği reddeder.
    if (main.contains('AppleProvider.appAttest')) {
      expect(
        entitlements.contains(
          'com.apple.developer.devicecheck.appattest-environment',
        ),
        isTrue,
        reason:
            'main.dart App Attest istiyor ama yetki dosyasında karşılığı yok',
      );
      expect(
        entitlements.contains('<string>production</string>'),
        isTrue,
        reason: 'TestFlight ve App Store production ortamında çalışır',
      );
    }
  });

  group('Info.plist', () {
    late String plist;

    setUpAll(() => plist = plistFile.readAsStringSync());

    test('fotoğraf ve kamera izin açıklamaları duruyor', () {
      // image_picker bu iki anahtar olmadan çalışmaz; dahası App Store
      // yükleme sırasında binary'yi reddeder.
      expect(plist.contains('NSCameraUsageDescription'), isTrue);
      expect(plist.contains('NSPhotoLibraryUsageDescription'), isTrue);
    });

    test('ihracat uyumluluğu beyan edilmiş', () {
      expect(
        plist.contains('ITSAppUsesNonExemptEncryption'),
        isTrue,
        reason:
            'Beyan yoksa her TestFlight yüklemesi App Store Connect\'te '
            'elle cevap bekler',
      );
    });

    test('iki dil de pakette beyan edilmiş', () {
      expect(plist.contains('CFBundleLocalizations'), isTrue);
      final block = RegExp(
        r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(plist);
      expect(block, isNotNull);
      expect(block!.group(1), contains('<string>tr</string>'));
      expect(block.group(1), contains('<string>en</string>'));
    });
  });
}
