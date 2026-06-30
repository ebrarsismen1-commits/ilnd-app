import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/ekle/gorev_ekle_sheet.dart';
import 'package:ilnd_app/features/ekle/su_ekle_sheet.dart';
import 'package:ilnd_app/features/ekle/yemek_ekle_screen.dart';
import 'package:ilnd_app/features/journal/journal_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

// ─── Public entry point ───────────────────────────────────────────────────────

Future<void> showEkleSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.charcoal.withValues(alpha: 0.45),
    isScrollControlled: true,
    builder: (_) => const _EkleSheet(),
  );
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _EkleSheet extends ConsumerWidget {
  const _EkleSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Container(
          decoration: BoxDecoration(
            color: p.base,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                child: Text(
                  l10n.ekleTitle,
                  style: AppTextStyles.display(fontSize: 28, color: p.text),
                ),
              ),

              const SizedBox(height: 20),

              // 2×2 action grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.45,
                  children: [
                    _ActionCard(
                      p: p,
                      icon: Icons.camera_alt_outlined,
                      iconColor: p.amber,
                      title: l10n.ekleFoodTitle,
                      subtitle: l10n.ekleFoodSubtitle,
                      action: 'yemek_ekle',
                    ),
                    _ActionCard(
                      p: p,
                      icon: Icons.edit_outlined,
                      iconColor: p.accent,
                      title: l10n.ekleJournalTitle,
                      subtitle: l10n.ekleJournalSubtitle,
                      action: 'gunluk_yaz',
                    ),
                    _ActionCard(
                      p: p,
                      icon: Icons.check_box_outlined,
                      iconColor: p.accent,
                      title: l10n.ekleHabitTitle,
                      subtitle: l10n.ekleHabitSubtitle,
                      action: 'gorev_ekle',
                    ),
                    _ActionCard(
                      p: p,
                      icon: Icons.water_drop_outlined,
                      iconColor: p.accent,
                      title: l10n.ekleWaterTitle,
                      subtitle: l10n.ekleWaterSubtitle,
                      action: 'su_ekle',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Close button
              Center(
                child: Pressable(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: p.onAccent, size: 18),
                  ),
                ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Action card ──────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.p,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final AppPalette p;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        if (action == 'yemek_ekle') {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const YemekEkleScreen()),
          );
        } else if (action == 'gunluk_yaz') {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const JournalScreen()),
          );
        } else if (action == 'gorev_ekle') {
          Navigator.of(context).pop();
          showGorevEkleSheet(context);
        } else if (action == 'su_ekle') {
          Navigator.of(context).pop();
          showSuEkleSheet(context);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          border: Border.all(color: p.border, width: 0.5),
        ),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 26),
            const Spacer(),
            Text(
              title,
              style: AppTextStyles.body(
                fontSize: 13,
                color: p.text,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTextStyles.body(
                fontSize: 11,
                color: p.textMuted,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
