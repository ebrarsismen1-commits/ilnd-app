import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Güvenlik denetimi M-5: sohbet geçmişi, AI hafızası ve Supabase oturum
/// anahtarı SharedPreferences'ta; Android'in varsayılan yedeği bunları buluta
/// ve cihaz aktarımına taşıyordu.
void main() {
  const base = 'android/app/src/main';
  final manifest = File('$base/AndroidManifest.xml').readAsStringSync();

  test('uygulama yedeği kapalı', () {
    expect(manifest, contains('android:allowBackup="false"'));
  });

  test('yedek ve veri çıkarma kuralları tanımlı ve dosyaları var', () {
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      File('$base/res/xml/data_extraction_rules.xml').existsSync(),
      isTrue,
    );
    expect(File('$base/res/xml/backup_rules.xml').existsSync(), isTrue);
  });

  test('bulut yedeği ve cihaz aktarımı SharedPreferences dahil her alanı '
      'hariç tutar', () {
    final rules = File(
      '$base/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();
    for (final section in ['cloud-backup', 'device-transfer']) {
      final start = rules.indexOf('<$section>');
      final end = rules.indexOf('</$section>');
      expect(start, greaterThanOrEqualTo(0), reason: '$section yok');
      final body = rules.substring(start, end);
      for (final domain in ['root', 'file', 'database', 'sharedpref']) {
        expect(
          body,
          contains('<exclude domain="$domain" />'),
          reason: '$section içinde $domain hariç tutulmalı',
        );
      }
      expect(body, isNot(contains('<include')));
    }
  });
}
