import 'package:ilnd_app/l10n/app_localizations.dart';

/// Streak metni — gurur odaklı, asla suçlayıcı değil. Kırılma bir ceza
/// değil, nazik bir "yeniden başla" davetidir.
abstract final class StreakCopy {
  static String? line({
    required int current,
    required int longest,
    required AppLocalizations l10n,
  }) {
    if (current >= 30) return l10n.streakCopyLongStreak(current);
    if (current >= 7) return l10n.streakCopyWeekStreak(current);
    if (current >= 1) return l10n.streakCopyDayStreak(current);
    if (longest > 0) return l10n.streakCopyRestart;
    return null; // henüz hiç seri yok — gürültü yapma
  }
}
