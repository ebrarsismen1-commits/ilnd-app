import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/ilnd/vibe_card_copy.dart';
import 'package:ilnd_app/l10n/app_localizations_tr.dart';

void main() {
  final l10n = AppLocalizationsTr();

  group('VibeCardCopy.headline', () {
    test('celebrates a 7+ day streak above everything else', () {
      final headline = VibeCardCopy.headline(
        journalCount: 1,
        streakDays: 7,
        l10n: l10n,
      );
      expect(headline, l10n.vibeCardHeadlineWeekStreak);
    });

    test('recognizes an active week (3+ journal entries) without a streak', () {
      final headline = VibeCardCopy.headline(
        journalCount: 3,
        streakDays: 0,
        l10n: l10n,
      );
      expect(headline, l10n.vibeCardHeadlineActiveWeek);
    });

    test('recognizes a first step (1-2 journal entries)', () {
      final headline = VibeCardCopy.headline(
        journalCount: 1,
        streakDays: 0,
        l10n: l10n,
      );
      expect(headline, l10n.vibeCardHeadlineFirstStep);
    });

    test('falls back to a quiet-week invite when there is no activity', () {
      final headline = VibeCardCopy.headline(
        journalCount: 0,
        streakDays: 0,
        l10n: l10n,
      );
      expect(headline, l10n.vibeCardHeadlineQuietWeek);
    });
  });

  group('VibeCardCopy.subline', () {
    test(
      'shows an empty-state message when there is no journal or habit activity',
      () {
        final subline = VibeCardCopy.subline(
          journalCount: 0,
          habitCount: 0,
          l10n: l10n,
        );
        expect(subline, l10n.vibeCardSublineEmpty);
      },
    );

    test('uses singular phrasing for exactly 1 journal entry', () {
      final subline = VibeCardCopy.subline(
        journalCount: 1,
        habitCount: 0,
        l10n: l10n,
      );
      expect(subline, '${l10n.vibeCardSublineJournalCount(1)}.');
    });

    test('uses plural phrasing for multiple journal entries', () {
      final subline = VibeCardCopy.subline(
        journalCount: 5,
        habitCount: 0,
        l10n: l10n,
      );
      expect(subline, '${l10n.vibeCardSublineJournalCount(5)}.');
    });

    test('joins journal and habit fragments when both are present', () {
      final subline = VibeCardCopy.subline(
        journalCount: 2,
        habitCount: 3,
        l10n: l10n,
      );
      expect(
        subline,
        '${l10n.vibeCardSublineJournalCount(2)}, ${l10n.vibeCardSublineHabitCount(3)}.',
      );
    });
  });
}
