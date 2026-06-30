import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/repositories/checkin_repository.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';

/// Anonim, agregat sosyal kanıt rozeti: "Bu hafta N kişi kendine vakit
/// ayırdı." Sayı yoksa veya sorgu başarısızsa hiçbir şey göstermez —
/// boş/garip bir UI'dan iyidir.
///
/// [p] verilirse [AppPalette] renkleri kullanılır (ana uygulama ekranları);
/// verilmezse statik [AppColors] kullanılır (onboarding, auth öncesi).
class SocialProofBadge extends ConsumerWidget {
  const SocialProofBadge({super.key, this.p});
  final AppPalette? p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(weeklyCheckinCountProvider).valueOrNull;
    if (count == null || count <= 0) return const SizedBox.shrink();

    final textColor = p?.textMuted ?? AppColors.muted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Text('✦ ', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Text(
              'Bu hafta $count kişi kendine vakit ayırdı.',
              style: AppTextStyles.body(fontSize: 12, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
