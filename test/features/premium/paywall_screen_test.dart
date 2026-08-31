import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/billing/billing_gateway.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/premium/paywall_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paywall, uygulamanın para kazandığı tek ekranı. Mantığı (entitlement,
/// usage_meter, free_limit) ayrıca test edilmiş; burada korunan şey ARAYÜZ:
/// başarısız bir satın alma sessizce premium açmamalı, sheet kaybolmamalı ve
/// kullanıcı ne olduğunu söyleyen bir mesaj görmeli.
///
/// Testte RevenueCat yapılandırılmadığı için `purchase()` ve
/// `restorePurchases()` deterministik olarak `false` döner — yani buradaki
/// akışlar gerçek "satın alma tutmadı" yolunun ta kendisi.

/// Mağaza yerine geçen sahte. `pending*` doluyken çağrı askıda kalır, yani
/// "akış sürerken ekran ne yapıyor" da, "akış bitince ne oluyor" da aynı
/// testten kontrol edilebiliyor.
class _FakeBilling implements BillingGateway {
  int purchaseCalls = 0;
  int restoreCalls = 0;

  Completer<bool>? pendingPurchase;
  Completer<bool>? pendingRestore;

  bool purchaseResult = true;
  bool restoreResult = true;
  Object? purchaseError;
  Object? restoreError;

  @override
  Future<bool> purchase() {
    purchaseCalls++;
    final pending = pendingPurchase;
    if (pending != null) return pending.future;
    if (purchaseError != null) return Future<bool>.error(purchaseError!);
    return Future<bool>.value(purchaseResult);
  }

  @override
  Future<bool> restorePurchases() {
    restoreCalls++;
    final pending = pendingRestore;
    if (pending != null) return pending.future;
    if (restoreError != null) return Future<bool>.error(restoreError!);
    return Future<bool>.value(restoreResult);
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final l10n = lookupAppLocalizations(const Locale('tr'));

  late SharedPreferences prefs;
  late ProviderContainer container;
  late _FakeBilling billing;

  /// Atılan analitik olayları (bkz. AnalyticsService.testSink).
  late List<(String, Map<String, Object?>?)> analytics;

  bool sent(String name) => analytics.any((e) => e.$1 == name);

  Map<String, Object?>? paramsOf(String name) =>
      analytics.firstWhere((e) => e.$1 == name, orElse: () => ('', null)).$2;

  setUp(() {
    billing = _FakeBilling();
    analytics = [];
    AnalyticsService.testSink = (name, params) => analytics.add((name, params));
  });

  tearDown(() => AnalyticsService.testSink = null);

  /// Paywall'ı gerçekte açıldığı gibi açar: modal bottom sheet olarak.
  Future<void> openPaywall(
    WidgetTester tester, {
    String? reason,
    String source = 'test',
  }) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          billingGatewayProvider.overrideWithValue(billing),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => PaywallScreen.show(
                      context,
                      reason: reason,
                      source: source,
                    ),
                    child: const Text('ac'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    // BreathRing sonsuz döner: pumpAndSettle burada asılır.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  bool isPremium() => container.read(isPremiumProvider);

  group('içerik', () {
    testWidgets('teklif eksiksiz gösterilir', (tester) async {
      await openPaywall(tester);

      expect(find.text('ILND+'), findsOneWidget);
      expect(find.text(l10n.paywallSubtitle), findsOneWidget);
      // Dört fayda maddesi satış argümanı; biri düşerse teklif eksilir.
      expect(find.text(l10n.paywallBenefitUnlimitedChatTitle), findsOneWidget);
      expect(find.text(l10n.paywallBenefitLongMemoryTitle), findsOneWidget);
      expect(find.text(l10n.paywallBenefitProactiveTitle), findsOneWidget);
      expect(find.text(l10n.paywallBenefitPersonalPlanTitle), findsOneWidget);
      // Fiyat bloğu ve deneme vaadi.
      expect(find.text(l10n.paywallYearly), findsOneWidget);
      expect(find.text(l10n.paywallFreeTrial), findsOneWidget);
      expect(find.text(l10n.paywallStartFreeTrial), findsOneWidget);
      expect(find.text(l10n.paywallRestore), findsOneWidget);
    });

    testWidgets('bağlam verilince başlıkta gösterilir', (tester) async {
      await openPaywall(tester, reason: 'bu hafta benimle çok konuştun');
      expect(find.text('bu hafta benimle çok konuştun'), findsOneWidget);
    });

    testWidgets('bağlam yokken yerine bir şey uydurulmaz', (tester) async {
      await openPaywall(tester);
      expect(find.text('bu hafta benimle çok konuştun'), findsNothing);
      expect(find.text('ILND+'), findsOneWidget);
    });
  });

  /// Satın alma butonuna basar ve akışın ilk karesini bekler.
  Future<void> tapPurchase(WidgetTester tester) async {
    await tester.ensureVisible(find.text(l10n.paywallStartFreeTrial));
    await tester.pump();
    await tester.tap(find.text(l10n.paywallStartFreeTrial));
    await tester.pump();
  }

  Future<void> tapRestore(WidgetTester tester) async {
    await tester.ensureVisible(find.text(l10n.paywallRestore));
    await tester.pump();
    await tester.tap(find.text(l10n.paywallRestore));
    await tester.pump();
  }

  /// Akışın çözülmesini ve rota geçişini bekler.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
  }

  // Uygulamanın para kazandığı tek yol. Bu grup mağazanın üç cevabını da
  // ayrı ayrı kilitliyor: onay, ret, hata. Üçünün karışması ya sessizce
  // bedava premium ya da ödeme yapmış kullanıcının hakkını görememesi demek.
  group('satın alma sonucu', () {
    testWidgets('mağaza onaylarsa hak açılır ve ekran kapanır', (tester) async {
      billing.purchaseResult = true;
      await openPaywall(tester, source: 'food');

      await tapPurchase(tester);
      await settle(tester);

      expect(isPremium(), isTrue);
      expect(
        prefs.getBool('is_premium'),
        isTrue,
        reason: 'hak diske de yazılmalı, yoksa açılışta kaybolur',
      );
      expect(find.byType(PaywallScreen), findsNothing);
      expect(sent('purchase_completed'), isTrue);
      expect(sent('purchase_failed'), isFalse);
    });

    testWidgets('mağaza reddederse hak AÇILMAZ, sebep söylenir', (
      tester,
    ) async {
      billing.purchaseResult = false;
      await openPaywall(tester, source: 'food');

      await tapPurchase(tester);
      await settle(tester);

      expect(
        isPremium(),
        isFalse,
        reason: 'iptal edilen satın alma premium açmamalı',
      );
      expect(prefs.getBool('is_premium') ?? false, isFalse);
      expect(
        find.byType(PaywallScreen),
        findsOneWidget,
        reason: 'kullanıcı tekrar deneyebilmeli',
      );
      expect(find.text(l10n.paywallPurchaseCancelled), findsOneWidget);
      expect(paramsOf('purchase_failed'), {'reason': 'cancelled'});
    });

    testWidgets('beklenmedik hata nazik mesaja düşer, hak açılmaz', (
      tester,
    ) async {
      billing.purchaseError = StateError('mağaza patladı');
      await openPaywall(tester, source: 'food');

      await tapPurchase(tester);
      await settle(tester);

      expect(isPremium(), isFalse);
      expect(find.text(l10n.paywallPurchaseFailed), findsOneWidget);
      expect(paramsOf('purchase_failed'), {'reason': 'error'});
    });

    testWidgets('akış sürerken buton kilitli, bitince geri gelir', (
      tester,
    ) async {
      final pending = Completer<bool>();
      billing.pendingPurchase = pending;
      await openPaywall(tester, source: 'food');

      await tapPurchase(tester);

      expect(
        find.text(l10n.paywallStartFreeTrial),
        findsNothing,
        reason: 'akış sürerken ikinci dokunuş hedefini bulmamalı',
      );
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(billing.purchaseCalls, 1);

      pending.complete(false);
      await settle(tester);

      expect(
        find.text(l10n.paywallStartFreeTrial),
        findsOneWidget,
        reason: 'başarısız denemeden sonra tekrar denenebilmeli',
      );
      expect(
        billing.purchaseCalls,
        1,
        reason: 'kilit tek çağrıyı garanti etmeli',
      );
    });
  });

  group('geri yükleme sonucu', () {
    testWidgets('aktif abonelik bulunursa hak açılır', (tester) async {
      billing.restoreResult = true;
      await openPaywall(tester, source: 'profile');

      await tapRestore(tester);
      await settle(tester);

      expect(isPremium(), isTrue);
      expect(prefs.getBool('is_premium'), isTrue);
      expect(paramsOf('restore_completed'), {'restored': 1});
    });

    testWidgets('abonelik yoksa hak açılmaz ve söylenir', (tester) async {
      billing.restoreResult = false;
      await openPaywall(tester, source: 'profile');

      await tapRestore(tester);
      await settle(tester);

      expect(isPremium(), isFalse);
      expect(find.text(l10n.paywallNoActiveSubscription), findsOneWidget);
      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(paramsOf('restore_completed'), {'restored': 0});
    });

    testWidgets('geri yükleme hatası nazik mesaja düşer', (tester) async {
      billing.restoreError = StateError('ağ yok');
      await openPaywall(tester, source: 'profile');

      await tapRestore(tester);
      await settle(tester);

      expect(isPremium(), isFalse);
      expect(find.text(l10n.paywallRestoreFailed), findsOneWidget);
      expect(sent('restore_failed'), isTrue);
    });
  });

  group('vazgeçme', () {
    testWidgets('"şimdi değil" sheet i kapatır, hiçbir şey değişmez', (
      tester,
    ) async {
      await openPaywall(tester);

      await tester.ensureVisible(find.text(l10n.paywallNotNow));
      await tester.pump();
      await tester.tap(find.text(l10n.paywallNotNow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(PaywallScreen), findsNothing);
      expect(isPremium(), isFalse);
    });
  });

  // Gelir hunisi ölçümü. Sıra: paywall_viewed -> purchase_started ->
  // purchase_completed. İlk iki adım burada kilitleniyor; sonuç adımları
  // RevenueCat mağaza kanalında asılı kaldığı için doğrulanamıyor.
  group('analitik', () {
    testWidgets('paywall açılışı kaynağıyla birlikte raporlanır', (
      tester,
    ) async {
      await openPaywall(tester, source: 'food');

      expect(sent('paywall_viewed'), isTrue);
      expect(
        paramsOf('paywall_viewed'),
        {'source': 'food'},
        reason: 'hangi duvarın ödemeye götürdüğü ancak kaynakla okunur',
      );
    });

    testWidgets('satın almaya dokunmak akışın başladığını raporlar', (
      tester,
    ) async {
      // Akış bilerek askıda tutuluyor: mağaza henüz cevap vermemişken
      // "tamamlandı" atılmadığını görmek istiyoruz.
      billing.pendingPurchase = Completer<bool>();
      await openPaywall(tester, source: 'profile');
      expect(sent('purchase_started'), isFalse);

      await tester.ensureVisible(find.text(l10n.paywallStartFreeTrial));
      await tester.pump();
      await tester.tap(find.text(l10n.paywallStartFreeTrial));
      await tester.pump();

      expect(sent('purchase_started'), isTrue);
      expect(
        sent('purchase_completed'),
        isFalse,
        reason: 'mağaza onaylamadan tamamlandı raporlanamaz',
      );
      expect(sent('purchase_failed'), isFalse);
    });

    testWidgets('vazgeçmek satın alma olayı üretmez', (tester) async {
      await openPaywall(tester, source: 'chat');

      await tester.ensureVisible(find.text(l10n.paywallNotNow));
      await tester.pump();
      await tester.tap(find.text(l10n.paywallNotNow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(sent('purchase_started'), isFalse);
      expect(sent('purchase_completed'), isFalse);
    });
  });

  // Kural #14'ün sınıfı: sabit boyut varsayan satır dar ekranda taşar.
  // Alt satır ("şimdi değil · satın alımları geri yükle") 320px'te 269px
  // taşıyordu; iki bağlantı Flexible'a alındı.
  for (final width in const [320.0, 375.0, 420.0]) {
    testWidgets('paywall ${width.toInt()}px genişlikte taşmaz', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await openPaywall(tester, reason: 'bu hafta benimle çok konuştun');

      expect(
        tester.takeException(),
        isNull,
        reason: '${width.toInt()}px genişlikte paywall taşıyor',
      );
      expect(find.text(l10n.paywallStartFreeTrial), findsOneWidget);
      expect(find.text(l10n.paywallRestore), findsOneWidget);
    });
  }
}
