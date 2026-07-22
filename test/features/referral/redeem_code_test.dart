import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/features/referral/redeem_code_sheet.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Davet kodu bug'ı: sunucunun döndürdüğü farklı redler (kendi kodun / zaten
/// kullandın / böyle kod yok / bağlanamadık) tek bir "geçersiz kod" mesajına
/// iniyordu; başarısızlıklar birbirinden ayrılamayınca alan "çalışmıyor" gibi
/// görünüyordu. Bu testler her sonucun kendi mesajını gösterdiğini kilitler.
class _FakeReferralRepo extends ReferralRepository {
  _FakeReferralRepo(this._result) : super('uid');
  final RedeemResult _result;

  @override
  Future<RedeemResult> redeemCode(String code) async => _result;
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final l10n = lookupAppLocalizations(const Locale('tr'));

  group('RedeemResult.isTerminal', () {
    test('terminal: success/self/already/invalid — kod temizlenir', () {
      expect(RedeemResult.success.isTerminal, isTrue);
      expect(RedeemResult.selfReferral.isTerminal, isTrue);
      expect(RedeemResult.alreadyRedeemed.isTerminal, isTrue);
      expect(RedeemResult.invalidCode.isTerminal, isTrue);
    });

    test('geçici: notReady/failed — kod korunur (kayıp olmasın)', () {
      expect(RedeemResult.notReady.isTerminal, isFalse);
      expect(RedeemResult.failed.isTerminal, isFalse);
    });
  });

  group('RedeemCodeSheet mesajları', () {
    Future<void> pumpSheet(WidgetTester tester, RedeemResult result) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            referralRepositoryProvider.overrideWithValue(
              _FakeReferralRepo(result),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => const RedeemCodeSheet(),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ABC123');
      await tester.tap(find.text(l10n.redeemCodeConfirm));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('kendi kodu: kendine ait mesaj, generic "geçersiz" DEĞİL', (
      tester,
    ) async {
      await pumpSheet(tester, RedeemResult.selfReferral);
      expect(find.text(l10n.redeemCodeSelfReferral), findsOneWidget);
      expect(find.text(l10n.redeemCodeInvalid), findsNothing);
      // Sheet açık kalır — başarısızlıkta kapanmaz.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('zaten kullanılmış: ayrı mesaj', (tester) async {
      await pumpSheet(tester, RedeemResult.alreadyRedeemed);
      expect(find.text(l10n.redeemCodeAlreadyUsed), findsOneWidget);
    });

    testWidgets('ağ/sunucu hatası: bağlantı mesajı', (tester) async {
      await pumpSheet(tester, RedeemResult.failed);
      expect(find.text(l10n.redeemCodeNetworkError), findsOneWidget);
    });

    testWidgets('başarı: başarı mesajı gösterilir', (tester) async {
      await pumpSheet(tester, RedeemResult.success);
      expect(find.text(l10n.redeemCodeSuccess), findsOneWidget);
    });
  });
}
