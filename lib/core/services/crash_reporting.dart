import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Crashlytics'e gidecek hata nesnesini kişisel içerikten arındırır.
///
/// Güvenlik denetimi L-2 (2026-09-13): yakalanmayan her hata ham hâliyle
/// kaydediliyordu. `FormatException` mesajı ve `source` alanı ayrıştırılamayan
/// girdinin kendisini taşır: bu uygulamada o girdi çoğu zaman modelin JSON
/// yanıtı ya da kullanıcının yazdığı metin (günlük, alerji, kilo). Ağ
/// hatalarının mesajı da istek adresini taşır. Bu türlerde yalnız tür adı
/// raporlanır; yığın izi (stack) aynen kalır, hata yine bulunabilir.
Object scrubForCrashReport(Object error) {
  if (error is FormatException) return const ScrubbedError('FormatException');
  if (error is http.ClientException) {
    return const ScrubbedError('ClientException');
  }
  return error;
}

/// İçeriği atılmış hata: yalnız türünü taşır.
@immutable
class ScrubbedError implements Exception {
  const ScrubbedError(this.type);

  final String type;

  @override
  String toString() => 'ScrubbedError($type)';
}

/// Yayın derlemesinde `debugPrint`'i susturur.
///
/// Güvenlik denetimi L-1: Flutter `debugPrint`'i yayın derlemesinden
/// çıkarmaz; 37 çağrı logcat'e / cihaz konsoluna yazıyordu (köprü yanıt
/// gövdesi, Supabase hata mesajları dahil). Cihaz loglarını okuyabilen
/// başka bir uygulama ya da bağlı bir bilgisayar bunları görebilir.
void silenceDebugPrintInRelease({required bool isRelease}) {
  if (!isRelease) return;
  debugPrint = (String? message, {int? wrapWidth}) {};
}
