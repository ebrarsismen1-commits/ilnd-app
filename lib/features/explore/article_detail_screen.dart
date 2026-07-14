import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/cover_image.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/explore/cooking_mode_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Editoryal okuma sayfası — kapak fotoğrafı + başlık + gövde.
class ArticleDetailScreen extends ConsumerWidget {
  const ArticleDetailScreen({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);

    return Scaffold(
      backgroundColor: p.base,
      body: CustomScrollView(
        slivers: [
          // ── Cover ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Stack(
              children: [
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: CoverImage(
                    imageUrl: article.imageUrl,
                    palette: article.category.palette,
                  ),
                ),
                // Readability scrim at top for the back button
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Semantics(
                      button: true,
                      label: l10n.a11yBack,
                      child: Pressable(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              24,
              AppSpacing.screenPadding,
              48,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                Row(
                  children: [
                    Text(
                      article.category.tag.toUpperCase(),
                      style: AppTextStyles.label(fontSize: 11, color: p.accent),
                    ),
                    Text(
                      l10n.articleDetailReadTime(article.readTime),
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  article.title,
                  style: AppTextStyles.display(
                    fontSize: 32,
                    color: p.text,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  article.excerpt,
                  style: AppTextStyles.body(
                    fontSize: 16,
                    color: p.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Divider(height: 32, color: p.border),
                for (final paragraph in article.body) ...[
                  Text(
                    paragraph,
                    style: AppTextStyles.body(
                      fontSize: 16,
                      color: p.text,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                // Tarif makaleleri interaktiftir: tik'lenebilir malzeme
                // listesi + adım adım pişirme modu.
                if (article.isRecipe) ...[
                  const SizedBox(height: 8),
                  _RecipeSection(article: article, p: p),
                ],
                const SizedBox(height: 12),
                // Soft sign-off
                Center(
                  child: Text(
                    l10n.articleDetailSignOff,
                    style: AppTextStyles.display(
                      fontSize: 18,
                      color: p.textMuted,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tarif bölümü ─────────────────────────────────────────────────────────────

/// Malzemeler tik'lenerek toplanır (yerel durum, kaydedilmez); ardından
/// tam ekran pişirme moduna geçilir.
class _RecipeSection extends StatefulWidget {
  const _RecipeSection({required this.article, required this.p});

  final Article article;
  final AppPalette p;

  @override
  State<_RecipeSection> createState() => _RecipeSectionState();
}

class _RecipeSectionState extends State<_RecipeSection> {
  final _checked = <int>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = widget.p;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recipeIngredientsTitle,
          style: AppTextStyles.label(fontSize: 11, color: p.accent),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border, width: 0.5),
          ),
          child: Column(
            children: [
              for (final (i, item) in widget.article.ingredients.indexed)
                Pressable(
                  onTap: () => setState(() {
                    _checked.contains(i) ? _checked.remove(i) : _checked.add(i);
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        Icon(
                          _checked.contains(i)
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 20,
                          color: _checked.contains(i) ? p.accent : p.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item,
                            style: AppTextStyles.body(
                              fontSize: 15,
                              color: _checked.contains(i)
                                  ? p.textMuted
                                  : p.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Pressable(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CookingModeScreen(article: widget.article),
            ),
          ),
          child: Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, size: 22, color: p.onAccent),
                const SizedBox(width: 6),
                Text(
                  l10n.recipeStartCooking,
                  style: AppTextStyles.body(
                    fontSize: 15,
                    color: p.onAccent,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
