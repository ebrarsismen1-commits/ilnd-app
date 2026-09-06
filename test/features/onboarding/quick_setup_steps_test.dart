import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/repositories/profile_repository.dart';
import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/onboarding/screens/quick_setup_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kurulum yedi alan grubunu tek sayfada soruyordu; artık dört adım.
///
/// Burada kilitlenen iki şey var. Birincisi zorunluluk sözleşmesi: YALNIZ
/// isim zorunlu, kalan üç adım geçilebilir — bir adımın sessizce zorunlu
/// hale gelmesi, kimsenin bitiremediği bir onboarding demektir. İkincisi
/// ölçüm: her adım kendi olayını atmazsa panelde yine yalnız "bitirenler"
/// görünür ve nerede düşüldüğü bilinemez (ANALITIK_SOZLUGU notu).
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('tr'));

  late List<(String, Map<String, Object?>?)> analytics;

  List<Object?> stepNames() => [
    for (final e in analytics)
      if (e.$1 == 'onboarding_step_completed') e.$2?['step_name'],
  ];

  setUp(() {
    analytics = [];
    AnalyticsService.testSink = (name, params) => analytics.add((name, params));
  });

  tearDown(() => AnalyticsService.testSink = null);

  /// [fresh] false ise disk sıfırlanmaz: uygulamanın kapanıp yeniden
  /// açılması aynı testte taklit edilebilsin diye.
  Future<GoRouter> pumpSetup(
    WidgetTester tester, {
    bool fresh = true,
    Map<String, Object> prefsSeed = const {},
  }) async {
    if (fresh) SharedPreferences.setMockInitialValues(prefsSeed);
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: routeQuickSetup,
      routes: [
        GoRoute(
          path: routeQuickSetup,
          builder: (_, _) => const QuickSetupScreen(),
        ),
        GoRoute(
          path: routeRegister,
          builder: (_, _) => const Scaffold(body: Text('STUB_REGISTER')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ilndMemoryProvider.overrideWith(
            (ref) => IlndMemoryNotifier(prefs, '', null),
          ),
          // Auth'suz test: sunucu yazımları sessizce atlanır.
          profileRepositoryProvider.overrideWithValue(null),
          referralRepositoryProvider.overrideWithValue(null),
        ],
        child: MaterialApp.router(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
  }

  Future<void> enterName(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField).first, name);
    await tester.pumpAndSettle();
  }

  testWidgets('ilk adımda yalnız isim sorulur, boşken devam kapalı', (
    tester,
  ) async {
    await pumpSetup(tester);

    expect(find.text(l10n.quickSetupNameHint), findsOneWidget);
    expect(
      find.text(l10n.quickSetupGoalsTitle),
      findsNothing,
      reason: 'yedi alan birden görünmesin diye bölündü',
    );
    expect(find.text(l10n.quickSetupStepCounter(1, 4)), findsOneWidget);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull, reason: 'isim tek zorunlu alan');
    expect(
      find.text(l10n.quickSetupSkipStep),
      findsNothing,
      reason: 'zorunlu adım geçilebilir gibi durmamalı',
    );

    await enterName(tester, 'ebrar');
    final ready = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(ready.onPressed, isNotNull);
  });

  testWidgets('adımlar sırayla ilerler, geri okuyla dönülür', (tester) async {
    await pumpSetup(tester);
    await enterName(tester, 'ebrar');

    await tapContinue(tester);
    expect(find.text(l10n.quickSetupGoalsTitle), findsOneWidget);
    expect(find.text(l10n.quickSetupStepCounter(2, 4)), findsOneWidget);

    await tapContinue(tester);
    expect(find.text(l10n.quickSetupBodyTitle), findsOneWidget);
    expect(find.text(l10n.quickSetupActivityTitle), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(l10n.quickSetupBack));
    await tester.pumpAndSettle();
    expect(find.text(l10n.quickSetupGoalsTitle), findsOneWidget);
    expect(find.text(l10n.quickSetupBodyTitle), findsNothing);
  });

  testWidgets('opsiyonel adımlar hiçbir şey seçmeden geçilir', (tester) async {
    final router = await pumpSetup(tester);
    await enterName(tester, 'ebrar');
    await tapContinue(tester);

    // Hedefler ve sayılar "şimdilik geç" ile geçilir; son adımda geç yok,
    // orada "hazırım" hem bitirir hem geçer.
    for (var i = 0; i < 2; i++) {
      expect(find.text(l10n.quickSetupSkipStep), findsOneWidget);
      await tester.tap(find.text(l10n.quickSetupSkipStep));
      await tester.pumpAndSettle();
    }
    await tapContinue(tester);

    expect(find.text('STUB_REGISTER'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      routeRegister,
      reason: 'boş bırakılan adımlar kurulumu bitirmeyi engellememeli',
    );
  });

  testWidgets('son adımda düğme "hazırım" olur ve isim kaydedilir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pumpSetup(tester);
    await enterName(tester, 'ebrar');
    await tapContinue(tester); // hedefler
    await tapContinue(tester); // sayılar
    await tapContinue(tester); // beslenme

    expect(find.text(l10n.quickSetupDietTitle), findsOneWidget);
    expect(find.text(l10n.quickSetupFinish), findsOneWidget);
    expect(find.text(l10n.quickSetupContinue), findsNothing);
    expect(
      find.text(l10n.quickSetupSkipStep),
      findsNothing,
      reason: '"hazırım" zaten geçmeyi karşılıyor, ikinci kapı gereksiz',
    );

    await tapContinue(tester);
    expect(find.text('STUB_REGISTER'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('user_name'),
      'ebrar',
      reason: 'adımlara bölünürken kaydetme yolu kopmamalı',
    );
  });

  testWidgets('yarıda bırakılan kurulum kaldığı adımdan devam eder', (
    tester,
  ) async {
    await pumpSetup(tester);
    await enterName(tester, 'ebrar');
    await tapContinue(tester);
    expect(find.text(l10n.quickSetupGoalsTitle), findsOneWidget);

    // Uygulama kapandı, kullanıcı geri döndü: disk aynı, ekran yeniden
    // kuruldu.
    await pumpSetup(tester, fresh: false);

    expect(
      find.text(l10n.quickSetupStepCounter(2, 4)),
      findsOneWidget,
      reason: 'verdiği cevapları yeniden geçmek zorunda kalmamalı',
    );
    expect(find.text(l10n.quickSetupGoalsTitle), findsOneWidget);

    // İsim de duruyor: geri dönünce alan dolu geliyor.
    await tester.tap(find.bySemanticsLabel(l10n.quickSetupBack));
    await tester.pumpAndSettle();
    expect(find.text('ebrar'), findsOneWidget);
  });

  testWidgets('isim kaydedilmemişse kayıtlı adım yok sayılır', (tester) async {
    // Elde böyle bir kayıt olabilir (eski sürüm, yarım yazma): adıma dönmek
    // kullanıcıyı isimsiz halde son adıma düşürür ve "hazırım" hiçbir şey
    // yapmayan bir düğmeye dönerdi.
    await pumpSetup(tester, prefsSeed: const {'quick_setup_step': 2});

    expect(find.text(l10n.quickSetupNameHint), findsOneWidget);
    expect(find.text(l10n.quickSetupStepCounter(1, 4)), findsOneWidget);
  });

  testWidgets('kurulum bitince kayıtlı adım silinir', (tester) async {
    await pumpSetup(tester);
    await enterName(tester, 'ebrar');
    await tapContinue(tester);
    await tapContinue(tester);
    await tapContinue(tester);
    await tapContinue(tester);

    expect(find.text('STUB_REGISTER'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt('quick_setup_step'),
      isNull,
      reason: 'yarım kalmış adım bir sonraki kuruluma sarkmamalı',
    );
  });

  testWidgets('dar viewport 320px: dört adımın hiçbiri taşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSetup(tester);
    await enterName(tester, 'ebrar');
    // Taşma debug'da FlutterError olarak yükselir; her adımda ayrı bakılır
    // çünkü adımların içeriği birbirinden çok farklı (üç sayı alanı yan
    // yana, altı çipli sarmal, ilerleme satırı).
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 3; i++) {
      await tapContinue(tester);
      expect(tester.takeException(), isNull, reason: 'adım ${i + 2} taştı');
    }
  });

  testWidgets('375dp telefonda yaş/boy/kilo alanları alt alta iner', (
    tester,
  ) async {
    // Yan yana üç alanda her birine ~100dp düşüyor ve ipucu kırpılıyordu:
    // ekranda "boy (..." görünüyor, santim mi kilo mu istendiği okunmuyordu.
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSetup(tester);
    await enterName(tester, 'ebrar');
    await tapContinue(tester);
    await tapContinue(tester);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    final first = tester.getRect(fields.at(0));
    final second = tester.getRect(fields.at(1));
    expect(
      second.top,
      greaterThan(first.top),
      reason: 'alanlar alt alta olmalı',
    );
    expect(
      first.width,
      greaterThan(250),
      reason: 'alt alta inen alan tam genişlik alır, ipucu kırpılmaz',
    );
  });

  testWidgets('her adım kendi analitik olayını atar', (tester) async {
    await pumpSetup(tester);
    await enterName(tester, 'ebrar');
    await tapContinue(tester);
    await tapContinue(tester);
    await tapContinue(tester);
    await tapContinue(tester);

    expect(stepNames(), [
      'quick_setup_name',
      'quick_setup_goals',
      'quick_setup_body',
      'quick_setup_food',
    ], reason: 'tek sabit olayla hangi adımda düşüldüğü bilinemiyordu');
  });
}
