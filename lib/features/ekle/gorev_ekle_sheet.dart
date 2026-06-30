import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/habits/habits_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

Future<void> showGorevEkleSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.charcoal.withValues(alpha: 0.45),
    isScrollControlled: true,
    builder: (_) => const _GorevEkleSheet(),
  );
}

class _GorevEkleSheet extends ConsumerStatefulWidget {
  const _GorevEkleSheet();

  @override
  ConsumerState<_GorevEkleSheet> createState() => _GorevEkleSheetState();
}

class _GorevEkleSheetState extends ConsumerState<_GorevEkleSheet> {
  final _nameCtrl = TextEditingController();
  int _targetDays = 5;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(AppLocalizations l10n) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      IlndToast.error(context, l10n.gorevEkleNameEmpty);
      return;
    }

    final auth = ref.read(authNotifierProvider);
    if (auth is! AuthAuthenticated) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(habitsRepositoryProvider)
          .addHabit(auth.user.id, name, _targetDays);
      if (mounted) {
        Navigator.of(context).pop();
        IlndToast.success(context, l10n.gorevEkleSuccess);
      }
    } catch (_) {
      if (mounted) IlndToast.error(context, l10n.gorevEkleFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          decoration: BoxDecoration(
            color: p.base,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            12,
            AppSpacing.screenPadding,
            28,
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
                l10n.gorevEkleTitle,
                style: AppTextStyles.display(fontSize: 24, color: p.text),
              ),
              const SizedBox(height: 20),

              // Name input
              Container(
                decoration: BoxDecoration(
                  color: p.surfaceStrong,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  style: AppTextStyles.body(fontSize: 15, color: p.text),
                  decoration: InputDecoration(
                    hintText: l10n.gorevEkleHint,
                    hintStyle: AppTextStyles.body(
                      fontSize: 15,
                      color: p.textMuted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _save(l10n),
                ),
              ),

              const SizedBox(height: 20),

              // Target days per week
              Text(
                l10n.gorevEkleDaysPerWeek,
                style: AppTextStyles.label(fontSize: 12, color: p.textMuted),
              ),
              const SizedBox(height: 10),
              Row(
                children: List.generate(7, (i) {
                  final day = i + 1;
                  final selected = day == _targetDays;
                  return Pressable(
                    onTap: () => setState(() => _targetDays = day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: selected ? p.accent : p.surfaceStrong,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$day',
                        style: AppTextStyles.mono(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? p.onAccent : p.textMuted,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // Save button
              Pressable(
                onTap: _saving ? null : () => _save(l10n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 52,
                  decoration: BoxDecoration(
                    color: _saving ? p.accent.withValues(alpha: 0.5) : p.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.onAccent,
                          ),
                        )
                      : Text(
                          l10n.gorevEkleSave,
                          style: AppTextStyles.body(
                            fontSize: 15,
                            color: p.onAccent,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
