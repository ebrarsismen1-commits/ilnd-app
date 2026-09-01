import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:ilnd_app/core/billing/usage_meter.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/core/services/app_config.dart';
import 'package:ilnd_app/features/ekle/yemek_ekle_screen.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/premium/paywall_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yemek analizi uygulamanın çağrı başına EN PAHALI AI yüzeyi: her analiz bir
/// vision çağrısıdır. Burada korunan iki şey var — (1) limit dolduğunda çağrının
/// hiç başlamaması (para), (2) hata/iptal yollarında kullanıcının "analiz
/// ediliyor" ekranında sıkışmaması (sessiz kayıp).
///
/// Proxy yapılandırılmamışken ekran bilerek deterministik bir demo sonucuna
/// düşer (yemek_ekle_screen.dart "Demo güvencesi"). Testler bu dalı kullanır:
/// ağ yok, ama analiz sonrası tüm ekran davranışı gerçek.

// ─── Sahte bağımlılıklar ─────────────────────────────────────────────────────

/// [UsageGate] arayüzünü taklit eder. Gerçek gate premium + haftalık sayaç
/// okur; testin ilgilendiği tek şey izin verilip verilmediği ve kaç hak
/// düşüldüğü.
class _FakeGate implements UsageGate {
  /// Testler bunu doğrudan set eder (limit dolu / hak var).
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

/// `extends` zorunlu: [ImagePickerPlatform.instance] setter'ı
/// `PlatformInterface.verify` ile token kontrolü yapar, `implements` reddedilir.
class _FakePicker extends ImagePickerPlatform {
  _FakePicker({this.result});

  XFile? result;

  /// Set edilirse `getImageFromSource` bunu fırlatır (izin reddi vb.).
  Object? failure;

  final sources = <ImageSource>[];
  int get calls => sources.length;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    sources.add(source);
    if (failure != null) throw failure!;
    return result;
  }
}

class _FakeFoodRepo extends FoodRepository {
  _FakeFoodRepo() : super('test-user');

  final added = <FoodEntry>[];

  @override
  Future<void> add(FoodEntry entry) async => added.add(entry);
}

// ─── Yardımcılar ─────────────────────────────────────────────────────────────

/// 1x1 saydam PNG. `Image.memory` gerçek codec kullanır; geçersiz baytlar
/// testi çözümleme hatasıyla düşürür, bu yüzden geçerli bir görsel şart.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
  'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

XFile _photo() => XFile.fromData(
  Uint8List.fromList(_pngBytes),
  name: 'yemek.png',
  mimeType: 'image/png',
);

/// Ekrandaki tüm `Text` içerikleri, ağaç sırasıyla. Sonuç ekranındaki sayılar
/// (kalori, makro değerleri) l10n anahtarı olmayan hesaplanmış dizeler olduğu
/// için konumla okunuyorlar.
List<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .whereType<String>()
    .toList();

/// Büyük kalori sayısı 'kcal' etiketinin hemen solunda duruyor.
int _kcal(WidgetTester tester) {
  final all = _texts(tester);
  final i = all.indexOf('kcal');
  expect(i, greaterThan(0), reason: 'sonuç ekranında kalori satırı yok');
  return int.parse(all[i - 1]);
}

/// `_MacroLine` etiketi solda, değeri sağda — ağaçta ardışık iki Text.
double _macro(WidgetTester tester, String label) {
  final all = _texts(tester);
  final i = all.indexOf(label);
  expect(i, isNonNegative, reason: '$label satırı bulunamadı');
  return double.parse(all[i + 1].replaceAll('g', ''));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('tr'));

  late _FakeGate gate;
  late _FakePicker picker;
  late _FakeFoodRepo repo;

  /// Atılan analitik olayları. Firebase testte kurulu olmadığı için servis
  /// hatayı yutar; bu kanal olmadan hiçbir olay iddiası kurulamaz.
  late List<(String, Map<String, Object?>?)> analytics;

  bool sent(String name) => analytics.any((e) => e.$1 == name);

  Map<String, Object?>? paramsOf(String name) =>
      analytics.firstWhere((e) => e.$1 == name, orElse: () => ('', null)).$2;

  setUp(() {
    gate = _FakeGate();
    picker = _FakePicker(result: _photo());
    repo = _FakeFoodRepo();
    ImagePickerPlatform.instance = picker;
    analytics = [];
    AnalyticsService.testSink = (name, params) => analytics.add((name, params));
  });

  tearDown(() => AnalyticsService.testSink = null);

  /// Ekranı bir alt rota olarak açar — `kaydet`in ekranı kapattığını
  /// doğrulayabilmek için kök rota olmaması gerekiyor.
  Future<void> pumpScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          usageGateProvider.overrideWithValue(gate),
          foodRepositoryProvider.overrideWithValue(repo),
          // Gerçek hafıza notifier'ı auth zincirine bağlı; testte doğrudan
          // kurulur (desen: ilnd_memory_scoping_test).
          ilndMemoryProvider.overrideWith(
            (ref) => IlndMemoryNotifier(prefs, '', 'test-user'),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const YemekEkleScreen(),
                    ),
                  ),
                  child: const Text('ac'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Fotoğraf seç, demo analizinin 1400 ms gecikmesini geç, sonuç ekranına var.
  Future<void> analyse(WidgetTester tester) async {
    await tester.tap(find.text(l10n.yemekEkleChooseFromGallery));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    // ILND yorumu (fallback) ve hafıza notu ayrı mikro-task'larda çözülür.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  test('demo dalı açık: proxy testte yapılandırılmamış olmalı', () {
    // Buradaki widget testleri ekranın demo dalını kullanır. Bir dart-define
    // proxy'yi yapılandırırsa testler sessizce canlı HTTP dalına kayar ve
    // neyi kanıtladıkları belirsizleşir.
    expect(
      AppConfig.isAnthropicProxyConfigured,
      isFalse,
      reason: 'testler --dart-define olmadan koşmalı',
    );
  });

  group('ücretsiz limit kapısı', () {
    testWidgets('hak dolduğunda paywall açılır ve fotoğraf hiç istenmez', (
      tester,
    ) async {
      gate.allowed = false;
      await pumpScreen(tester);

      await tester.tap(find.text(l10n.yemekEkleOpenCamera));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(
        picker.calls,
        0,
        reason: 'limit doluyken kamera açılmamalı — analiz para harcar',
      );
      expect(find.text(l10n.yemekEkleAnalyzing), findsNothing);
    });

    testWidgets('hak varken analiz başlar ve kullanım sayılır', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text(l10n.yemekEkleChooseFromGallery));
      await tester.pump();

      expect(picker.calls, 1);
      expect(picker.sources.single, ImageSource.gallery);
      expect(find.byType(PaywallScreen), findsNothing);

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();

      expect(gate.recorded, [
        UsageKind.food,
      ], reason: 'başarılı analiz haftalık kotadan bir hak düşmeli');
    });
  });

  group('porsiyon çarpanı', () {
    testWidgets('gösterilen kalori ve makrolar çarpanla ölçeklenir', (
      tester,
    ) async {
      await pumpScreen(tester);
      await analyse(tester);

      final baseKcal = _kcal(tester);
      final baseProtein = _macro(tester, l10n.yemekEkleProtein);
      final baseCarbs = _macro(tester, l10n.yemekEkleCarbs);
      expect(baseKcal, greaterThan(0));

      await tester.tap(find.text('2×'));
      await tester.pump();

      expect(_kcal(tester), (baseKcal * 2.0).round());
      expect(
        _macro(tester, l10n.yemekEkleProtein),
        closeTo(baseProtein * 2, 0.05),
      );
      expect(_macro(tester, l10n.yemekEkleCarbs), closeTo(baseCarbs * 2, 0.05));

      await tester.tap(find.text('½×'));
      await tester.pump();

      expect(_kcal(tester), (baseKcal * 0.5).round());
      expect(
        _macro(tester, l10n.yemekEkleProtein),
        closeTo(baseProtein * 0.5, 0.05),
      );
    });

    testWidgets('kaydedilen değerler çarpanla ölçeklenir, ekran kapanır', (
      tester,
    ) async {
      await pumpScreen(tester);
      await analyse(tester);

      final baseKcal = _kcal(tester);
      final baseProtein = _macro(tester, l10n.yemekEkleProtein);

      await tester.tap(find.text('2×'));
      await tester.pump();
      // Sonuç ekranı kaydırılabilir; kaydet butonu katlamanın altında.
      await tester.ensureVisible(find.text(l10n.yemekEkleSaveButton));
      await tester.pump();
      await tester.tap(find.text(l10n.yemekEkleSaveButton));
      await tester.pump();
      // Rota çıkış geçişi (MaterialPageRoute) ~300 ms sürer.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(repo.added, hasLength(1));
      final entry = repo.added.single;
      expect(
        entry.kalori,
        (baseKcal * 2.0).round(),
        reason: 'AI tahmini değil, kullanıcının düzelttiği miktar kaydedilir',
      );
      expect(entry.protein, (baseProtein * 2).round());
      expect(entry.yemekAdi, isNotEmpty);

      expect(
        find.byType(YemekEkleScreen),
        findsNothing,
        reason: 'kaydet ekranı kapatmalı',
      );
    });
  });

  group('hata ve iptal yolları', () {
    testWidgets('fotoğrafa erişilemezse hata ekranı çıkar, sıkışma olmaz', (
      tester,
    ) async {
      picker.failure = PlatformException(code: 'photo_access_denied');
      await pumpScreen(tester);

      await tester.tap(find.text(l10n.yemekEkleOpenCamera));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(l10n.yemekEkleErrorTitle), findsOneWidget);
      expect(find.text(l10n.yemekEklePhotoAccessError), findsOneWidget);
      expect(
        find.text(l10n.yemekEkleAnalyzing),
        findsNothing,
        reason: 'hata sonrası analiz ekranında kalınmamalı',
      );
      expect(
        gate.recorded,
        isEmpty,
        reason: 'başarısız denemede kota düşmemeli',
      );

      // Hata ekranından geri dönülebilmeli.
      await tester.tap(find.text(l10n.yemekEkleRetryButton));
      await tester.pump();
      expect(find.text(l10n.yemekEkleOpenCamera), findsOneWidget);
    });

    testWidgets('kullanıcı seçimi iptal ederse ekran olduğu gibi kalır', (
      tester,
    ) async {
      picker.result = null; // iptal
      await pumpScreen(tester);

      await tester.tap(find.text(l10n.yemekEkleChooseFromGallery));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(l10n.yemekEkleOpenCamera), findsOneWidget);
      expect(
        find.text(l10n.yemekEkleErrorTitle),
        findsNothing,
        reason: 'iptal bir hata değildir',
      );
      expect(gate.recorded, isEmpty);
    });
  });

  // Yemek analizi çağrı başına en pahalı AI yüzeyi; ölçüm olmadan maliyet ve
  // sağlık oranı okunamaz. Olayların DOĞRU ANDA atılması, atılmasından daha
  // önemli: başarısız bir analiz "tamamlandı" sayılırsa panel yalan söyler.
  group('analitik', () {
    testWidgets('limit doluyken analiz değil, limit ve paywall raporlanır', (
      tester,
    ) async {
      gate.allowed = false;
      await pumpScreen(tester);

      await tester.tap(find.text(l10n.yemekEkleOpenCamera));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(sent('free_limit_reached'), isTrue);
      expect(paramsOf('free_limit_reached'), {'kind': 'food'});
      expect(sent('paywall_viewed'), isTrue);
      expect(paramsOf('paywall_viewed'), {'source': 'food'});
      expect(
        sent('food_analysis_started'),
        isFalse,
        reason: 'analiz hiç başlamadı, başlamış gibi sayılmamalı',
      );
    });

    testWidgets('başarılı analiz başladı ve tamamlandı olarak raporlanır', (
      tester,
    ) async {
      await pumpScreen(tester);
      await analyse(tester);

      expect(sent('food_analysis_started'), isTrue);
      expect(sent('food_analysis_completed'), isTrue);
      expect(sent('food_analysis_failed'), isFalse);
    });

    testWidgets('fotoğraf okunamazsa tamamlandı raporlanmaz', (tester) async {
      picker.failure = PlatformException(code: 'photo_access_denied');
      await pumpScreen(tester);

      await tester.tap(find.text(l10n.yemekEkleOpenCamera));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        sent('food_analysis_completed'),
        isFalse,
        reason: 'hata yolunda başarı olayı atılamaz',
      );
      expect(
        sent('food_analysis_started'),
        isFalse,
        reason: 'fotoğraf hiç okunamadı, analiz başlamadı',
      );
    });

    testWidgets('kaydetme, kullanıcının seçtiği porsiyonla raporlanır', (
      tester,
    ) async {
      await pumpScreen(tester);
      await analyse(tester);

      await tester.tap(find.text('2×'));
      await tester.pump();
      await tester.ensureVisible(find.text(l10n.yemekEkleSaveButton));
      await tester.pump();
      await tester.tap(find.text(l10n.yemekEkleSaveButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(sent('food_entry_saved'), isTrue);
      expect(
        paramsOf('food_entry_saved'),
        {'portion': 2.0},
        reason: 'AI tahmini değil, kullanıcının düzelttiği çarpan ölçülür',
      );
    });

    testWidgets('iptal edilen seçim hiçbir olay üretmez', (tester) async {
      picker.result = null;
      await pumpScreen(tester);

      await tester.tap(find.text(l10n.yemekEkleChooseFromGallery));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(analytics, isEmpty);
    });
  });

  group('dar viewport', () {
    testWidgets('sonuç ekranı 320x600 cihazda taşmaz', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 600 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await pumpScreen(tester);
      await analyse(tester);

      expect(find.text(l10n.yemekEklePortionQuestion), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'dar ekranda RenderFlex taşması olmamalı',
      );

      // Çarpan satırı dar ekranda da dokunulabilir kalmalı.
      await tester.ensureVisible(find.text('1½×'));
      await tester.pump();
      await tester.tap(find.text('1½×'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
