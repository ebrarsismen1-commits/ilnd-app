import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/billing/usage_meter.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/premium/paywall_screen.dart';
import 'package:ilnd_app/features/takip/meal_edit_sheet.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kayıtlı öğünde malzeme düzeltmenin PARA kuralı burada kilitleniyor:
/// düzeltmek bedava, yalnız makroların yeniden hesaplanması bir analiz hakkı
/// yer. Kural kayarsa iki yönde de zarar var — bedava sanılan bir çağrı
/// kullanıcının haftalık hakkını sessizce bitirir, ücretli sanılan bir
/// düzeltme ise kullanıcıyı yanlış yazılmış öğünle yaşamaya mahkûm eder.

class _FakeGate implements UsageGate {
  bool allowed = true;
  final recorded = <UsageKind>[];
  final exhausted = <UsageKind>[];

  @override
  bool isAllowed(UsageKind kind) => allowed;

  @override
  void record(UsageKind kind) => recorded.add(kind);

  @override
  void markExhausted(UsageKind kind) => exhausted.add(kind);
}

class _FakeFoodRepo extends FoodRepository {
  _FakeFoodRepo() : super('test-user');

  /// Yalnız listeyi yazan (bedava) çağrılar.
  final ingredientWrites = <List<String>>[];

  /// Makroları da yazan (ücretli) çağrılar.
  final recalcWrites = <Map<String, Object>>[];

  @override
  Future<void> updateIngredients(String id, List<String> malzemeler) async =>
      ingredientWrites.add([...malzemeler]);

  @override
  Future<void> updateAfterRecalculate(
    String id, {
    required List<String> malzemeler,
    required int kalori,
    required int protein,
    required int karbonhidrat,
    required int yag,
  }) async => recalcWrites.add({
    'malzemeler': [...malzemeler],
    'kalori': kalori,
    'protein': protein,
    'karbonhidrat': karbonhidrat,
    'yag': yag,
  });
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('tr'));

  final entry = FoodEntry(
    id: 'e1',
    yemekAdi: 'mercimek çorbası',
    kalori: 300,
    protein: 12,
    karbonhidrat: 40,
    yag: 8,
    createdAt: DateTime(2026, 9, 3, 12),
    malzemeler: const ['mercimek', 'soğan'],
  );

  late _FakeGate gate;
  late _FakeFoodRepo repo;
  late List<(String, Map<String, Object?>?)> analytics;

  Map<String, Object?>? paramsOf(String name) =>
      analytics.firstWhere((e) => e.$1 == name, orElse: () => ('', null)).$2;

  setUp(() {
    gate = _FakeGate();
    repo = _FakeFoodRepo();
    analytics = [];
    AnalyticsService.testSink = (name, params) => analytics.add((name, params));
  });

  tearDown(() => AnalyticsService.testSink = null);

  /// Sayfayı açar ve malzeme alanına [ingredient] yazar.
  Future<void> pumpSheet(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          usageGateProvider.overrideWithValue(gate),
          foodRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showMealEditSheet(context, entry),
                  child: const Text('ac'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();
  }

  Future<void> addIngredient(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextField), value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('malzeme eklemek tek başına hiçbir hak harcamaz', (tester) async {
    await pumpSheet(tester);

    expect(find.text('mercimek'), findsOneWidget);
    expect(find.text(l10n.takipMealEditFreeHint), findsOneWidget);

    await addIngredient(tester, 'zeytinyağı');

    expect(find.text('zeytinyağı'), findsOneWidget);
    expect(gate.recorded, isEmpty, reason: 'çip eklemek analiz çağrısı DEĞİL');
    expect(repo.ingredientWrites, isEmpty, reason: 'kaydet henüz basılmadı');
  });

  testWidgets('kaydet yalnız listeyi yazar, makrolara ve kotaya dokunmaz', (
    tester,
  ) async {
    await pumpSheet(tester);
    await addIngredient(tester, 'zeytinyağı');

    await tester.tap(find.text(l10n.takipMealEditSave));
    await tester.pumpAndSettle();

    expect(repo.ingredientWrites, [
      ['mercimek', 'soğan', 'zeytinyağı'],
    ]);
    expect(repo.recalcWrites, isEmpty, reason: 'makrolar olduğu gibi kalır');
    expect(gate.recorded, isEmpty, reason: 'bedava düzeltme kotadan düşmez');
    expect(paramsOf('food_entry_edited'), {'recalculated': false});
  });

  testWidgets('yeniden hesaplama bir analiz hakkı düşer ve makroları yazar', (
    tester,
  ) async {
    await pumpSheet(tester);
    await addIngredient(tester, 'zeytinyağı');

    await tester.tap(find.text(l10n.yemekEkleRecalculate));
    await tester.pump();
    // Proxy testte yapılandırılmamış: ekran ağ yerine demo dalına düşer ve
    // makroları malzeme sayısıyla ölçekler (2 → 3, yani 1.5x).
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(gate.recorded, [UsageKind.food]);
    expect(repo.recalcWrites.length, 1);
    expect(repo.recalcWrites.single['kalori'], 450);
    expect(repo.recalcWrites.single['malzemeler'], [
      'mercimek',
      'soğan',
      'zeytinyağı',
    ]);
    expect(paramsOf('food_entry_edited'), {'recalculated': true});
    expect(
      repo.ingredientWrites,
      isEmpty,
      reason: 'liste makrolarla birlikte tek yazmada gider',
    );
  });

  testWidgets('hak dolduğunda hesaplama başlamaz, paywall açılır', (
    tester,
  ) async {
    gate.allowed = false;
    await pumpSheet(tester);
    await addIngredient(tester, 'zeytinyağı');

    await tester.tap(find.text(l10n.yemekEkleRecalculate));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(repo.recalcWrites, isEmpty);
    expect(gate.recorded, isEmpty);
  });
}
