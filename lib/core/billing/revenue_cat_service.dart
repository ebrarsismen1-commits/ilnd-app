import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// ─── RevenueCat entitlement & offering identifiers ───────────────────────────
// These must match what you create in the RevenueCat dashboard.
const _kEntitlement = 'premium';
const _kOffering = 'default';

class RevenueCatService {
  RevenueCatService._();

  /// Call once in main(), after Supabase.initialize().
  /// apiKey: set via --dart-define-from-file=.env (REVENUECAT_API_KEY)
  static Future<void> initialize(String apiKey) async {
    if (apiKey.isEmpty) {
      debugPrint('[RevenueCat] API key not set — skipping initialization.');
      return;
    }
    await Purchases.setLogLevel(kReleaseMode ? LogLevel.error : LogLevel.debug);
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  /// Aboneliği ILND hesabına bağlar (RevenueCat app_user_id = Firebase uid).
  ///
  /// İki nedenle şart: (1) kullanıcı telefonda aldığı aboneliği web'de de
  /// görsün — anonim id'de abonelik cihazda kalır; (2) sunucu
  /// (functions/index.js → hasRevenueCatPremium) hesabın abone olup
  /// olmadığını uid ile sorabilsin, aksi halde gerçek aboneler ücretsiz
  /// katman kotasına takılır.
  static Future<void> identify(String uid) async {
    if (uid.isEmpty) return;
    try {
      await Purchases.logIn(uid);
    } catch (e) {
      // Yapılandırılmamış (dev) veya desteklenmeyen platform — akışı kırma.
      debugPrint('[RevenueCat] identify error: $e');
    }
  }

  /// Çıkışta anonim kimliğe döner; sonraki kullanıcı öncekinin hakkını
  /// görmesin.
  static Future<void> forget() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('[RevenueCat] forget error: $e');
    }
  }

  /// Returns true if the current user has an active premium entitlement.
  static Future<bool> isPremium() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(_kEntitlement);
    } catch (e) {
      debugPrint('[RevenueCat] isPremium error: $e');
      return false;
    }
  }

  /// Purchases the first available package in the default offering.
  /// Returns true on success, false if cancelled or failed.
  static Future<bool> purchase() async {
    try {
      final offerings = await Purchases.getOfferings();
      final pkg = offerings
          .getOffering(_kOffering)
          ?.availablePackages
          .firstOrNull;
      if (pkg == null) {
        debugPrint('[RevenueCat] No packages found in offering "$_kOffering".');
        return false;
      }
      await Purchases.purchasePackage(pkg);
      return true;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) return false;
      debugPrint('[RevenueCat] purchase error: $e');
      return false;
    } catch (e) {
      debugPrint('[RevenueCat] purchase unknown error: $e');
      return false;
    }
  }

  /// Restores previous purchases and returns true if premium is now active.
  static Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(_kEntitlement);
    } catch (e) {
      debugPrint('[RevenueCat] restore error: $e');
      return false;
    }
  }
}
