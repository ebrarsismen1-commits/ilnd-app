import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/billing/usage_meter.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/features/ekle/yemek_ekle_screen.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yemek eklemenin tek yolu fotoğraftı: karanlık bir restoranda ya da öğün
/// çoktan bitmişken kayıt hiç yapılamıyordu. Elle ekleme o kapıyı açar,
/// malzeme düzenleme de AI'nın yanlış gördüğünü düzeltir. İkisi de sonuç
/// ekranını paylaşır; bu test o paylaşımın kırılmadığını kilitler.
class _FakeIlndService extends IlndService {
  const _FakeIlndService();

  @override
  Future<String> respond({
    required IlndMemory memory,
    required String userMessage,
    required AppLocalizations l10n,
    List<IlndTurn> history = const [],
    String? task,
    IlndTier tier = IlndTier.quick,
    String? fallback,
    UsageKind? meterAs,
  }) async => 'güzel seçim';
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final l10n = lookupAppLocalizations(const Locale('tr'));

  Future<void> pumpScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          hasPremiumAccessProvider.overrideWithValue(true),
          ilndMemoryProvider.overrideWith(
            (ref) => IlndMemoryNotifier(prefs, '', null),
          ),
          ilndServiceProvider.overrideWithValue(const _FakeIlndService()),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: YemekEkleScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Küçük test ekranında düğmeler kolayca katlanmanın altında kalıyor;
  /// dokunmadan önce görünür alana getir.
  Future<void> tapText(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> openManualResult(WidgetTester tester) async {
    await tapText(tester, l10n.yemekEkleManualButton);

    await tester.enterText(
      find.byType(TextField).at(0),
      'ev yapımı mercimek çorbası',
    );
    await tester.enterText(find.byType(TextField).at(1), '240');
    await tapText(tester, l10n.yemekEkleManualContinue);
  }

  testWidgets('fotoğrafsız yol: elle ekleme formu açılır ve doğrular', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text(l10n.yemekEkleManualButton), findsOneWidget);

    await tapText(tester, l10n.yemekEkleManualButton);
    expect(find.text(l10n.yemekEkleManualTitle), findsOneWidget);

    // Boş ad: kayıt başlamaz.
    await tapText(tester, l10n.yemekEkleManualContinue);
    expect(find.text(l10n.yemekEkleManualNameError), findsOneWidget);

    // Ad var, kalori yok: yine başlamaz.
    await tester.enterText(find.byType(TextField).at(0), 'mercimek çorbası');
    await tapText(tester, l10n.yemekEkleManualContinue);
    expect(find.text(l10n.yemekEkleManualCalorieError), findsOneWidget);
  });

  testWidgets('elle eklenen öğün sonuç ekranına fotoğrafsız düşer', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openManualResult(tester);

    expect(find.text('ev yapımı mercimek çorbası'), findsOneWidget);
    expect(find.text('240'), findsOneWidget);
    expect(find.text(l10n.yemekEkleSaveButton), findsOneWidget);
    expect(
      find.byType(Image),
      findsNothing,
      reason: 'Elle eklemede fotoğraf yok, sonuç ekranı onsuz kurulmalı',
    );
  });

  testWidgets('malzeme eklenip çıkarılır, yeniden hesaplama teklif edilir', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openManualResult(tester);

    // Başlangıçta liste boş: hesaplanacak bir şey değişmedi.
    expect(find.text(l10n.yemekEkleRecalculate), findsNothing);

    final field = find.byType(TextField).last;
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'kırmızı mercimek');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('kırmızı mercimek'), findsOneWidget);
    expect(
      find.text(l10n.yemekEkleRecalculate),
      findsOneWidget,
      reason: 'Liste son hesaplamadan ayrıldı, makrolar artık onu anlatmıyor',
    );

    // Çıkarınca liste yine boşalır ve teklif geri çekilir.
    await tester.ensureVisible(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('kırmızı mercimek'), findsNothing);
    expect(find.text(l10n.yemekEkleRecalculate), findsNothing);
  });
}
