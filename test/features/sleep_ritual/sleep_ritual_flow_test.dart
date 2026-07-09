import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DİKKAT: pumpAndSettle YASAK — BreathAnimation sonsuz döngüde animasyon
/// oynatır, settle asla gelmez. Sadece tester.pump(süre) kullanılır.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppLocalizations l10n;
  setUpAll(() {
    l10n = lookupAppLocalizations(const Locale('tr'));
  });

  Future<void> pumpRitual(
    WidgetTester tester, {
    Duration breathDuration = const Duration(seconds: 112),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ilndMemoryProvider.overrideWith(
            (ref) => IlndMemoryNotifier(prefs, '', null),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SleepRitualScreen(breathDuration: breathDuration),
        ),
      ),
    );
    // Entrance animasyonları otursun.
    await tester.pump(const Duration(milliseconds: 900));
  }

  // AnimatedSwitcher 320ms: ilk pump geçişi başlatır (tap'in state değişimi
  // o karede işlenir, animasyon t=0'dan kurulur), ikincisi bitirir, üçüncüsü
  // eski çocuğu ağaçtan düşürür. pumpAndSettle kullanılamadığı için elle.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('seçim → adımlar → kapanış → bayrak (nefessiz akış)', (
    tester,
  ) async {
    await pumpRitual(tester);

    // Seçim ekranı açık, başla henüz bir şey yapmıyor (seçim yok).
    expect(find.text(l10n.sleepRitualPickerHeading), findsOneWidget);
    await tester.tap(find.text(l10n.sleepRitualStartButton));
    await settle(tester);
    expect(find.text(l10n.sleepRitualPickerHeading), findsOneWidget);

    // Hazırlık + güzel an seç, başla.
    await tester.tap(find.text(l10n.sleepRitualStepPrepTitle));
    await tester.tap(find.text(l10n.sleepRitualStepGratitudeTitle));
    await tester.pump();
    await tester.tap(find.text(l10n.sleepRitualStartButton));
    await settle(tester);

    // Adım 1: hazırlık — ilerleme 1 / 3, madde tik'lenebilir.
    expect(find.text(l10n.sleepRitualStepProgress(1, 3)), findsOneWidget);
    await tester.tap(find.text(l10n.sleepRitualPrepItemLights));
    await tester.pump();
    await tester.tap(find.text(l10n.sleepRitualContinueButton));
    await settle(tester);

    // Adım 2: güzel an — yaz ve devam et.
    expect(find.text(l10n.sleepRitualGratitudePrompt), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'küçük bir kahve');
    await tester.tap(find.text(l10n.sleepRitualContinueButton));
    await settle(tester);

    // Kapanış: iyi geceler butonu görünür, basınca ekran kapanır.
    expect(find.text(l10n.sleepRitualFinishButton), findsOneWidget);
    await tester.tap(find.text(l10n.sleepRitualFinishButton));
    await settle(tester);

    // Bayrak yazıldı.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('sleep_ritual_done'), isTrue);
  });

  testWidgets('nefes adımı: süre dolunca devam açılır', (tester) async {
    await pumpRitual(tester, breathDuration: const Duration(seconds: 2));

    await tester.tap(find.text(l10n.sleepRitualStepBreathTitle));
    await tester.pump();
    await tester.tap(find.text(l10n.sleepRitualStartButton));
    await settle(tester);

    // Nefes adımında geri sayım sürerken devam etkisiz: basmak ilerletmez.
    expect(find.text(l10n.sleepRitualStepProgress(1, 2)), findsOneWidget);
    await tester.tap(find.text(l10n.sleepRitualContinueButton));
    await settle(tester);
    expect(find.text(l10n.sleepRitualStepProgress(1, 2)), findsOneWidget);

    // Süre (2 sn) dolsun → devam artık ilerletir (kapanışa geçer).
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text(l10n.sleepRitualContinueButton));
    await settle(tester);
    expect(find.text(l10n.sleepRitualFinishButton), findsOneWidget);
  });
}
