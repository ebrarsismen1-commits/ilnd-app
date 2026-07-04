import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Deterministic crisis safety net.
///
/// The AI persona is *instructed* to handle crisis signals gently, but a
/// mental-wellness app cannot leave that to model discretion alone: when a
/// user's own words signal self-harm, concrete human resources must appear
/// regardless of what the model replies. This guard is intentionally simple
/// (keyword match, no network, no logging of matched text) so it can never
/// fail silently or leak sensitive content.
abstract final class CrisisGuard {
  static final _patterns = RegExp(
    // TR
    r'intihar|kendimi öldür|canıma kıy|yaşamak istemiyorum|ölmek istiyorum'
    r'|kendime zarar|kendimi kes'
    // EN
    r'|suicide|kill myself|end my life|want to die|hurt myself|self.?harm'
    r"|don'?t want to live",
    caseSensitive: false,
    unicode: true,
  );

  static bool matches(String text) => _patterns.hasMatch(text.toLowerCase());
}

/// Shows the crisis resource sheet. Never blocks the user's original action
/// (message still sends, journal still saves) — support is offered, not
/// forced.
Future<void> showCrisisResourceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _CrisisSheet(),
  );
}

class _CrisisSheet extends ConsumerWidget {
  const _CrisisSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);

    return Container(
      decoration: BoxDecoration(
        color: p.isDark ? p.surfaceStrong : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.favorite_rounded, color: p.accent, size: 28),
          const SizedBox(height: 12),
          Text(
            l10n.crisisTitle,
            style: AppTextStyles.heading(fontSize: 20, color: p.text),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.crisisBody,
            style: AppTextStyles.body(
              fontSize: 14,
              color: p.textMuted,
            ).copyWith(height: 1.5),
          ),
          const SizedBox(height: 18),
          _ResourceRow(text: l10n.crisisLine112, p: p),
          const SizedBox(height: 10),
          _ResourceRow(text: l10n.crisisLine183, p: p),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.onAccent,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.crisisDismiss),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({required this.text, required this.p});
  final String text;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.call_rounded, size: 18, color: p.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body(
                fontSize: 14,
                color: p.text,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
