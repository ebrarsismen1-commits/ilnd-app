import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/repositories/events_repository.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/topluluk/topluluk_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pump(
    WidgetTester tester,
    Locale locale, {
    List<CommunityEvent> events = const [],
    int count = 12,
    bool going = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Testte gerçek Firebase yok — event katmanı sahte akışlarla beslenir.
          upcomingEventsProvider.overrideWith((ref) => Stream.value(events)),
          myRsvpProvider.overrideWith((ref, id) => Stream.value(going)),
          rsvpCountProvider.overrideWith((ref, id) => Future.value(count)),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TopulukScreen(),
        ),
      ),
    );
    // Sürekli arka plan animasyonu nedeniyle pumpAndSettle kullanmıyoruz.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('no events shows community invitation and city guidance (tr)', (
    tester,
  ) async {
    await pump(tester, const Locale('tr'));
    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.topulukTitle), findsOneWidget);
    expect(find.text(l10n.topulukComingTitle), findsOneWidget);
    expect(find.text(l10n.topulukComingBody), findsOneWidget);
    expect(find.text(l10n.topulukCityTitle), findsOneWidget);
    expect(find.text(l10n.topulukCitySubtitle), findsOneWidget);
    expect(find.text(l10n.topulukInviteCta), findsOneWidget);
    expect(find.text(l10n.topulukUpcomingLabel), findsNothing);
    expect(find.text(l10n.topulukRsvpJoin), findsNothing);
  });

  testWidgets('renders event card with RSVP button and count (tr)', (
    tester,
  ) async {
    final event = CommunityEvent(
      id: 'e1',
      title: 'sabah  yürüyüşü',
      city: 'İstanbul',
      venue: 'Caddebostan sahili',
      startsAt: DateTime(2026, 9, 28, 8),
    );
    await pump(tester, const Locale('tr'), events: [event]);
    final l10n = lookupAppLocalizations(const Locale('tr'));

    expect(find.text(l10n.topulukUpcomingLabel), findsOneWidget);
    expect(find.text('sabah rutini yürüyüşü'), findsOneWidget);
    expect(find.textContaining('Caddebostan'), findsOneWidget);
    expect(find.text(l10n.topulukRsvpJoin), findsOneWidget); // henüz katılmadı
    expect(find.text(l10n.topulukGoingCount(12)), findsOneWidget);
    // Boş-durum daveti listede görünmez.
    expect(find.text(l10n.topulukComingTitle), findsNothing);
  });

  testWidgets('renders fully in English under the en locale', (tester) async {
    await pump(tester, const Locale('en'));
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.topulukTitle), findsOneWidget); // "community."
    expect(find.text(l10n.topulukInviteCta), findsOneWidget);
  });

  // Kontenjan etkinlik başına gelir ve olmayabilir. Kontrol istemcide:
  // Firestore kuralları doküman sayamadığı için kapasite kuralda
  // uygulanamıyor (bkz. docs/decisions.md, 2026-08-31).
  group('kontenjan', () {
    CommunityEvent eventWith({int? capacity}) => CommunityEvent(
      id: 'e1',
      title: 'sabah yürüyüşü',
      city: 'İstanbul',
      venue: 'Caddebostan sahili',
      startsAt: DateTime(2026, 9, 28, 8),
      capacity: capacity,
    );

    final l10n = lookupAppLocalizations(const Locale('tr'));

    testWidgets('kontenjansız etkinlikte katılım hep açık', (tester) async {
      await pump(tester, const Locale('tr'), events: [eventWith()], count: 999);

      expect(find.text(l10n.topulukRsvpJoin), findsOneWidget);
      expect(find.text(l10n.topulukRsvpFull), findsNothing);
      // Kontenjan yoksa sayı tek başına gösterilir.
      expect(find.text(l10n.topulukGoingCount(999)), findsOneWidget);
    });

    testWidgets('kontenjan varken sayı kapasiteyle birlikte okunur', (
      tester,
    ) async {
      await pump(
        tester,
        const Locale('tr'),
        events: [eventWith(capacity: 20)],
        count: 12,
      );

      expect(
        find.text(l10n.topulukGoingCountOfCapacity(12, 20)),
        findsOneWidget,
      );
      expect(find.text(l10n.topulukRsvpJoin), findsOneWidget);
    });

    testWidgets('kontenjan dolunca katılım kapanır', (tester) async {
      await pump(
        tester,
        const Locale('tr'),
        events: [eventWith(capacity: 20)],
        count: 20,
      );

      expect(find.text(l10n.topulukRsvpFull), findsOneWidget);
      expect(
        find.text(l10n.topulukRsvpJoin),
        findsNothing,
        reason: 'dolu etkinlikte katıl butonu gösterilmemeli',
      );

      // Butonun gerçekten pasif olması gerekiyor: metnin değişmesi yetmez.
      final pressable = tester.widget<Pressable>(
        find.ancestor(
          of: find.text(l10n.topulukRsvpFull),
          matching: find.byType(Pressable),
        ),
      );
      expect(pressable.onTap, isNull);
    });

    testWidgets('dolu etkinlikte katılan yine de çıkabilir', (tester) async {
      await pump(
        tester,
        const Locale('tr'),
        events: [eventWith(capacity: 20)],
        count: 20,
        going: true,
      );

      // Kontenjan dolu ama bu kullanıcı zaten içeride: kapı ona kapanmaz.
      expect(find.text(l10n.topulukRsvpGoing), findsOneWidget);
      expect(find.text(l10n.topulukRsvpFull), findsNothing);

      final pressable = tester.widget<Pressable>(
        find.ancestor(
          of: find.text(l10n.topulukRsvpGoing),
          matching: find.byType(Pressable),
        ),
      );
      expect(
        pressable.onTap,
        isNotNull,
        reason: 'dolu etkinlikten çıkış engellenemez',
      );
    });

    testWidgets('kontenjan aşılmışsa da kapalı kalır', (tester) async {
      // Eşzamanlı kayıtlar sınırı aşabilir (istemci kontrolünün bilinen
      // açığı); o durumda arayüz yine de kapalı görünmeli.
      await pump(
        tester,
        const Locale('tr'),
        events: [eventWith(capacity: 20)],
        count: 22,
      );

      expect(find.text(l10n.topulukRsvpFull), findsOneWidget);
    });
  });
}
