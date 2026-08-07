import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/repositories/plans_repository.dart';
import 'package:ilnd_app/features/plans/plan_detail_screen.dart';
import 'package:ilnd_app/features/plans/plan_model.dart';
import 'package:ilnd_app/features/plans/plan_shelf.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlanDay _day(int i) => PlanDay(
  id: 'd$i',
  title: 'gün $i',
  articleId: 'makale-$i',
  note: '$i. günün notu',
);

Plan _plan({
  String id = '7-gun-hareket',
  int days = 7,
  bool premium = false,
  int order = 0,
}) => Plan(
  id: id,
  title: '7 gün hareket',
  description: 'Bir haftada bedeni yeniden hatırlamak.',
  days: [for (var i = 1; i <= days; i++) _day(i)],
  premium: premium,
  order: order,
);

/// Ekranı bağımsız kurar: katalog ve ilerleme sahte, oturum/ağ yok.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required SharedPreferences prefs,
  List<Plan> plans = const [],
  PlanProgress progress = const PlanProgress(),
  String? activePlanId,
  bool premium = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        publishablePlansProvider.overrideWithValue(plans),
        activePlanIdProvider.overrideWith((ref) => Stream.value(activePlanId)),
        planProgressProvider.overrideWith((ref, id) => Stream.value(progress)),
        hasPremiumAccessProvider.overrideWithValue(premium),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final l10n = lookupAppLocalizations(const Locale('tr'));

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Plan rafı', () {
    testWidgets('devam eden plan listenin başına alınır', (tester) async {
      final plans = [
        _plan(id: 'a', order: 0),
        _plan(id: 'b', order: 1),
        _plan(id: 'c', order: 2),
      ];
      await _pump(
        tester,
        Scaffold(
          body: PlanShelf(plans: plans, p: AppPalette.light),
        ),
        prefs: prefs,
        plans: plans,
        activePlanId: 'c',
      );

      // Yarım bırakılan plan aranmamalı: en soldaki kart o olmalı.
      final cards = tester.widgetList<PlanCard>(find.byType(PlanCard)).toList();
      expect(cards.first.plan.id, 'c');
    });

    testWidgets('ilerleme varsa kartta gün sayısı yerine oran yazar', (
      tester,
    ) async {
      final plans = [_plan(id: 'a')];
      await _pump(
        tester,
        Scaffold(
          body: PlanShelf(plans: plans, p: AppPalette.light),
        ),
        prefs: prefs,
        plans: plans,
        progress: const PlanProgress(completedDayIds: {'d1', 'd2'}),
      );
      expect(find.text(l10n.planProgress(2, 7)), findsOneWidget);
      expect(find.text(l10n.planDayCount(7)), findsNothing);
    });
  });

  group('Plan detayı', () {
    // Not: her durum ayrı testte — aynı test içinde ikinci pumpWidget
    // ProviderScope'u yeniden kurmuyor, ilk override'lar ayakta kalıyor.
    testWidgets('hiç başlanmamış planda buton "başla" der', (tester) async {
      final plan = _plan();
      await _pump(
        tester,
        PlanDetailScreen(plan: plan),
        prefs: prefs,
        plans: [plan],
      );
      expect(find.text(l10n.planStart), findsOneWidget);
    });

    testWidgets('devam eden planda buton sıradaki günü söyler', (tester) async {
      final plan = _plan();
      await _pump(
        tester,
        PlanDetailScreen(plan: plan),
        prefs: prefs,
        plans: [plan],
        progress: const PlanProgress(completedDayIds: {'d1', 'd2'}),
      );
      // Sıradaki gün 3 — kullanıcı nereye döneceğini butondan okur.
      expect(find.text(l10n.planContinue(3)), findsOneWidget);
    });

    testWidgets('plan bitince buton değil tamamlandı satırı gösterilir', (
      tester,
    ) async {
      final plan = _plan();
      await _pump(
        tester,
        PlanDetailScreen(plan: plan),
        prefs: prefs,
        plans: [plan],
        progress: PlanProgress(
          completedDayIds: {for (final d in plan.days) d.id},
        ),
      );
      expect(find.text(l10n.planAllDone), findsOneWidget);
      // Bitmiş plan baştan başlatan bir buton göstermez (ADR-0005: "bitti"
      // bir sondur).
      expect(find.text(l10n.planStart), findsNothing);
      expect(find.text(l10n.planContinue(1)), findsNothing);
    });

    testWidgets('premium plan kilitliyken gün satırları kilit ikonu taşır', (
      tester,
    ) async {
      final plan = _plan(premium: true);
      await _pump(
        tester,
        PlanDetailScreen(plan: plan),
        prefs: prefs,
        plans: [plan],
      );
      expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
      expect(find.text(l10n.planPremiumBadge), findsOneWidget);
    });

    testWidgets('premium erişimi olan kullanıcıda kilit kalkar', (
      tester,
    ) async {
      final plan = _plan(premium: true);
      await _pump(
        tester,
        PlanDetailScreen(plan: plan),
        prefs: prefs,
        plans: [plan],
        premium: true,
      );
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    });
  });
}
