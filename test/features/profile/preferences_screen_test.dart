import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/profile/preferences_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Onboarding'de verilen bilgilerin sonradan düzenlenmesi.
///
/// Bu ekran yoktu: kullanıcı kilosunu yanlış girdiyse ya da vegan olduysa
/// değiştirmenin yolu yoktu. Alerji listesi tarif önerisini beslediği için
/// düzenlenebilir olması bir güvenlik meselesi.
///
/// Kaydetme iki yere birden yazar: cihaz-yerel depo ve ILND'nin "bilinen
/// gerçekler" hafızası. Testte Supabase oturumu olmadığı için sunucu yazımı
/// atlanır, hafıza yazımı yine de olmalı.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    // AuthNotifier kurucusunda Supabase istemcisini okuyor; ağ çağrısı yok.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  final l10n = lookupAppLocalizations(const Locale('tr'));

  late SharedPreferences prefs;
  late IlndMemoryNotifier memory;

  Future<void> pump(
    WidgetTester tester, {
    Map<String, Object> initial = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initial);
    prefs = await SharedPreferences.getInstance();
    memory = IlndMemoryNotifier(prefs, '', 'u1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ilndMemoryProvider.overrideWith((ref) => memory),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PreferencesScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text(l10n.preferencesSave));
    await tester.pump();
    await tester.tap(find.text(l10n.preferencesSave));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('mevcut bilgiler alanlara yüklenir', (tester) async {
    await pump(
      tester,
      initial: const {
        'user_name': 'Ela',
        'onboarding_age': 28,
        'onboarding_height': 170,
        'onboarding_weight': 62,
      },
    );

    expect(find.widgetWithText(TextField, 'Ela'), findsOneWidget);
    expect(find.widgetWithText(TextField, '28'), findsOneWidget);
    expect(find.widgetWithText(TextField, '170'), findsOneWidget);
    expect(find.widgetWithText(TextField, '62'), findsOneWidget);
  });

  testWidgets('kilo güncellenince hem depoya hem hafızaya yazılır', (
    tester,
  ) async {
    await pump(tester, initial: const {'onboarding_weight': 62});

    final weightField = find.widgetWithText(TextField, '62');
    await tester.enterText(weightField, '58');
    await tester.pump();
    await save(tester);

    expect(prefs.getInt('onboarding_weight'), 58);
    expect(
      memory.state.facts,
      contains('Kilo: 58 kg'),
      reason: 'ILND güncel kiloyu bilmeli',
    );
    expect(
      memory.state.facts.any((f) => f.contains('62')),
      isFalse,
      reason: 'eski kilo hafızada kalmamalı',
    );
  });

  testWidgets('sayı alanı boşaltılınca bilgi silinir', (tester) async {
    await pump(tester, initial: const {'onboarding_weight': 62});

    await tester.enterText(find.widgetWithText(TextField, '62'), '');
    await tester.pump();
    await save(tester);

    expect(
      prefs.getInt('onboarding_weight'),
      isNull,
      reason: 'boş alan "bilinmiyor" demek, sıfır değil',
    );
    expect(memory.state.facts.any((f) => f.startsWith('Kilo:')), isFalse);
  });

  testWidgets('alerji eklemek listeyi ve hafızayı günceller', (tester) async {
    await pump(tester);

    await tester.ensureVisible(find.text(l10n.quickSetupAllergyEgg));
    await tester.pump();
    await tester.tap(find.text(l10n.quickSetupAllergyEgg));
    await tester.pump();
    await save(tester);

    expect(prefs.getStringList('onboarding_allergies'), contains('yumurta'));
    expect(
      memory.state.facts.any((f) => f.startsWith('Alerjiler:')),
      isTrue,
      reason: 'alerji tarif önerisini besliyor, ILND bilmeli',
    );
  });

  testWidgets('hedef seçimi kaydedilir (bugünün okumasını besler)', (
    tester,
  ) async {
    await pump(tester);

    await tester.ensureVisible(find.text(l10n.quickSetupGoalMovement));
    await tester.pump();
    await tester.tap(find.text(l10n.quickSetupGoalMovement));
    await tester.pump();
    await save(tester);

    expect(
      prefs.getStringList('onboarding_goals'),
      contains('daha_fazla_hareket'),
    );
  });

  testWidgets('sohbetten öğrenilen gerçekler kaydetmede silinmez', (
    tester,
  ) async {
    await pump(tester, initial: const {'onboarding_weight': 62});
    await memory.addFact('Sabahları koşuyor');

    await tester.enterText(find.widgetWithText(TextField, '62'), '58');
    await tester.pump();
    await save(tester);

    expect(memory.state.facts, contains('Sabahları koşuyor'));
    expect(memory.state.facts, contains('Kilo: 58 kg'));
  });

  for (final width in const [320.0, 375.0]) {
    testWidgets('${width.toInt()}px genişlikte taşmaz', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pump(tester);

      expect(
        tester.takeException(),
        isNull,
        reason: '${width.toInt()}px genişlikte tercihler ekranı taşıyor',
      );
      // Üç sayı alanı yan yana duruyor; dar ekranın asıl riski orası.
      expect(find.text(l10n.preferencesBodyLabel), findsOneWidget);
    });
  }
}
