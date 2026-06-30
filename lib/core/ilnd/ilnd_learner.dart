import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// ILND'nin konuşmalardan kalıcı hafıza biriktirmesini sağlar.
///
/// Bir metni (günlük, mesaj) ucuz modelle ayıklar ve çıkan hedef/gerçekleri
/// kalıcı hafızaya işler. "Beni gerçekten tanıyor" hissinin motoru budur.
/// Maliyet için fire-and-forget ve seçili anlarda çağrılır.
class IlndLearner {
  IlndLearner(this._ref);

  final Ref _ref;

  Future<void> learnFrom(String text, AppLocalizations l10n) async {
    if (text.trim().length < 12) {
      return; // çok kısa metinden öğrenecek bir şey yok
    }
    try {
      final service = _ref.read(ilndServiceProvider);
      final memory = _ref.read(ilndMemoryProvider);
      final extracted = await service.extractMemory(
        text: text,
        known: memory,
        l10n: l10n,
      );

      final notifier = _ref.read(ilndMemoryProvider.notifier);
      for (final goal in extracted.goals) {
        await notifier.addGoal(goal);
      }
      for (final fact in extracted.facts) {
        await notifier.addFact(fact);
      }
    } catch (_) {
      // Öğrenme opsiyoneldir; sessizce geç.
    }
  }
}

final ilndLearnerProvider = Provider<IlndLearner>((ref) => IlndLearner(ref));
