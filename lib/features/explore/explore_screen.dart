import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/breath_animation.dart';
import 'package:ilnd_app/core/widgets/cover_image.dart';
import 'package:ilnd_app/core/widgets/entrance.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/core/repositories/explore_repository.dart';
import 'package:ilnd_app/features/explore/article_detail_screen.dart';
import 'package:ilnd_app/features/explore/article_model.dart';

// ─── Filter ───────────────────────────────────────────────────────────────────

enum _Filter { hepsi, wellness, tarifler, yazilar }

extension _FilterX on _Filter {
  String get label => switch (this) {
        _Filter.hepsi => 'Hepsi',
        _Filter.wellness => 'Wellness',
        _Filter.tarifler => 'Tarifler',
        _Filter.yazilar => 'Yazılar',
      };

  bool matches(Article a) => switch (this) {
        _Filter.hepsi => true,
        _Filter.wellness => a.category == ArticleCategory.wellness,
        _Filter.tarifler => a.category == ArticleCategory.tarif,
        _Filter.yazilar => a.category == ArticleCategory.yazi,
      };
}

// ─── Story config ─────────────────────────────────────────────────────────────

class _Story {
  const _Story(this.label, this.emoji, this.color);
  final String label;
  final String emoji;
  final Color color;
}

const _stories = [
  _Story('nefes', '🌬️', Color(0xFFB8A9FF)),
  _Story('uyku', '🌙', Color(0xFF9BB5FF)),
  _Story('su', '💧', Color(0xFF93D5FF)),
  _Story('hareket', '⚡', Color(0xFFA8EDCA)),
  _Story('meditasyon', '✨', Color(0xFFFFB8D9)),
  _Story('öz-bakım', '🌸', Color(0xFFFFCBA4)),
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
      PageRouteBuilder<void>(
        pageBuilder: (ctx, anim, _) => ArticleDetailScreen(article: a),
        transitionsBuilder: (ctx, anim, _, child) {
          final c = CurvedAnimation(parent: anim, curve: Curves.easeOutQuart);
          return FadeTransition(
            opacity: c,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.05), end: Offset.zero)
                  .animate(c),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(paletteProvider);
    final _raw = ref.watch(articlesProvider).valueOrNull;
    final allArticles = (_raw == null || _raw.isEmpty) ? kArticles : _raw;
    final hero = allArticles.isNotEmpty ? allArticles.first : null;
    final featured =
        allArticles.length > 1 ? allArticles.sublist(1, allArticles.length.clamp(1, 4)) : <Article>[];
    final rest = allArticles.length > 4 ? allArticles.sublist(4) : <Article>[];
    final filtered = rest.where((a) => _selected.matches(a)).toList();

    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Header ────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding, 28, AppSpacing.screenPadding, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('keşfet.',
                                style: AppTextStyles.display(
                                    fontSize: 32, color: p.text)),
                            const SizedBox(height: 2),
                            Text('iyi hissetmenin küçük adımları',
                                style: AppTextStyles.body(
                                    fontSize: 13, color: p.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Stories ───────────────────────────────────────────────────
              SliverToBoxAdapter(child: _StoriesRow(p: p)),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── Hero card ─────────────────────────────────────────────────
              if (hero != null) ...[
                SliverToBoxAdapter(
                  child: Entrance(
                    index: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding),
                      child: _HeroCard(article: hero, p: p, onTap: _open),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // ── "Öne çıkanlar" 2-column grid ──────────────────────────────
              if (featured.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPadding, 0, AppSpacing.screenPadding, 12),
                    child: Row(
                      children: [
                        Text('ÖNE ÇIKANLAR',
                            style: AppTextStyles.label(
                                fontSize: 11, color: p.accent)),
                        const Spacer(),
                        Text('hepsi →',
                            style: AppTextStyles.body(
                                fontSize: 12, color: p.textMuted)),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding),
                      itemCount: featured.length,
                      separatorBuilder: (ctx0, i0) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => Entrance(
                        index: i + 1,
                        child: _FeaturedCard(
                            article: featured[i], p: p, onTap: _open),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],

              // ── Günün alıntısı ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Entrance(
                  index: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding),
                    child: _QuoteBanner(p: p),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── Filter pills ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding),
                    children: _Filter.values.map((f) {
                      final active = _selected == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Pressable(
                          onTap: () => setState(() => _selected = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: active
                                  ? p.accent
                                  : p.surface.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color:
                                      active ? p.accent : p.border,
                                  width: 0.5),
                            ),
                            child: Text(
                              f.label,
                              style: AppTextStyles.label(
                                fontSize: 12,
                                color: active ? p.onAccent : p.textMuted,
                              ).copyWith(
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400,
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

              // ── Feed ──────────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding, 0, AppSpacing.screenPadding, 40),
                sliver: filtered.isEmpty
                    ? const SliverToBoxAdapter(child: SizedBox.shrink())
                    : SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (ctx0, i0) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) => Entrance(
                          index: i,
                          delayStep: const Duration(milliseconds: 60),
                          child: _FeedRow(
                              article: filtered[i], p: p, onTap: _open),
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

// ─── Stories ──────────────────────────────────────────────────────────────────

class _StoriesRow extends StatelessWidget {
  const _StoriesRow({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding),
        itemCount: _stories.length,
        separatorBuilder: (ctx0, i0) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final s = _stories[i];
          return Pressable(
            onTap: () {
              if (s.label == 'nefes') {
                Navigator.of(context).push(
                  PageRouteBuilder<void>(
                    pageBuilder: (ctx, anim, _) => BreathScreen(p: p),
                    transitionsBuilder: (ctx, anim, _, child) {
                      final c = CurvedAnimation(
                          parent: anim, curve: Curves.easeOutCubic);
                      return FadeTransition(
                        opacity: c,
                        child: ScaleTransition(
                          scale:
                              Tween(begin: 0.92, end: 1.0).animate(c),
                          child: child,
                        ),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 350),
                  ),
                );
              }
            },
            child: SizedBox(
              width: 70,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          s.color.withValues(alpha: 0.9),
                          s.color.withValues(alpha: 0.5),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: s.color.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(s.emoji,
                          style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.label,
                    style: AppTextStyles.body(
                        fontSize: 11, color: p.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
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

// ─── Hero card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard(
      {required this.article, required this.p, required this.onTap});
  final Article article;
  final AppPalette p;
  final void Function(Article) onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => onTap(article),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 260,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // fotoğraf
              CoverImage(
                  imageUrl: article.imageUrl,
                  palette: article.category.palette),
              // gradient overlay
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.3, 0.6, 1.0],
                  ),
                ),
              ),
              // içerik
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // üst: kategori chip
                    Row(
                      children: [
                        _CategoryChip(article.category),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(article.readTime,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                    // alt: başlık + excerpt
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          article.excerpt,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Featured card (horizontal scroll) ───────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard(
      {required this.article, required this.p, required this.onTap});
  final Article article;
  final AppPalette p;
  final void Function(Article) onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => onTap(article),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 160,
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CoverImage(
                  imageUrl: article.imageUrl,
                  palette: article.category.palette),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                    stops: const [0.35, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CategoryChip(article.category),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          article.readTime,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
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
      ),
    );
  }
}

// ─── Quote banner ─────────────────────────────────────────────────────────────

class _QuoteBanner extends StatelessWidget {
  const _QuoteBanner({required this.p});
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            p.accent.withValues(alpha: 0.12),
            p.amber.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.accent.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Text('✨',
              style: TextStyle(fontSize: 28, shadows: [
                Shadow(color: p.accent.withValues(alpha: 0.4), blurRadius: 8)
              ])),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İyi hissetmek bir tesadüf değil, bir pratik.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'her gün biraz, tutarlılıkla.',
                  style:
                      TextStyle(fontSize: 12, color: p.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(this.category);
  final ArticleCategory category;

  Color get _color => switch (category) {
        ArticleCategory.wellness => const Color(0xFF9B87F5),
        ArticleCategory.tarif => const Color(0xFF34D399),
        ArticleCategory.yazi => const Color(0xFFF472B6),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category.tag.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Feed row ─────────────────────────────────────────────────────────────────

class _FeedRow extends StatelessWidget {
  const _FeedRow(
      {required this.article, required this.p, required this.onTap});
  final Article article;
  final AppPalette p;
  final void Function(Article) onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => onTap(article),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: CoverImage(
                    imageUrl: article.imageUrl,
                    palette: article.category.palette),
              ),
            ),
            const SizedBox(width: 14),
            // text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryChip(article.category),
                  const SizedBox(height: 5),
                  Text(
                    article.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    article.excerpt,
                    style: TextStyle(
                        fontSize: 12, color: p.textMuted, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    article.readTime,
                    style: TextStyle(fontSize: 11, color: p.accent),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}
