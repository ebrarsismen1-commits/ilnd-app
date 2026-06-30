import 'package:ilnd_app/l10n/app_localizations.dart';

/// Vibe Card için statik, deterministik anlatı metni — LLM çağrısı yok,
/// her zaman hızlı ve ücretsiz. Sayı odaklı değil, duygu/anlatı odaklı.
///
/// Bilerek burada (UI katmanında) hesaplanır, repository'de değil —
/// repository bir [BuildContext]'e (dolayısıyla [AppLocalizations]'a)
/// erişemez; ham sayılar [VibeCardData]'da taşınır, metin sadece
/// gösterilirken üretilir.
abstract final class VibeCardCopy {
  static String headline({
    required int journalCount,
    required int streakDays,
    required AppLocalizations l10n,
  }) {
    if (streakDays >= 7) return l10n.vibeCardHeadlineWeekStreak;
    if (journalCount >= 3) return l10n.vibeCardHeadlineActiveWeek;
    if (journalCount >= 1) return l10n.vibeCardHeadlineFirstStep;
    return l10n.vibeCardHeadlineQuietWeek;
  }

  static String subline({
    required int journalCount,
    required int habitCount,
    required AppLocalizations l10n,
  }) {
    if (journalCount == 0 && habitCount == 0) {
      return l10n.vibeCardSublineEmpty;
    }
    final parts = <String>[
      if (journalCount > 0) l10n.vibeCardSublineJournalCount(journalCount),
      if (habitCount > 0) l10n.vibeCardSublineHabitCount(habitCount),
    ];
    return '${parts.join(', ')}.';
  }
}
