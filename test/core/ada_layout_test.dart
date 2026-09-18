import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/widgets/ilnd_surfaces.dart';
import 'package:ilnd_app/core/repositories/checkin_repository.dart';
import 'package:ilnd_app/core/repositories/events_repository.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/core/repositories/journal_repository.dart';
import 'package:ilnd_app/features/adan/adan_repository.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';
import 'package:ilnd_app/features/adan/adan_screen.dart';
import 'package:ilnd_app/features/auth/login_screen.dart';
import 'package:ilnd_app/features/chat/chat_screen.dart';
import 'package:ilnd_app/features/focus/focus_screen.dart';
import 'package:ilnd_app/features/habits/habit_model.dart';
import 'package:ilnd_app/features/habits/habits_provider.dart';
import 'package:ilnd_app/features/home/home_screen.dart';
import 'package:ilnd_app/features/journal/journal_screen.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/onboarding/screens/welcome_screen.dart';
import 'package:ilnd_app/features/profile/data_privacy_screen.dart';
import 'package:ilnd_app/features/profile/notification_prefs_screen.dart';
import 'package:ilnd_app/features/profile/profile_provider.dart';
import 'package:ilnd_app/features/profile/profile_screen.dart';
import 'package:ilnd_app/features/takip/takip_screen.dart';
import 'package:ilnd_app/features/topluluk/topluluk_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/fake_firebase_auth.dart';

/// "Her telefonda bozulmadan çalışsın" (owner, 2026-09-11).
///
/// Ada tasarımı 402 × 874'e (iPhone 16 Pro) göre çizildi. Tasarımın
/// ölçüleri koda birebir girdiğinde en büyük risk sabit yükseklik ve sabit
/// genişliklerin dar ekranda taşması: bu depoda daha önce tam olarak bu
/// yaşandı (ekle sheet'i, Adan yüzeyi, rozet şeridi, okuma kartı).
///
/// Bu test her ekranı iPhone SE'den iPad'e kadar yedi ölçüde çizer ve tek
/// bir şey sorar: bir şey taştı mı? Taşma testte exception olarak düşer.
/// Ekranların içeriğini başka testler doğruluyor; buradaki tek konu
/// yerleşim.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    useFakeFirebaseAuth();
  });

  /// Gerçek cihaz ölçüleri (nokta cinsinden), dar → geniş.
  const sizes = <String, Size>{
    'iPhone SE': Size(320, 568),
    'iPhone SE 3': Size(375, 667),
    'iPhone 14': Size(390, 844),
    'iPhone 16': Size(393, 852),
    'iPhone 16 Pro': Size(402, 874),
    'iPhone 16 Pro Max': Size(430, 932),
    'iPad': Size(768, 1024),
  };

  final habits = [
    Habit(
      id: 'h1',
      userId: 'u1',
      name: 'sabah yürüyüşü',
      targetDaysPerWeek: 7,
      createdAt: DateTime(2026),
    ),
  ];

  Future<void> pumpScreen(WidgetTester tester, Widget screen, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ilndMemoryProvider.overrideWith(
            (ref) => IlndMemoryNotifier(prefs, 'Ela', null),
          ),
          profileStatsProvider.overrideWith(
            (ref) async => const ProfileStats(
              streakDays: 7,
              weeklyJournalCount: 3,
              weeklyFoodCount: 5,
              weeklyActivityByDay: [1, 0, 1, 0, 0, 1, 0],
            ),
          ),
          weeklyCheckinCountProvider.overrideWith((ref) async => 3),
          islandStateProvider.overrideWith(
            (ref) => Stream.value(const IslandState(earned: {'lantern'})),
          ),
          dailyMacrosProvider.overrideWithValue(
            const DailyMacros(
              kalori: 1240,
              protein: 55,
              karbonhidrat: 150,
              yag: 40,
            ),
          ),
          todayFoodEntriesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          habitsProvider.overrideWith((ref) => Stream.value(habits)),
          todayCompletionsProvider.overrideWith(
            (ref) => Stream.value(const <String>{'h1'}),
          ),
          rangeCompletionsProvider.overrideWith(
            (ref, range) => Stream.value(const {}),
          ),
          toggleHabitCompletionProvider.overrideWithValue((_) async {}),
          journalEntriesProvider.overrideWith((ref) => Stream.value(const [])),
          upcomingEventsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    );
    await tester.pump();
    // Entrance kademelenmesi otursun: zamanlayıcı bir karede ateşlenir ama
    // denetleyici sonraki karelerde ilerler, o yüzden tek uzun pump yetmez.
    // pumpAndSettle KULLANILMAZ (nefes halkası sürekli animasyon
    // çalıştırıyor, hiç durulmaz).
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  final screens = <String, Widget Function()>{
    'Karşılama': () => const WelcomeScreen(),
    'Giriş': () => const LoginScreen(),
    'Bugün': () => const HomeScreen(hourOverride: 22),
    'Adan': () => const AdanScreen(),
    'Günlük': () => const JournalScreen(),
    'Takibin': () => const TakipScreen(),
    'Sohbet': () => const ChatScreen(),
    'Topluluk': () => const TopulukScreen(),
    'Sen': () => const ProfileScreen(),
    'Odaklan': () => const FocusScreen(),
    'Veriler ve gizlilik': () => const DataPrivacyScreen(),
    'Bildirim tercihleri': () => const NotificationPrefsScreen(),
  };

  for (final screen in screens.entries) {
    for (final size in sizes.entries) {
      testWidgets('${screen.key} · ${size.key} taşmıyor', (tester) async {
        await pumpScreen(tester, screen.value(), size.value);
        expect(
          tester.takeException(),
          isNull,
          reason:
              '${screen.key}, ${size.key} (${size.value.width.toInt()}×'
              '${size.value.height.toInt()}) ölçüsünde taşıyor',
        );
      });
    }
  }

  testWidgets('ada çerçevesi iki tonunu gerçekten boyar', (tester) async {
    // Çocuksuz ColoredBox, Column'un varsayılan (center) hizasında gevşek
    // genişlik alıp sıfıra düşüyordu: kart ekranda hiç görünmüyordu ve
    // hiçbir taşma testi bunu yakalayamazdı, çünkü sorun boyamada.
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: IslandFrame(p: AppPalette.light, height: 200),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Scaffold'un kendi zemini de bir ColoredBox: arama çerçeveyle sınırlı.
    final bandFinder = find.descendant(
      of: find.byType(IslandFrame),
      matching: find.byType(ColoredBox),
    );
    final bands = tester.widgetList<ColoredBox>(bandFinder);
    final colors = bands.map((b) => b.color).toSet();
    expect(colors.contains(AppPalette.light.sky), isTrue);
    expect(colors.contains(AppPalette.light.sea), isTrue);

    for (final band in bandFinder.evaluate()) {
      final size = tester.getSize(find.byWidget(band.widget));
      expect(
        size.width,
        300,
        reason: 'Tonlar kartın tamamını kaplamalı, sıfır genişlikte olamaz',
      );
      expect(size.height, greaterThan(0));
    }
  });
}
