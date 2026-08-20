import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/ilnd_learner.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hafıza çıkarımı ürünün en ayırt edici parçası ("geçen hafta yazdığımı
/// hatırlıyor") ama aynı zamanda **opsiyonel** bir yan etkidir: günlük
/// kaydetme akışının içinden çağrılıyor. Buradan sızan bir hata kullanıcının
/// yazdığı günlüğü kaybettirir — bu yüzden sessiz kalması sözleşmedir.
class _FakeService extends IlndService {
  const _FakeService({
    this.goals = const [],
    this.facts = const [],
    this.fail = false,
  });

  final List<String> goals;
  final List<String> facts;
  final bool fail;

  static int calls = 0;

  @override
  Future<({List<String> goals, List<String> facts})> extractMemory({
    required String text,
    required AppLocalizations l10n,
    IlndMemory known = const IlndMemory(),
  }) async {
    calls++;
    if (fail) throw Exception('proxy 500');
    return (goals: goals, facts: facts);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;

  setUpAll(() {
    l10n = lookupAppLocalizations(const Locale('tr'));
  });

  setUp(() => _FakeService.calls = 0);

  Future<ProviderContainer> containerWith(_FakeService service) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        ilndServiceProvider.overrideWithValue(service),
        ilndMemoryProvider.overrideWith(
          (ref) => IlndMemoryNotifier(prefs, '', 'uid-1'),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('çıkarılan hedef ve gerçekler hafızaya işlenir', () async {
    final c = await containerWith(
      const _FakeService(
        goals: ['erken kalkmak'],
        facts: ['sabahları koşuyor'],
      ),
    );

    await c
        .read(ilndLearnerProvider)
        .learnFrom('bugün erken kalkmayı denedim ve koşuya çıktım', l10n);

    final memory = c.read(ilndMemoryProvider);
    expect(memory.goals, contains('erken kalkmak'));
    expect(memory.facts, contains('sabahları koşuyor'));
  });

  test('çok kısa metin için AI hiç çağrılmaz', () async {
    final c = await containerWith(const _FakeService());

    await c.read(ilndLearnerProvider).learnFrom('iyiyim', l10n);

    expect(
      _FakeService.calls,
      0,
      reason: 'Kısa metinden öğrenilecek şey yok; para harcanmamalı',
    );
    expect(c.read(ilndMemoryProvider).goals, isEmpty);
  });

  test('yalnız boşluktan oluşan metin de çağrı yapmaz', () async {
    final c = await containerWith(const _FakeService());
    await c.read(ilndLearnerProvider).learnFrom('              ', l10n);
    expect(_FakeService.calls, 0);
  });

  test('servis hatası dışarı SIZMAZ', () async {
    final c = await containerWith(const _FakeService(fail: true));

    // Bu çağrı günlük kaydetme akışının içinden yapılıyor: fırlatırsa
    // kullanıcının yazdığı günlük kaybolur.
    await expectLater(
      c
          .read(ilndLearnerProvider)
          .learnFrom('bu yeterince uzun bir günlük metni sayılır', l10n),
      completes,
    );
    expect(_FakeService.calls, 1);
    expect(c.read(ilndMemoryProvider).goals, isEmpty);
  });

  test('boş çıkarım hafızayı kirletmez', () async {
    final c = await containerWith(
      const _FakeService(goals: [''], facts: ['  ']),
    );

    await c
        .read(ilndLearnerProvider)
        .learnFrom('bu yeterince uzun bir günlük metni sayılır', l10n);

    expect(c.read(ilndMemoryProvider).goals, isEmpty);
    expect(c.read(ilndMemoryProvider).facts, isEmpty);
  });
}
