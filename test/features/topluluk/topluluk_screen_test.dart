import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/repositories/events_repository.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/features/topluluk/topluluk_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pump(
    WidgetTester tester,
    Locale locale, {
    List<CommunityEvent> events = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Testte gerçek Firebase yok — event katmanı sahte akışlarla beslenir.
          upcomingEventsProvider.overrideWith((ref) => Stream.value(events)),
          myRsvpProvider.overrideWith((ref, id) => Stream.value(false)),
          rsvpCountProvider.overrideWith((ref, id) => Future.value(12)),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TopulukScreen(),
        ),
      ),
    );
    // AnimatedBackground + BreathRing sonsuz animasyon → pumpAndSettle yasak.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('empty state shows invitation with breath ring (tr)', (
    tester,
  ) async {
    await pump(tester, const Locale('tr'));
    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(find.text(l10n.topulukTitle), findsOneWidget);
    expect(find.text(l10n.topulukComingTitle), findsOneWidget);
    expect(find.text(l10n.topulukInviteCta), findsOneWidget);
    expect(find.byType(BreathRing), findsOneWidget);
  });

  testWidgets('renders event card with RSVP button and count (tr)', (
    tester,
  ) async {
    final event = CommunityEvent(
      id: 'e1',
      title: 'sabah rutini yürüyüşü',
      city: 'İstanbul',
      venue: 'Caddebostan sahili',
      startsAt: DateTime(2026, 9, 14, 8),
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
}
