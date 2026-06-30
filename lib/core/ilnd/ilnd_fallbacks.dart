import 'dart:math';

import 'package:ilnd_app/l10n/app_localizations.dart';

/// ILND karakterine uygun, önceden hazırlanmış yedek cevaplar.
///
/// Canlı AI çalışmadığında (anahtar yok, internet yok, limit) demonun akıcı
/// kalması için kullanılır — hata balonu yerine sıcak, inandırıcı bir ILND
/// cümlesi. Her havuzdan rastgele seçilir ki tekrar etmiş gibi durmasın.
class IlndFallbacks {
  IlndFallbacks._();

  static final _rng = Random();

  static String _pick(List<String> pool) => pool[_rng.nextInt(pool.length)];

  /// Genel sohbet karşılığı.
  static String chat(AppLocalizations l10n) => _pick([
    l10n.ilndFallbackChat1,
    l10n.ilndFallbackChat2,
    l10n.ilndFallbackChat3,
    l10n.ilndFallbackChat4,
  ]);

  /// Günlük yazısına nazik karşılık.
  static String journal(AppLocalizations l10n) => _pick([
    l10n.ilndFallbackJournal1,
    l10n.ilndFallbackJournal2,
    l10n.ilndFallbackJournal3,
  ]);

  /// Yemek analizine diyetisyen-dost yorumu.
  static String food(AppLocalizations l10n) => _pick([
    l10n.ilndFallbackFood1,
    l10n.ilndFallbackFood2,
    l10n.ilndFallbackFood3,
    l10n.ilndFallbackFood4,
  ]);
}
