import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/billing/entitlement.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';

/// ILND+ tanıtım ekranı. Limit aşımında veya profilden açılır.
///
/// [reason] varsa başlıkta nazik bir bağlam gösterir
/// (ör. "bu hafta benimle çok konuştun").
class PaywallScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
            const Positioned.fill(child: AnimatedBackground(palette: p)),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding, 12, AppSpacing.screenPadding, 28),
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
                  if (reason != null) ...[
                    Text(reason!, style: AppTextStyles.body(fontSize: 14, color: p.accent)),
                    const SizedBox(height: 8),
                  ],
                  Text('ILND+', style: AppTextStyles.display(fontSize: 40, color: p.text)),
                  const SizedBox(height: 6),
                  Text(
                    'sınırsız, seni gerçekten hatırlayan bir ILND.',
                    style: AppTextStyles.body(fontSize: 15, color: p.textMuted, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const _Benefit(
                    icon: Icons.all_inclusive_rounded,
                    title: 'sınırsız sohbet & analiz',
                    subtitle: 'haftalık limit yok, istediğin kadar konuş',
                    p: p,
                  ),
                  const _Benefit(
                    icon: Icons.psychology_outlined,
                    title: 'uzun hafıza',
                    subtitle: 'ILND geçmişini gerçekten hatırlar',
                    p: p,
                  ),
                  const _Benefit(
                    icon: Icons.favorite_border_rounded,
                    title: 'proaktif ILND',
                    subtitle: 'sana kendi gelir, hatırlatır, sorar',
                    p: p,
                  ),
                  const _Benefit(
                    icon: Icons.map_outlined,
                    title: 'kişisel plan',
                    subtitle: 'sana özel diyet & koçluk yol haritası',
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
                              Text('yıllık',
                                  style: AppTextStyles.body(fontSize: 14, color: p.text)
                                      .copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('7 gün ücretsiz dene',
                                  style: AppTextStyles.body(fontSize: 12, color: p.textMuted)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.accent.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('−%40',
                              style: AppTextStyles.label(fontSize: 11, color: p.accent)
                                  .copyWith(letterSpacing: 0)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Pressable(
                    onTap: () async {
                      await ref.read(isPremiumProvider.notifier).setPremium(true);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text('ücretsiz denemeyi başlat',
                          style: AppTextStyles.body(fontSize: 15, color: p.onAccent)
                              .copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Pressable(
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('şimdi değil',
                            style: AppTextStyles.body(fontSize: 14, color: p.textMuted)),
                      ),
                    ),
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
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.p,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: p.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.body(fontSize: 15, color: p.text)
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTextStyles.body(fontSize: 13, color: p.textMuted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
