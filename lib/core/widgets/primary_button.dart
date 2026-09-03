import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';

/// Birincil eylem düğmesi: vurgu renginde dolu.
///
/// [SecondaryButton] ile birlikte yemek ekleme ekranından çıkarıldı — kayıtlı
/// öğün düzeltmesi de aynı ikiliyi kullanıyor (dolu = bedava kaydet,
/// çerçeveli = ücretli yeniden hesapla).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
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
          color: p.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: p.onAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.body(
                fontSize: 15,
                color: p.onAccent,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
