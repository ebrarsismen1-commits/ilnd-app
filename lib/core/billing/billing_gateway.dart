import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/billing/revenue_cat_service.dart';

/// Mağaza satın alma yüzeyi.
///
/// Paywall [RevenueCatService]'in statik metotlarını doğrudan çağırıyordu ve
/// bu, satın almanın SONUÇ yollarını test edilemez kılıyordu: testte
/// `Purchases` yapılandırılmadığı için çağrı mağaza kanalında asılı kalıyor,
/// yani "başarılı satın alma premium açar", "iptal premium AÇMAZ", "hata
/// nazik mesaja düşer" gibi para kritik kuralların hiçbiri doğrulanamıyordu.
///
/// Arayüz bilerek dar: yalnız paywall'ın ihtiyaç duyduğu iki işlem. Kimlik
/// (`identify`/`forget`) ve hak okuma (`isPremium`) hâlâ doğrudan servisten
/// geçiyor, çünkü onların test ihtiyacı farklı ve çağrı yerleri başka.
abstract interface class BillingGateway {
  /// Varsayılan offering'in ilk paketini satın alır.
  /// `true` başarı, `false` iptal ya da başarısızlık.
  Future<bool> purchase();

  /// Önceki satın alımları geri yükler.
  /// `true` aktif bir premium hak bulundu.
  Future<bool> restorePurchases();
}

/// Üretim uygulaması: çağrıyı olduğu gibi RevenueCat'e devreder.
class RevenueCatGateway implements BillingGateway {
  const RevenueCatGateway();

  @override
  Future<bool> purchase() => RevenueCatService.purchase();

  @override
  Future<bool> restorePurchases() => RevenueCatService.restorePurchases();
}

final billingGatewayProvider = Provider<BillingGateway>(
  (ref) => const RevenueCatGateway(),
);
