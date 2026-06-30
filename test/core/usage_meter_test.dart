import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/billing/usage_meter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // SharedPreferences.setMockInitialValues lets getInstance() resolve in
  // plain `flutter test` without a real platform/plugin — this is the
  // standard way to exercise SharedPreferences-backed logic in unit tests.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UsageState', () {
    test('countOf defaults to 0 for a kind with no recorded usage', () {
      const state = UsageState(weekKey: '2026-W1');
      expect(state.countOf(UsageKind.message), 0);
    });

    test('remaining is the free weekly limit minus the count so far', () {
      const state = UsageState(
        weekKey: '2026-W1',
        counts: {UsageKind.message: 3},
      );
      expect(
        state.remaining(UsageKind.message),
        kFreeWeeklyLimits[UsageKind.message]! - 3,
      );
    });
  });

  group('UsageMeterNotifier', () {
    test('starts at zero usage with nothing persisted', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = UsageMeterNotifier(prefs);
      expect(notifier.state.countOf(UsageKind.message), 0);
      expect(notifier.canUse(UsageKind.message), isTrue);
    });

    test('record() increments the count for that kind only', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = UsageMeterNotifier(prefs);

      await notifier.record(UsageKind.message);
      await notifier.record(UsageKind.message);
      await notifier.record(UsageKind.food);

      expect(notifier.state.countOf(UsageKind.message), 2);
      expect(notifier.state.countOf(UsageKind.food), 1);
    });

    test(
      'canUse() becomes false once the free weekly limit is reached',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final notifier = UsageMeterNotifier(prefs);

        final limit = kFreeWeeklyLimits[UsageKind.food]!;
        for (var i = 0; i < limit; i++) {
          expect(
            notifier.canUse(UsageKind.food),
            isTrue,
            reason: 'should still be allowed before hitting the limit',
          );
          await notifier.record(UsageKind.food);
        }

        expect(notifier.canUse(UsageKind.food), isFalse);
      },
    );

    test(
      'persists usage across notifier instances backed by the same prefs',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await UsageMeterNotifier(prefs).record(UsageKind.message);

        // A fresh notifier reading the same SharedPreferences instance should
        // pick up the previously recorded usage instead of starting at zero.
        final reloaded = UsageMeterNotifier(prefs);
        expect(reloaded.state.countOf(UsageKind.message), 1);
      },
    );

    test(
      'rolls usage over when the stored week differs from the current week',
      () async {
        SharedPreferences.setMockInitialValues({
          'usage_meter': '{"weekKey":"2000-W1","counts":{"message":20}}',
        });
        final prefs = await SharedPreferences.getInstance();
        final notifier = UsageMeterNotifier(prefs);

        // Stored data is from a long-past week, so usage must reset rather
        // than carry over a maxed-out count forever.
        expect(notifier.state.countOf(UsageKind.message), 0);
        expect(notifier.canUse(UsageKind.message), isTrue);
      },
    );
  });
}
