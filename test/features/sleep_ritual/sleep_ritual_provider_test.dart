import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/billing/usage_meter.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_models.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ILND'yi taklit eden servis: sabit yanıt döner ya da fırlatır.
class _FakeIlndService extends IlndService {
  const _FakeIlndService({this.reply, this.throws = false});
  final String? reply;
  final bool throws;

  @override
  Future<String> respond({
    required IlndMemory memory,
    required String userMessage,
    required AppLocalizations l10n,
    List<IlndTurn> history = const [],
    String? task,
    IlndTier tier = IlndTier.quick,
    String? fallback,
    UsageKind? meterAs,
  }) async {
    if (throws) throw const IlndServiceException('offline');
    return reply!;
  }
}

const _validPlanJson = '''
{"adimlar":[
  {"tip":"kontrol","baslik":"odanı yumuşat","maddeler":["ışıkları kıs","telefonu uzaklaştır"]},
  {"tip":"yazi","soru":"bugün seni ne yordu?","ipucu":"tek cümle yeter"},
  {"tip":"mesaj","metin":"bugün elinden geleni yaptın."}
],"kapanis":"iyi uykular, yarın yeni bir gün."}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('tr'));

  String today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<ProviderContainer> makeContainer({IlndService? service}) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ilndMemoryProvider.overrideWith(
          (ref) => IlndMemoryNotifier(prefs, '', null),
        ),
        if (service != null) ilndServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('isSleepRitualWindow', () {
    test('akşam 21:00 ve gece yarısı sonrası açık, gündüz kapalı', () {
      expect(isSleepRitualWindow(20), isFalse);
      expect(isSleepRitualWindow(21), isTrue);
      expect(isSleepRitualWindow(23), isTrue);
      expect(isSleepRitualWindow(0), isTrue);
      expect(isSleepRitualWindow(3), isTrue);
      expect(isSleepRitualWindow(4), isFalse);
      expect(isSleepRitualWindow(12), isFalse);
    });
  });

  group('sleepRitualDoneTonightProvider', () {
    test('boş prefs → false; record() → true ve prefs yazılır', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await makeContainer();

      expect(container.read(sleepRitualDoneTonightProvider), isFalse);

      await container.read(sleepRitualDoneTonightProvider.notifier).record();
      expect(container.read(sleepRitualDoneTonightProvider), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sleep_ritual_date'), today());
      expect(prefs.getBool('sleep_ritual_done'), isTrue);
    });

    test('dünün kaydı bugünü kirletmez', () async {
      SharedPreferences.setMockInitialValues({
        'sleep_ritual_date': '2020-01-01',
        'sleep_ritual_done': true,
      });
      final container = await makeContainer();
      expect(container.read(sleepRitualDoneTonightProvider), isFalse);
    });
  });

  group('parseSleepRitualPlan', () {
    test('geçerli JSON plana çevrilir', () {
      final plan = parseSleepRitualPlan(_validPlanJson)!;
      expect(plan.steps, hasLength(3));
      expect(plan.steps[0].type, SleepRitualStepType.checklist);
      expect(plan.steps[0].items, hasLength(2));
      expect(plan.steps[1].type, SleepRitualStepType.text);
      expect(plan.steps[1].prompt, 'bugün seni ne yordu?');
      expect(plan.steps[2].type, SleepRitualStepType.message);
      expect(plan.closing, contains('iyi uykular'));
    });

    test('markdown çitli yanıttan da ayıklar', () {
      final plan = parseSleepRitualPlan('```json\n$_validPlanJson\n```');
      expect(plan, isNotNull);
    });

    test('nefes süresi 30-180 aralığına sıkıştırılır, 2. nefes elenir', () {
      final plan = parseSleepRitualPlan(
        '{"adimlar":[{"tip":"nefes","sure_sn":900},'
        '{"tip":"nefes","sure_sn":60}],"kapanis":"x"}',
      )!;
      expect(plan.steps, hasLength(1));
      expect(plan.steps.first.breathSeconds, 180);
    });

    test('bozuk/boş yanıt null döner (yedeğe düşülür)', () {
      expect(parseSleepRitualPlan('bir şeyler ters gitti'), isNull);
      expect(parseSleepRitualPlan('{"adimlar":[]}'), isNull);
      expect(
        parseSleepRitualPlan('{"adimlar":[{"tip":"bilinmeyen"}]}'),
        isNull,
      );
    });
  });

  group('SleepRitualFlowNotifier', () {
    test('prepare: ILND planı kurar, kuyruk sonu kapanış', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await makeContainer(
        service: const _FakeIlndService(reply: _validPlanJson),
      );
      final notifier = container.read(sleepRitualFlowProvider.notifier);

      await notifier.prepare(l10n);

      final state = container.read(sleepRitualFlowProvider);
      expect(state.phase, SleepRitualPhase.running);
      expect(state.queue, hasLength(4)); // 3 adım + kapanış
      expect(state.queue.last.type, SleepRitualStepType.closing);
      expect(state.queue.last.message, contains('iyi uykular'));
    });

    test('prepare: servis hata verirse yedek plan devreye girer', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await makeContainer(
        service: const _FakeIlndService(throws: true),
      );
      final notifier = container.read(sleepRitualFlowProvider.notifier);

      await notifier.prepare(l10n);

      final state = container.read(sleepRitualFlowProvider);
      expect(state.phase, SleepRitualPhase.running);
      expect(state.queue.first.type, SleepRitualStepType.checklist);
      expect(state.queue.first.title, l10n.sleepRitualStepPrepTitle);
      expect(state.queue.last.type, SleepRitualStepType.closing);
      expect(state.queue.last.message, isNotEmpty);
    });

    test(
      'advance kuyruğu yürür; kapanıştan sonra done + bayrak + not',
      () async {
        SharedPreferences.setMockInitialValues({});
        final container = await makeContainer(
          service: const _FakeIlndService(reply: _validPlanJson),
        );
        final notifier = container.read(sleepRitualFlowProvider.notifier);
        await notifier.prepare(l10n);

        await notifier.advance(); // kontrol → yazi
        notifier.setAnswer('toplantılar yordu');
        await notifier.advance(); // yazi → mesaj
        await notifier.advance(); // mesaj → kapanış
        await notifier.advance(); // kapanış → done

        expect(
          container.read(sleepRitualFlowProvider).phase,
          SleepRitualPhase.done,
        );
        expect(container.read(sleepRitualDoneTonightProvider), isTrue);
        expect(
          container.read(ilndMemoryProvider).recentNotes.join(),
          contains('toplantılar yordu'),
        );
      },
    );
  });
}
