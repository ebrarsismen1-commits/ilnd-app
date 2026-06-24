import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/cover_image.dart';
import 'package:ilnd_app/core/widgets/editorial_gradient.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/core/repositories/explore_repository.dart';
import 'package:ilnd_app/features/explore/article_detail_screen.dart';
import 'package:ilnd_app/features/explore/article_model.dart';

// ─── Filter ───────────────────────────────────────────────────────────────────

enum _Filter { hepsi, tarifler, yazilar, wellness }

extension _FilterX on _Filter {
  String get label => switch (this) {
        _Filter.hepsi => 'Hepsi',
        _Filter.tarifler => 'Tarifler',
        _Filter.yazilar => 'Yazılar',
        _Filter.wellness => 'Wellness',
      };

  bool matches(Article a) => switch (this) {
        _Filter.hepsi => true,
        _Filter.tarifler => a.category == ArticleCategory.tarif,
        _Filter.yazilar => a.category == ArticleCategory.yazi,
        _Filter.wellness => a.category == ArticleCategory.wellness,
      };
}

// ─── Stories ──────────────────────────────────────────────────────────────────

class _Story {
  const _Story(this.label, this.icon, this.palette);
  final String label;
  final IconData icon;
  final int palette;
}

const _stories = [
  _Story('nefes', Icons.air_rounded, 0),
  _Story('uyku', Icons.nightlight_round, 3),
  _Story('su', Icons.water_drop_outlined, 2),
  _Story('stres', Icons.spa_outlined, 0),
  _Story('hareket', Icons.directions_walk_rounded, 1),
  _Story('öz-bakım', Icons.favorite_border_rounded, 1),
];

// ─── Screen ──────────────────────────────────────────────────────────────────

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  _Filter _selected = _Filter.hepsi;

  void _open(Article a) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ArticleDetailScreen(article: a)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(paletteProvider);
    final allArticles = ref.watch(articlesProvider).valueOrNull ?? kArticles;
    final filtered = allArticles.where((a) => _selected.matches(a)).toList();
    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding, 28, AppSpacing.screenPadding, 16),
                  child: Text('keşfet.',
                      style: AppTextStyles.display(fontSize: 32, color: p.text)),
                ),
              ),

              // ── Stories ───────────────────────────────────────────────────
              SliverToBoxAdapter(child: _StoriesRow(p: p)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── "Bugün için" carousel ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                  child: Text('BUGÜN İÇİN', style: AppTextStyles.sectionLabel(color: p.accent)),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(child: _FeaturedCarousel(articles: allArticles, p: p, onTap: _open)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── Filter pills ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    children: _Filter.values.map((f) {
                      final active = _selected == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Pressable(
                          onTap: () => setState(() => _selected = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: active ? p.accent : p.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: active ? p.accent : p.border, width: 0.5),
                            ),
                            child: Text(
                              f.label.toUpperCase(),
                              style: AppTextStyles.label(
                                fontSize: 11,
                                color: active ? p.onAccent : p.textMuted,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Compact feed ──────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding, 0, AppSpacing.screenPadding, 32),
                sliver: filtered.isEmpty
                    ? const SliverToBoxAdapter(child: SizedBox.shrink())
                    : SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (ctx2, i2) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => Entrance(
                          index: i,
                          delayStep: const Duration(milliseconds: 55),
                          child: _FeedRow(article: filtered[i], p: p, onTap: _open),
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

// ─── Stories row ──────────────────────────────────────────────────────────────

class _StoriesRow extends StatelessWidget {
  const _StoriesRow({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        itemCount: _stories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final s = _stories[i];
          return Pressable(
            onTap: () {},
            child: SizedBox(
              width: 64,
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: p.accent.withValues(alpha: 0.6), width: 2),
                    ),
                    child: ClipOval(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          EditorialGradient(palette: s.palette),
                          Center(child: Icon(s.icon, size: 24, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.label,
                    style: AppTextStyles.body(fontSize: 11, color: p.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Featured carousel ─────────────────────────────────────────────────────────

class _FeaturedCarousel extends StatelessWidget {
  const _FeaturedCarousel({required this.articles, required this.p, required this.onTap});
  final List<Article> articles;
  final AppPalette p;
  final void Function(Article) onTap;

  @override
  Widget build(BuildContext context) {
    final featured = articles.take(4).toList();
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        itemCount: featured.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final a = featured[i];
          return Pressable(
            onTap: () => onTap(a),
            child: SizedBox(
              width: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverImage(imageUrl: a.imageUrl, palette: a.category.palette),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            style: AppTextStyles.heading(fontSize: 16, color: Colors.white, height: 1.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text('${a.category.tag} · ${a.readTime}',
                              style: AppTextStyles.body(
                                  fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Compact feed row ──────────────────────────────────────────────────────────

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.article, required this.p, required this.onTap});
  final Article article;
  final AppPalette p;
  final void Function(Article) onTap;

  Color get _tagColor => switch (article.category) {
        ArticleCategory.wellness => const Color(0xFF6B8F5E),
        ArticleCategory.tarif => const Color(0xFFC4956A),
        ArticleCategory.yazi => p.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => onTap(article),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border, width: 0.5),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: CoverImage(imageUrl: article.imageUrl, palette: article.category.palette),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: AppTextStyles.heading(
                        fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(article.category.tag.toUpperCase(),
                          style: AppTextStyles.label(fontSize: 10, color: _tagColor)),
                      Text('  ·  ${article.readTime}',
                          style: AppTextStyles.body(fontSize: 11, color: p.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}
