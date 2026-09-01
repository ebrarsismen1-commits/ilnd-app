import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/repositories/journal_repository.dart';
import 'package:ilnd_app/features/journal/journal_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Günlük girdisini silme.
///
/// Silme HİÇ yoktu: `JournalRepository` yalnız `stream()` ve `add()`
/// taşıyordu, yani kullanıcı yazdığı bir yazıyı kaldıramıyordu. Firestore
/// kuralı zaten izin veriyordu (`users/{uid}/**` sahibine tam yazma), eksik
/// olan veri katmanı ve arayüzdü.
class _FakeJournalRepo extends JournalRepository {
  _FakeJournalRepo() : super('test-user');

  final deleted = <String>[];

  @override
  Future<void> delete(String entryId) async => deleted.add(entryId);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final l10n = lookupAppLocalizations(const Locale('tr'));

  final entry = JournalEntry(
    id: 'e1',
    body: 'bugün yorgunum ama iyiyim',
    ilndReply: '',
    createdAt: DateTime(2026, 9, 1, 21),
  );

  late _FakeJournalRepo repo;

  Future<void> pump(WidgetTester tester) async {
    repo = _FakeJournalRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalEntriesProvider.overrideWith((ref) => Stream.value([entry])),
          journalRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const JournalScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('uzun basınca onay sorulur, onaylanınca silinir', (tester) async {
    await pump(tester);
    expect(find.text(entry.body), findsOneWidget);

    await tester.longPress(find.text(entry.body));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(l10n.journalDeleteTitle),
      findsOneWidget,
      reason: 'silme geri alınamıyor, onaysız olmamalı',
    );
    expect(repo.deleted, isEmpty, reason: 'onaydan önce silinmemeli');

    await tester.tap(find.text(l10n.deleteAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(repo.deleted, ['e1']);
  });

  testWidgets('vazgeçilince hiçbir şey silinmez', (tester) async {
    await pump(tester);

    await tester.longPress(find.text(entry.body));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(l10n.cancelAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.deleted, isEmpty);
    expect(find.text(entry.body), findsOneWidget);
  });

  testWidgets('kısa dokunuş silme penceresini açmaz', (tester) async {
    // Kart kısa dokunuşa bilerek tepkisiz; yanlışlıkla silme kapısı
    // açılmamalı.
    await pump(tester);

    await tester.tap(find.text(entry.body));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(l10n.journalDeleteTitle), findsNothing);
    expect(repo.deleted, isEmpty);
  });
}
