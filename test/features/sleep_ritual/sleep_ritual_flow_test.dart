import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DİKKAT: pumpAndSettle YASAK — BreathAnimation/ikon sahnesi sonsuz döngüde
/// animasyon oynatır, settle asla gelmez. Sadece tester.pump(süre) kullanılır.
class _FakeIlndService extends IlndService {
  const _FakeIlndService({this.reply, this.throws = false});
  final String? reply;
  final bool throws;

  @override
  Future<String> respond({
    required IlndMemory memory,
    required String userMessage,
    required AppLocalizations l10n,
    List<IlndTurn> history = const [],
    String? task,
    IlndTier tier = IlndTier.quick,
    String? fallback,
  }) async {
    if (throws) throw const IlndServiceException('offline');
    return reply!;
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppLocalizations l10n;
  setUpAll(() {
    l10n = lookupAppLocalizations(const Locale('tr'));
  });

  Future<void> pumpRitual(
    WidgetTester tester, {
    required IlndService service,
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
          ilndServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SleepRitualScreen(),
        ),
      ),
    );
    // İlk kare + prepare + geçiş animasyonları.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 900));
  }

  // AnimatedSwitcher 320ms: ilk pump geçişi başlatır, ikincisi bitirir,
  // üçüncüsü eski çocuğu ağaçtan düşürür.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('ILND planı: adımlar sırayla, kapanışta bayrak', (tester) async {
    await pumpRitual(
      tester,
      service: const _FakeIlndService(
        reply:
            '{"adimlar":['
            '{"tip":"kontrol","baslik":"odanı yumuşat","maddeler":["ışıkları kıs"]},'
            '{"tip":"yazi","soru":"bugün seni ne yordu?","ipucu":"tek cümle"},'
            '{"tip":"mesaj","metin":"bugün elinden geleni yaptın."}'
            '],"kapanis":"iyi uykular."}',
      ),
    );

    // Adım 1: ILND'nin kişisel kontrol listesi.
    expect(find.text(l10n.sleepRitualStepProgress(1, 4)), findsOneWidget);
    expect(find.text('odanı yumuşat'), findsOneWidget);
    await tester.tap(find.text('ışıkları kıs'));
    await tester.pump();
    await tester.tap(find.text(l10n.sleepRitualContinueButton));
    await settle(tester);

    // Adım 2: kişisel yazı sorusu.
    expect(find.text('bugün seni ne yordu?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'toplantılar');
    await tester.tap(find.text(l10n.sleepRitualContinueButton));
    await settle(tester);

    // Adım 3: ILND mesajı.
    expect(find.text('bugün elinden geleni yaptın.'), findsOneWidget);
    await tester.tap(find.text(l10n.sleepRitualContinueButton));
    await settle(tester);

    // Kapanış: AI'nın kapanış cümlesi + bitir → bayrak.
    expect(find.text('iyi uykular.'), findsOneWidget);
    await tester.tap(find.text(l10n.sleepRitualFinishButton));
    await settle(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('sleep_ritual_done'), isTrue);
  });

  testWidgets('servis hata verirse yedek akış açılır — kullanıcı hata görmez', (
    tester,
  ) async {
    await pumpRitual(tester, service: const _FakeIlndService(throws: true));

    // Yedek planın ilk adımı: hazırlık kontrol listesi.
    expect(find.text(l10n.sleepRitualStepPrepTitle), findsOneWidget);
    expect(find.text(l10n.sleepRitualPrepItemLights), findsOneWidget);
  });

  testWidgets('nefes adımı: süre dolunca devam açılır', (tester) async {
    await pumpRitual(
      tester,
      service: const _FakeIlndService(
        reply: '{"adimlar":[{"tip":"nefes","sure_sn":30}],"kapanis":"x"}',
      ),
    );

    // Geri sayım sürerken devam etkisiz.
    expect(find.text(l10n.sleepRitualStepProgress(1, 2)), findsOneWidget);
    await tester.tap(find.text(l10n.sleepRitualContinueButton));
    await settle(tester);
    expect(find.text(l10n.sleepRitualStepProgress(1, 2)), findsOneWidget);

    // Süre (30 sn, parser alt sınırı) dolunca devam ilerletir.
    await tester.pump(const Duration(seconds: 31));
    await tester.tap(find.text(l10n.sleepRitualContinueButton));
    await settle(tester);
    expect(find.text(l10n.sleepRitualFinishButton), findsOneWidget);
  });
}
