import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/billing/revenue_cat_service.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// ILND+ tanıtım ekranı. Limit aşımında veya profilden açılır.
///
/// [reason] varsa başlıkta nazik bir bağlam gösterir
/// (ör. "bu hafta benimle çok konuştun").
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.reason});

  final String? reason;

  static Future<void> show(BuildContext context, {String? reason}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.charcoal.withValues(alpha: 0.5),
      isScrollControlled: true,
      builder: (_) => PaywallScreen(reason: reason),
    );
  }

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _purchasing = false;
  bool _restoring = false;

  Future<void> _purchase(AppLocalizations l10n) async {
    setState(() => _purchasing = true);
    try {
      final success = await RevenueCatService.purchase();
      if (!mounted) return;
      if (success) {
        await ref.read(isPremiumProvider.notifier).setPremium(true);
        if (mounted) Navigator.of(context).pop();
      } else {
        IlndToast.error(context, l10n.paywallPurchaseCancelled);
      }
    } catch (_) {
      if (mounted) IlndToast.error(context, l10n.paywallPurchaseFailed);
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore(AppLocalizations l10n) async {
    setState(() => _restoring = true);
    try {
      final success = await RevenueCatService.restorePurchases();
      if (!mounted) return;
      if (success) {
        await ref.read(isPremiumProvider.notifier).setPremium(true);
        if (!mounted) return;
        IlndToast.success(context, l10n.paywallRestoreSuccess);
        Navigator.of(context).pop();
      } else {
        IlndToast.error(context, l10n.paywallNoActiveSubscription);
      }
    } catch (_) {
      if (mounted) IlndToast.error(context, l10n.paywallRestoreFailed);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Premium hep "luxe" hissettirsin: gündüz/gece fark etmeksizin koyu palet.
    const p = AppPalette.dark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        color: p.base,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                12,
                AppSpacing.screenPadding,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Center(child: BreathRing(size: 52)),
                  const SizedBox(height: 18),
                  if (widget.reason != null) ...[
                    Text(
                      widget.reason!,
                      style: AppTextStyles.body(fontSize: 14, color: p.accent),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'ILND+',
                    style: AppTextStyles.display(fontSize: 42, color: p.text),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.paywallSubtitle,
                    style: AppTextStyles.body(
                      fontSize: 15,
                      color: p.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Benefit(
                    title: l10n.paywallBenefitUnlimitedChatTitle,
                    subtitle: l10n.paywallBenefitUnlimitedChatSubtitle,
                    p: p,
                  ),
                  _Benefit(
                    title: l10n.paywallBenefitLongMemoryTitle,
                    subtitle: l10n.paywallBenefitLongMemorySubtitle,
                    p: p,
                  ),
                  _Benefit(
                    title: l10n.paywallBenefitProactiveTitle,
                    subtitle: l10n.paywallBenefitProactiveSubtitle,
                    p: p,
                  ),
                  _Benefit(
                    title: l10n.paywallBenefitPersonalPlanTitle,
                    subtitle: l10n.paywallBenefitPersonalPlanSubtitle,
                    p: p,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radius),
                      border: Border.all(color: p.accent, width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.paywallYearly,
                                style: AppTextStyles.body(
                                  fontSize: 13,
                                  color: p.text,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.paywallFreeTrial,
                                style: AppTextStyles.body(
                                  fontSize: 11.5,
                                  color: p.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: p.accent.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.paywallDiscount,
                            style: AppTextStyles.label(
                              fontSize: 11.5,
                              color: p.accent,
                            ).copyWith(letterSpacing: 0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Pressable(
                    onTap: (_purchasing || _restoring)
                        ? null
                        : () => _purchase(l10n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 54,
                      decoration: BoxDecoration(
                        color: _purchasing
                            ? p.accent.withValues(alpha: 0.5)
                            : p.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: _purchasing
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: p.onAccent,
                              ),
                            )
                          : Text(
                              l10n.paywallStartFreeTrial,
                              style: AppTextStyles.body(
                                fontSize: 15,
                                color: p.onAccent,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Pressable(
                        onTap: () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            l10n.paywallNotNow,
                            style: AppTextStyles.body(
                              fontSize: 13,
                              color: p.textMuted,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        ' · ',
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: p.textMuted,
                        ),
                      ),
                      Pressable(
                        onTap: (_purchasing || _restoring)
                            ? null
                            : () => _restore(l10n),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _restoring
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: p.textMuted,
                                  ),
                                )
                              : Text(
                                  l10n.paywallRestore,
                                  style: AppTextStyles.body(
                                    fontSize: 13,
                                    color: p.textMuted,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.title,
    required this.subtitle,
    required this.p,
  });

  final String title;
  final String subtitle;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    // Kart ya da ikon dairesi yok: faydalar hairline'la ayrılmış satırlar
    // (prototip §11). Dört daire, dört sözü birbirinin kopyası gibi
    // gösteriyordu.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.heading(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: AppTextStyles.body(
                  fontSize: 12.5,
                  color: p.textMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        Container(height: 0.5, color: p.border),
      ],
    );
  }
}
