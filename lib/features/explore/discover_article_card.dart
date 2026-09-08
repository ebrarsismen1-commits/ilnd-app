import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/cover_image.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/explore/article_model.dart';

/// Keşfet'in "Bugün senin için" rafındaki dikey yazı kartları.
///
/// Kart bu ekranda bir istisnadır, kural değil: DESIGN_SYSTEM §7.1 içerik
/// kartını yasaklar ("kutu hastalığı"), ama yatay raflar (ritüeller, planlar,
/// hareket) zaten kartla çalışıyor çünkü yan yana duran öğelerin sınırı
/// boşlukla anlatılamıyor. Material Card DEĞİL: gölge yok, zemin paletten
/// gelen çok açık bir ton, ayrım 0.5px hairline.
///
/// Kartın içeriği uydurulmuş bir "içgörü" değil, hattaki gerçek yazıdır:
/// kapak, kategori, başlık, okuma süresi. Rafın vaadi ile dokunuşun götürdüğü
/// yer aynı olmalı.

/// Kart geometrisi. Tek cihazda sabitlenmiş piksel yok: genişlik viewport'un
/// oranından türer, yükseklik genişlikten, ikisi de kırpılır. Sağdaki kartın
/// ucunun görünmesi (kaydırılabilirlik işareti) bu orandan gelir.
class DiscoverCardMetrics {
  const DiscoverCardMetrics._();

  /// Kartlar arası boşluk.
  static const double gap = 14;

  /// Köşe yarıçapı. Standart kart yarıçapından (16) belirgin şekilde büyük:
  /// yumuşaklık bu rafın imzası.
  static const double radius = 24;

  static double width(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 0.42).clamp(150.0, 175.0);

  /// Yükseklik genişliğin oranıdır, sonra metin ölçeğiyle büyür.
  ///
  /// Dynamic Type açık bir kullanıcıda sabit yükseklik taşma demekti
  /// (Sert Kural #14: kart sabit boyut varsayamaz). Ölçek 1.5'te kırpılır;
  /// üstünü kapağın esnemesi ve başlıktaki `maxLines` + ellipsis karşılar.
  static double height(BuildContext context) {
    final base = (width(context) * 1.24).clamp(190.0, 220.0);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
    return base * scale;
  }
}

/// Tek yazı kartı: üstte tam genişlikte kapak, altta yumuşak zemin üzerinde
/// kategori · başlık · okuma süresi.
///
/// Kapak [Expanded]: metin bloğu doğal boyutunu alır, kalan yer görsele
/// gider. Ters kurulsaydı (görsel sabit, metin esnek) büyük yazı ölçeğinde
/// başlık kırpılırdı; burada önce görsel küçülür, metin bütün kalır.
class DiscoverArticleCard extends StatelessWidget {
  const DiscoverArticleCard({
    super.key,
    required this.article,
    required this.p,
    required this.tint,
    required this.onTap,
  });

  final Article article;
  final AppPalette p;

  /// Zemin — daima [AppPalette.insight] setinden (kural #6).
  final Color tint;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scaleDown: 0.97,
      child: Container(
        width: DiscoverCardMetrics.width(context),
        height: DiscoverCardMetrics.height(context),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(DiscoverCardMetrics.radius),
          // Gölge yok: ayrımı ton farkı ve saç teli kenarlık kuruyor.
          border: Border.all(color: p.border, width: 0.5),
        ),
        // Kapak köşelere kadar gider; kırpma kartın kendi yarıçapıyla.
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: CoverImage(
                  imageUrl: article.imageUrl,
                  palette: article.category.palette,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    article.category.tag.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label(
                      fontSize: 9.5,
                      color: p.accent,
                      letterSpacingEm: 0.12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.heading(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: p.text,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.readTime,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.mono(
                      fontSize: 10.5,
                      color: p.textMuted,
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
