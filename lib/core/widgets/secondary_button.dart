import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';

/// İkincil eylem düğmesi: dolu değil, 0.5px vurgu çerçeveli.
///
/// Yemek ekleme ekranının içinde özel bir sınıftı; malzeme editörü oradan
/// çıkıp kayıtlı öğün düzeltmesinde de kullanılınca ikinci bir kopya çıkarmak
/// yerine paylaşılan yere taşındı.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.p,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.accent, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: p.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.body(
                fontSize: 15,
                color: p.accent,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
