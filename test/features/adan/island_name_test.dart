import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/adan/island_name_dialog.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/features/adan/adan_screen.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';
import 'package:ilnd_app/features/adan/adan_repository.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/features/adan/island_name_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

class MemoryNameStore implements IslandNameStore {
  final values = <String, String>{};
  final changes = StreamController<void>.broadcast();
  @override
  Stream<String?> watch(String uid) async* {
    yield values[uid];
    await for (final _ in changes.stream) {
      yield values[uid];
    }
  }

  @override
  Future<void> save(String uid, String name) async {
    values[uid] = name;
    changes.add(null);
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  test(
    'name accepts Turkish/emoji, normalizes whitespace, rejects invalid input',
    () {
      expect(normalizeIslandName('  Sakin   Koy  '), 'Sakin Koy');
      expect(isValidIslandName('Işığın adası 🌿'), isTrue);
      expect(isValidIslandName(' '), isFalse);
      expect(isValidIslandName('a' * 33), isFalse);
      expect(isValidIslandName('a\u0000b'), isFalse);
    },
  );

  test(
    'name persists across containers and never follows another account',
    () async {
      final store = MemoryNameStore();
      final account = StateProvider<String?>((ref) => 'alice');
      ProviderContainer container() => ProviderContainer(
        overrides: [
          islandNameStoreProvider.overrideWithValue(store),
          islandNameAccountProvider.overrideWith((ref) => ref.watch(account)),
        ],
      );
      final first = container();
      final subscription = first.listen(islandNameProvider, (_, _) {});
      final oldSave = first.read(saveIslandNameProvider);
      await oldSave('  Sakin   Koy ');
      await Future<void>.delayed(Duration.zero);
      expect(first.read(islandNameProvider).valueOrNull, 'Sakin Koy');
      first.read(account.notifier).state = 'bob';
      expect(first.read(islandNameProvider).valueOrNull, isNull);
      await expectLater(oldSave('wrong account'), throwsStateError);
      expect(store.values['bob'], isNull);
      subscription.close();
      first.dispose();
      final second = container();
      final secondSubscription = second.listen(islandNameProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(second.read(islandNameProvider).valueOrNull, 'Sakin Koy');
      secondSubscription.close();
      second.dispose();
      await store.changes.close();
    },
  );

  testWidgets('island screen opens editor and reflects saved account name', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = MemoryNameStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ilndMemoryProvider.overrideWith(
            (_) => IlndMemoryNotifier(prefs, '', null),
          ),
          islandNameAccountProvider.overrideWithValue('alice'),
          islandNameStoreProvider.overrideWithValue(store),
          islandStateProvider.overrideWith(
            (_) => Stream.value(const IslandState()),
          ),
          syncIslandProvider.overrideWithValue(() async {}),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdanScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(const Locale('tr'));
    await tester.scrollUntilVisible(find.text(l.adanNameTitle), 200);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(l.adanNameTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.adanNameTitle));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Sakin Koy');
    await tester.tap(find.text(l.preferencesSave));
    await tester.pumpAndSettle();
    expect(find.byType(IslandNameDialog), findsNothing);
    expect(find.text('Sakin Koy'), findsOneWidget);
    expect(find.text(l.adanNameEdit), findsOneWidget);
    expect(store.values['alice'], 'Sakin Koy');
    await tester.pumpWidget(const SizedBox());
    await store.changes.close();
  });

  Future<void> open(
    WidgetTester tester,
    Future<void> Function(String) save, {
    String? initialName,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    IslandNameDialog(initialName: initialName, save: save),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'rename waits for save, blocks duplicate submissions and closes on success',
    (tester) async {
      final gate = Completer<void>();
      final saved = <String>[];
      await open(tester, (name) {
        saved.add(name);
        return gate.future;
      }, initialName: 'Eski isim');
      expect(find.text('Eski isim'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '  Yeni Koy ');
      final l = lookupAppLocalizations(const Locale('tr'));
      await tester.tap(find.text(l.preferencesSave));
      await tester.pump();
      expect(saved, ['Yeni Koy']);
      expect(find.byType(IslandNameDialog), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        isFalse,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(IslandNameDialog), findsNothing);
    },
  );

  testWidgets(
    'empty names do not save; failed save retains input and permits retry',
    (tester) async {
      var calls = 0;
      await open(tester, (_) async {
        calls++;
        if (calls == 1) throw StateError('private error');
      });
      final l = lookupAppLocalizations(const Locale('tr'));
      await tester.tap(find.text(l.preferencesSave));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text(l.adanNameInvalid), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Kıyı');
      await tester.tap(find.text(l.preferencesSave));
      await tester.pumpAndSettle();
      expect(find.text(l.preferencesSaveFailed), findsOneWidget);
      expect(find.text('private error'), findsNothing);
      expect(find.text('Kıyı'), findsOneWidget);
      await tester.tap(find.text(l.preferencesSave));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(IslandNameDialog), findsNothing);
    },
  );

  testWidgets('cancel does not save', (tester) async {
    var calls = 0;
    await open(tester, (_) async {
      calls++;
    });
    await tester.enterText(find.byType(TextFormField), 'Koy');
    await tester.tap(
      find.text(lookupAppLocalizations(const Locale('tr')).cancelAction),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
  });
}
