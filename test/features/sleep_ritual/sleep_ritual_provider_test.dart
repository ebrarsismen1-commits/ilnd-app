import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_models.dart';
import 'package:ilnd_app/features/sleep_ritual/sleep_ritual_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<ProviderContainer> makeContainer() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ilndMemoryProvider.overrideWith(
          (ref) => IlndMemoryNotifier(prefs, '', null),
        ),
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

    test('bugünün kaydı true okunur', () async {
      SharedPreferences.setMockInitialValues({
        'sleep_ritual_date': today(),
        'sleep_ritual_done': true,
      });
      final container = await makeContainer();
      expect(container.read(sleepRitualDoneTonightProvider), isTrue);
    });
  });

  group('SleepRitualFlowNotifier', () {
    test('seçimsiz start çalışmaz; seçimle kuyruk sıralı + kapanış', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await makeContainer();
      final notifier = container.read(sleepRitualFlowProvider.notifier);

      notifier.start();
      expect(
        container.read(sleepRitualFlowProvider).phase,
        SleepRitualPhase.picker,
      );

      // Ters sırada seç — kuyruk yine kanonik sırada kurulmalı.
      notifier.toggleStep(SleepRitualStep.gratitude);
      notifier.toggleStep(SleepRitualStep.prep);
      notifier.start();

      final state = container.read(sleepRitualFlowProvider);
      expect(state.phase, SleepRitualPhase.running);
      expect(state.queue, [
        SleepRitualStep.prep,
        SleepRitualStep.gratitude,
        SleepRitualStep.closing,
      ]);
      expect(state.current, SleepRitualStep.prep);
    });

    test('advance kuyruğu yürür; kapanıştan sonra done + bayrak', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await makeContainer();
      final notifier = container.read(sleepRitualFlowProvider.notifier);

      notifier.toggleStep(SleepRitualStep.prep);
      notifier.toggleStep(SleepRitualStep.gratitude);
      notifier.setGratitudeText('güneşli yürüyüş');
      notifier.start();

      await notifier.advance(); // prep → gratitude
      expect(
        container.read(sleepRitualFlowProvider).current,
        SleepRitualStep.gratitude,
      );
      await notifier.advance(); // gratitude → closing
      expect(
        container.read(sleepRitualFlowProvider).current,
        SleepRitualStep.closing,
      );
      await notifier.advance(); // closing → done

      expect(
        container.read(sleepRitualFlowProvider).phase,
        SleepRitualPhase.done,
      );
      expect(container.read(sleepRitualDoneTonightProvider), isTrue);
      // Yazı girdisi AI hafızasına not düştü.
      expect(
        container.read(ilndMemoryProvider).recentNotes.join(),
        contains('güneşli yürüyüş'),
      );
    });
  });
}
