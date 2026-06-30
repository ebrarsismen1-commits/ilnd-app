import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/habits/habits_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

Future<void> showSuEkleSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.charcoal.withValues(alpha: 0.45),
    isScrollControlled: true,
    builder: (_) => const _SuEkleSheet(),
  );
}

const _kOptions = [150, 250, 350, 500];
const _kHedef = 2000; // ml

class _SuEkleSheet extends ConsumerWidget {
  const _SuEkleSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final waterMl = ref.watch(waterTodayProvider);
    final notifier = ref.read(waterTodayProvider.notifier);
    final pct = (waterMl / _kHedef).clamp(0.0, 1.0);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: p.base,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          12,
          AppSpacing.screenPadding,
          32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              l10n.suEkleTitle,
              style: AppTextStyles.display(fontSize: 24, color: p.text),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.suEkleDailyGoal(_kHedef),
              style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
            ),
            const SizedBox(height: 20),

            // Progress
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: p.border,
                          color: const Color(0xFF93D5FF),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.suEkleProgress(waterMl, _kHedef),
                        style: AppTextStyles.mono(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: p.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (waterMl > 0)
                  Pressable(
                    onTap: () async {
                      await notifier.reset();
                      if (context.mounted) {
                        IlndToast.success(context, l10n.suEkleReset);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        l10n.suEkleResetButton,
                        style: AppTextStyles.body(
                          fontSize: 12,
                          color: p.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // Quick-add buttons
            Text(
              l10n.suEkleHowMuch,
              style: AppTextStyles.label(fontSize: 12, color: p.textMuted),
            ),
            const SizedBox(height: 12),
            Row(
              children: _kOptions.map((ml) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Pressable(
                      onTap: () async {
                        await notifier.add(ml);
                        if (context.mounted) {
                          IlndToast.success(context, l10n.suEkleAdded(ml));
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: p.surfaceStrong,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.border, width: 0.5),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '+$ml',
                              style: AppTextStyles.mono(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: p.text,
                              ),
                            ),
                            Text(
                              l10n.suEkleMl,
                              style: AppTextStyles.label(
                                fontSize: 10,
                                color: p.textMuted,
                              ).copyWith(letterSpacing: 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
