import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/billing/usage_meter.dart';

void main() {
  group('UsageState', () {
    test('countOf defaults to 0 for a kind with no recorded usage', () {
      final state = UsageState(weekKey: usageWeekKey());
      expect(state.countOf(UsageKind.message), 0);
    });

    test('remaining is the free weekly limit minus the count so far', () {
      final state = UsageState(
        weekKey: usageWeekKey(),
        counts: const {UsageKind.message: 3},
      );
      expect(
        state.remaining(UsageKind.message),
        kFreeWeeklyLimits[UsageKind.message]! - 3,
      );
    });
  });

  group('usageWeekKey', () {
    // functions/index.js'teki currentWeekKey ile aynı formül olmalı:
    //   days = floor(ms / 86400000); key = "W" + floor((days + 3) / 7)
    // Bu test o formülü bağımsız olarak yeniden hesaplayıp karşılaştırır —
    // taraflardan biri kayarsa istemci sunucunun yazdığından BAŞKA bir
    // dokümanı okur ve kalan hak yanlış görünür.
    String jsFormula(DateTime t) {
      final days = t.toUtc().millisecondsSinceEpoch ~/ 86400000;
      return 'W${(days + 3) ~/ 7}';
    }

    test('matches the server formula across a range of dates', () {
      for (var i = 0; i < 400; i++) {
        final t = DateTime.utc(2026, 1, 1).add(Duration(days: i, hours: 7));
        expect(usageWeekKey(t), jsFormula(t));
      }
    });

    test('rolls over on Monday UTC, not mid-week', () {
      // 2026-07-27 Pazartesi.
      final sunday = DateTime.utc(2026, 7, 26, 23, 59);
      final monday = DateTime.utc(2026, 7, 27, 0, 1);
      final saturday = DateTime.utc(2026, 8, 1, 12);
      expect(usageWeekKey(monday), isNot(usageWeekKey(sunday)));
      expect(usageWeekKey(saturday), usageWeekKey(monday));
    });

    test('is timezone-independent — the same instant is the same week', () {
      final utc = DateTime.utc(2026, 7, 29, 12);
      expect(usageWeekKey(utc.toLocal()), usageWeekKey(utc));
    });
  });

  group('UsageMeterNotifier', () {
    late StreamController<UsageState> remote;
    late UsageMeterNotifier notifier;

    setUp(() {
      remote = StreamController<UsageState>();
      notifier = UsageMeterNotifier(remote.stream);
    });

    tearDown(() async {
      notifier.dispose();
      await remote.close();
    });

    test('starts at zero usage until the account counter arrives', () {
      expect(notifier.state.countOf(UsageKind.message), 0);
      expect(notifier.canUse(UsageKind.message), isTrue);
    });

    test('adopts the account counter written by the server', () async {
      remote.add(
        UsageState(
          weekKey: usageWeekKey(),
          counts: const {UsageKind.message: 7, UsageKind.food: 2},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      // Cihazda hiç kullanım yapılmamış olsa bile hesabın sayacı geçerli —
      // kullanıcı web'de harcadığı hakkı mobilde geri kazanamaz.
      expect(notifier.state.countOf(UsageKind.message), 7);
      expect(notifier.state.countOf(UsageKind.food), 2);
    });

    test(
      'does not let a late snapshot undo an in-flight local count',
      () async {
        notifier.record(UsageKind.message);
        notifier.record(UsageKind.message);

        // Sunucudan bir tık geride bir snapshot gelirse sayaç geri düşmemeli,
        // yoksa kullanıcı aynı hakkı iki kez harcayabilir.
        remote.add(
          UsageState(
            weekKey: usageWeekKey(),
            counts: const {UsageKind.message: 1},
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(notifier.state.countOf(UsageKind.message), 2);
      },
    );

    test(
      'ignores a snapshot from a week that has already rolled over',
      () async {
        remote.add(
          const UsageState(weekKey: 'W1', counts: {UsageKind.message: 20}),
        );
        await Future<void>.delayed(Duration.zero);

        expect(notifier.state.countOf(UsageKind.message), 0);
        expect(notifier.canUse(UsageKind.message), isTrue);
      },
    );

    test('record() increments the count for that kind only', () {
      notifier.record(UsageKind.message);
      notifier.record(UsageKind.message);
      notifier.record(UsageKind.food);

      expect(notifier.state.countOf(UsageKind.message), 2);
      expect(notifier.state.countOf(UsageKind.food), 1);
    });

    test('canUse() becomes false once the free weekly limit is reached', () {
      final limit = kFreeWeeklyLimits[UsageKind.food]!;
      for (var i = 0; i < limit; i++) {
        expect(
          notifier.canUse(UsageKind.food),
          isTrue,
          reason: 'should still be allowed before hitting the limit',
        );
        notifier.record(UsageKind.food);
      }

      expect(notifier.canUse(UsageKind.food), isFalse);
    });

    test('markExhausted() closes the gate when the server says 429', () {
      // Hak başka bir cihazda bitmiş olabilir: yerel sayaç sıfır olsa da
      // sunucunun kararı sayacı doldurur, kullanıcı aynı duvara tekrar
      // tekrar çarpmaz.
      expect(notifier.canUse(UsageKind.message), isTrue);
      notifier.markExhausted(UsageKind.message);
      expect(notifier.canUse(UsageKind.message), isFalse);
      expect(notifier.state.remaining(UsageKind.message), 0);
    });

    test(
      'a stream error leaves the gate open (server stays authoritative)',
      () async {
        remote.addError(Exception('permission-denied'));
        await Future<void>.delayed(Duration.zero);

        expect(notifier.canUse(UsageKind.message), isTrue);
      },
    );
  });
}
