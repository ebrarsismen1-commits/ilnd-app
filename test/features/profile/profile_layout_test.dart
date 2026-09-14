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

/// Sen ekranının yerleşimi (Ada tasarımı 10).
///
/// Ekran 2026-09-11'de sadeleşti: sayı şeridi, rozetler ve haftalık çubuk
/// grafik kalktı; yerine haftanın tek cümlelik özeti ve dört kapı geldi.
/// Eski testler o üç bileşeni koruyordu — bu testler yenisini koruyor:
/// kapılar duruyor mu, ekran dar ve geniş viewport'ta bozulmuyor mu.
///
/// Genişlik testi tarihsel: rozetler dört `Expanded` ile eşit paylaşıyordu
/// ve masaüstü web'de her biri ~470px'lik boş bir kutuya dönüşüyordu. Kart
/// düzeni aynı tuzağa düşebilir, o yüzden iki uçta da ölçülüyor.
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

  const stats = ProfileStats(
    streakDays: 3,
    weeklyJournalCount: 2,
    weeklyFoodCount: 4,
    weeklyActivityByDay: [0, 0, 0, 0, 0, 0, 0],
  );

  Future<void> pump(WidgetTester tester, {required double width}) async {
    await tester.binding.setSurfaceSize(Size(width, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStatsProvider.overrideWith((ref) async => stats),
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

  testWidgets('haftanın özeti gerçek sayıları söyler', (tester) async {
    await pump(tester, width: 390);

    expect(find.text(l10n.profileWeekLabel), findsOneWidget);
    expect(find.text(l10n.profileWeekLine(2, 4)), findsOneWidget);
  });

  testWidgets('yeni kullanıcıya soğuk sıfır duvarı göstermez', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStatsProvider.overrideWith((ref) async => ProfileStats.zero),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text(l10n.profileWeekEmpty), findsOneWidget);
    expect(find.text(l10n.profileWeekLine(0, 0)), findsNothing);
  });

  testWidgets('dört kapı da duruyor', (tester) async {
    await pump(tester, width: 390);

    // Ada, bildirimler ve veriler; ayarların altında çıkış.
    expect(find.text(l10n.adanTitle), findsOneWidget);
    expect(find.text(l10n.profileNotificationsRow), findsOneWidget);
    expect(find.text(l10n.profileDataRow), findsOneWidget);
    expect(find.text(l10n.profileSignOut), findsOneWidget);
  });

  for (final width in const [320.0, 390.0, 1200.0]) {
    testWidgets('${width.toInt()}px genişlikte taşmaz', (tester) async {
      await pump(tester, width: width);
      expect(
        tester.takeException(),
        isNull,
        reason: '${width.toInt()}px genişlikte bir kart taşıyor',
      );
    });
  }
}
