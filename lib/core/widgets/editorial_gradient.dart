import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_colors.dart';

/// Görsel asset olmadan editoryal, dergi-benzeri arka planlar üretir.
///
/// Marka paletinden küratörlü, katmanlı degrade kompozisyonları. Gerçek
/// fotoğraflar gelene kadar kapak görseli yerine geçer; ilk izlenimi
/// "sıradan değil" hissine taşır.
class EditorialGradient extends StatelessWidget {
  const EditorialGradient({super.key, this.palette = 0});

  /// Hangi küratörlü paletin kullanılacağı.
  final int palette;

  static const List<List<Color>> _palettes = [
    // 0 — sage → derin yeşil (sakinlik)
    [Color(0xFF8FB07E), Color(0xFF6B8F5E), Color(0xFF3E5938)],
    // 1 — amber → terracotta (sıcaklık)
    [Color(0xFFE8C9A0), Color(0xFFC4956A), Color(0xFF8A5E3C)],
    // 2 — cream → sage (yumuşak)
    [Color(0xFFEDE8DF), Color(0xFFA8C49A), Color(0xFF6B8F5E)],
    // 3 — dusk: amber → charcoal (derinlik)
    [Color(0xFFC4956A), Color(0xFF7E7466), Color(0xFF2C2C2A)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _palettes[palette % _palettes.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Yumuşak ışık lekesi — organik derinlik
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.white.withValues(alpha: 0.22),
                    AppColors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.last.withValues(alpha: 0.45),
                    colors.last.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
