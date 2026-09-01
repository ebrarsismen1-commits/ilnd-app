import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/profile/profile_provider.dart';
import 'package:ilnd_app/features/profile/profile_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sen ekranının yerleşimi.
///
/// İki sorun vardı ve ikisi de ekranı bozuk gösteriyordu:
///
/// 1. Rozetler dört `Expanded` ile eşit paylaşıyordu; masaüstü web'de her
///    rozet ~470px'lik boş bir kutuya dönüşüyordu (telefon düzeninin
///    gerilmiş hâli, Adan yüzeyindeki hatanın aynı sınıfı).
/// 2. Haftalık grafik boş haftada 96px yer ayırıp içini boş bırakıyordu:
///    bütün çubuklar 4px, üstünde 86px hiçlik.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  final l10n = lookupAppLocalizations(const Locale('tr'));

  ProfileStats stats({List<double>? week}) => ProfileStats(
    streakDays: 3,
    weeklyJournalCount: 2,
    weeklyFoodCount: 4,
    weeklyActivityByDay: week ?? List.filled(7, 0.0),
  );

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    List<double>? week,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStatsProvider.overrideWith((ref) async => stats(week: week)),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  group('rozetler', () {
    testWidgets('geniş ekranda gerilmez', (tester) async {
      await pump(tester, width: 1400);

      final badge = tester.getRect(find.text(l10n.profileBadgeFirstStep));
      // Rozet kutusu metinden geniştir ama 120px tavanını aşmamalı.
      final card = tester.getRect(
        find
            .ancestor(
              of: find.text(l10n.profileBadgeFirstStep),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(
        card.width,
        lessThanOrEqualTo(121),
        reason: '1400px ekranda rozet dev bir kutuya dönüşmemeli',
      );
      expect(badge.width, greaterThan(0));
    });

    testWidgets('dar ekranda dördü de sığar ve taşmaz', (tester) async {
      await pump(tester, width: 320);

      expect(find.text(l10n.profileBadgeFirstStep), findsOneWidget);
      expect(find.text(l10n.profileBadgeSevenDays), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: '320px ekranda rozet satırı taşmamalı',
      );
    });
  });

  group('haftalık özet', () {
    testWidgets('boş haftada grafik yerine cümle çıkar', (tester) async {
      await pump(tester, width: 800, week: List.filled(7, 0.0));

      expect(
        find.text(l10n.profileWeekEmpty),
        findsOneWidget,
        reason: 'boş hafta bozuk bir grafik değil, bir cümle olmalı',
      );
    });

    testWidgets('hareket varsa grafik çizilir', (tester) async {
      await pump(
        tester,
        width: 800,
        week: const [0.0, 0.5, 0.0, 1.0, 0.0, 0.0, 0.25],
      );

      expect(find.text(l10n.profileWeekEmpty), findsNothing);
      // Gün etiketleri grafiğin parçası; grafik çizilmişse duruyorlar.
      expect(find.text('Pt'), findsOneWidget);
      expect(find.text('Pa'), findsOneWidget);
    });
  });
}
