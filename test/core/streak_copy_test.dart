import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/streak_copy.dart';
import 'package:ilnd_app/l10n/app_localizations_tr.dart';

void main() {
  final l10n = AppLocalizationsTr();

  group('StreakCopy.line', () {
    test(
      'returns null when there is no current streak and no longest streak',
      () {
        final line = StreakCopy.line(current: 0, longest: 0, l10n: l10n);
        expect(line, isNull);
      },
    );

    test(
      'invites a gentle restart when the streak broke but a longest streak exists',
      () {
        final line = StreakCopy.line(current: 0, longest: 12, l10n: l10n);
        expect(line, l10n.streakCopyRestart);
      },
    );

    test('shows day-streak copy for 1-6 day streaks', () {
      final line = StreakCopy.line(current: 3, longest: 3, l10n: l10n);
      expect(line, l10n.streakCopyDayStreak(3));
    });

    test('shows week-streak copy starting at exactly 7 days', () {
      final line = StreakCopy.line(current: 7, longest: 7, l10n: l10n);
      expect(line, l10n.streakCopyWeekStreak(7));
    });

    test('shows week-streak copy below the 30-day threshold', () {
      final line = StreakCopy.line(current: 29, longest: 29, l10n: l10n);
      expect(line, l10n.streakCopyWeekStreak(29));
    });

    test('shows long-streak copy starting at exactly 30 days', () {
      final line = StreakCopy.line(current: 30, longest: 30, l10n: l10n);
      expect(line, l10n.streakCopyLongStreak(30));
    });

    test('shows long-streak copy well above the 30-day threshold', () {
      final line = StreakCopy.line(current: 120, longest: 120, l10n: l10n);
      expect(line, l10n.streakCopyLongStreak(120));
    });
  });
}
