import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/explore/discover_article_card.dart';

/// "Bugün senin için" — Keşfet'in günlük yatay rafı.
///
/// Hangi yazıların gireceği rafın değil ekranın kararıdır (seçim
/// `pickDaily`, süzgeç ekranda): raf yalnız dizer. Böylece aynı düzen başka
/// bir listeyle de kullanılabilir.
///
/// Fizik BİLEREK verilmedi: `physics` atanırsa iOS'ta zıplama, Android'de
/// clamp davranışı elle taklit edilmiş olurdu. Flutter varsayılanı zaten
/// platforma göre doğru olanı seçiyor.
class DiscoverCarousel extends StatelessWidget {
  const DiscoverCarousel({
    super.key,
    required this.title,
    required this.articles,
    required this.p,
    required this.onOpen,
  });

  /// Bölüm başlığı. ALL CAPS etiket değil, serif bir editoryal satır: bu raf
  /// ekranın kişisel anı, etiket rafı gibi okunmamalı.
  final String title;

  final List<Article> articles;
  final AppPalette p;
  final void Function(Article) onOpen;

  @override
  Widget build(BuildContext context) {
    // Boş raf çizilmez: olmayan bir bölümün başlığı, verilmemiş bir söz.
    if (articles.isEmpty) return const SizedBox.shrink();

    // Yumuşak tonlar sırayla döner; havuz tükenirse başa sarar. Ton yazının
    // kendisinden değil sıradan gelir, yani liste değiştiğinde raf yine
    // dengeli görünür.
    final tints = p.insight.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Text(
            title,
            style: AppTextStyles.heading(fontSize: 20, color: p.text),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          // Yükseklik kartla aynı kaynaktan gelir; iki ayrı sayı olsaydı
          // metin ölçeği büyüdüğünde kart raftan taşardı.
          height: DiscoverCardMetrics.height(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            // Sağdaki kartın ucu görünsün diye kenar dolgusu ekran
            // dolgusuyla aynı: son kart da kenara yapışmaz.
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            itemCount: articles.length,
            separatorBuilder: (ctx0, i0) =>
                const SizedBox(width: DiscoverCardMetrics.gap),
            itemBuilder: (context, i) => Entrance(
              index: i,
              child: DiscoverArticleCard(
                article: articles[i],
                p: p,
                tint: tints[i % tints.length],
                onTap: () => onOpen(articles[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
