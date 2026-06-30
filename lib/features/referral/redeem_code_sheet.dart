import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

class RedeemCodeSheet extends ConsumerStatefulWidget {
  const RedeemCodeSheet({super.key});

  @override
  ConsumerState<RedeemCodeSheet> createState() => _RedeemCodeSheetState();
}

class _RedeemCodeSheetState extends ConsumerState<RedeemCodeSheet> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations l10n) async {
    final code = _controller.text.trim();
    if (code.isEmpty || _loading) return;

    setState(() => _loading = true);

    bool success = false;
    try {
      final repo = ref.read(referralRepositoryProvider);
      success = repo != null && await repo.redeemCode(code);
    } catch (_) {
      success = false;
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      unawaited(AnalyticsService.logReferralSignupCompleted());
      unawaited(AnalyticsService.logReferralRewardClaimed());
      ref.invalidate(myGrowthProfileProvider);
      Navigator.of(context).pop();
      IlndToast.success(context, l10n.redeemCodeSuccess);
    } else {
      IlndToast.error(context, l10n.redeemCodeInvalid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: p.base,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          16,
          AppSpacing.screenPadding,
          32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              l10n.redeemCodeTitle,
              style: AppTextStyles.heading(fontSize: 20, color: p.text),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: AppTextStyles.body(fontSize: 16, color: p.text),
                decoration: InputDecoration(hintText: l10n.redeemCodeHint),
              ),
            ),
            const SizedBox(height: 20),
            Pressable(
              onTap: _loading ? null : () => _submit(l10n),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: _loading ? p.accent.withValues(alpha: 0.5) : p.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: _loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.onAccent,
                        ),
                      )
                    : Text(
                        l10n.redeemCodeConfirm,
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
    );
  }
}
