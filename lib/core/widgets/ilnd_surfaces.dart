import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// "Ada" tasarımının (Figma Page 2) ortak yüzeyleri.
///
/// Tasarım her ekranda aynı birkaç parçayı tekrar ediyor: kenarlıklı kağıt
/// kart, Adaçayı ikon karosu, ikonlu liste satırı, hap seçenek, geri oklu
/// sayfa başlığı ve iki tonlu ada çerçevesi. Her ekran bunları kendi
/// kopyasıyla çizseydi köşe ya da kenarlık değeri ilk değişiklikte ekran
/// ekran ayrışırdı (PROJECT_PRINCIPLES #3), o yüzden tek dosyada duruyorlar.
///
/// Ölçüler tasarımdan: kart köşesi 16, kontrol köşesi 14, ana görsel 24,
/// kenarlık 1px `border`, satır ikon karosu 42.

/// Kenarlıklı kağıt kart. [color] verilirse (Adaçayı, Su) kenarlık düşer:
/// tasarımda renkli kartlar kenarlıksız, kağıt kartlar kenarlıklı.
class IlndCard extends StatelessWidget {
  const IlndCard({
    super.key,
    required this.p,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.color,
    this.radius = AppSpacing.radius,
    this.onTap,
    this.onLongPress,
  });

  final AppPalette p;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(radius),
        border: color == null ? Border.all(color: p.border) : null,
      ),
      child: child,
    );
    if (onTap == null && onLongPress == null) return card;
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleDown: 0.98,
      child: card,
    );
  }
}

/// Adaçayı zeminli yuvarlak köşeli ikon karosu (satırlar 42, liste 32).
class IlndIconTile extends StatelessWidget {
  const IlndIconTile({
    super.key,
    required this.p,
    required this.icon,
    this.size = 42,
    this.color,
    this.iconColor,
  });

  final AppPalette p;
  final IconData icon;
  final double size;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? p.surfaceStrong,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.48, color: iconColor ?? p.accent),
    );
  }
}

/// İkon karosu + kalın başlık + alt satır + ok: "Kaydettiklerin",
/// "Öğünlerin", "Adandaki öğeler" satırlarının hepsi bu.
class IlndListRow extends StatelessWidget {
  const IlndListRow({
    super.key,
    required this.p,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.titleColor,
    this.iconColor,
    this.semanticsLabel,
  });

  final AppPalette p;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Varsayılan ok yerine (ör. anahtar ya da durum yazısı).
  final Widget? trailing;
  final Color? titleColor;
  final Color? iconColor;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: IlndCard(
        p: p,
        onTap: onTap,
        onLongPress: onLongPress,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            IlndIconTile(p: p, icon: icon, iconColor: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.rowTitle(color: titleColor ?? p.text),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: p.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                (onTap == null
                    ? const SizedBox.shrink()
                    : Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: p.textMuted,
                      )),
          ],
        ),
      ),
    );
  }
}

/// Hap seçenek: seçili dolu Orman, diğeri kenarlıklı kağıt.
class IlndChip extends StatelessWidget {
  const IlndChip({
    super.key,
    required this.p,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final AppPalette p;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          // 32px görsel yükseklik; dokunma hedefi satırın kendisiyle 44'e
          // tamamlanıyor (çipler hep satır içinde, altlarında boşluk var).
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? p.accent : p.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? p.accent : p.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 12.5,
              color: selected ? p.onAccent : p.textMuted,
              height: 1.2,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

enum IlndButtonKind { primary, secondary, soft }

/// Tasarımın üç butonu: dolu Orman (birincil), kenarlıklı kağıt (ikincil),
/// Adaçayı zeminli yeşil yazı (onaylanmış durum). Yükseklik 52, köşe 14.
class IlndButton extends StatelessWidget {
  const IlndButton({
    super.key,
    required this.p,
    required this.label,
    required this.onTap,
    this.kind = IlndButtonKind.primary,
    this.loading = false,
    this.leading,
  });

  final AppPalette p;
  final String label;
  final VoidCallback? onTap;
  final IlndButtonKind kind;
  final bool loading;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (kind) {
      IlndButtonKind.primary => (p.accent, p.onAccent, null),
      IlndButtonKind.secondary => (p.surface, p.text, p.border),
      IlndButtonKind.soft => (p.surfaceStrong, p.accent, null),
    };
    return Semantics(
      button: true,
      enabled: onTap != null && !loading,
      child: Pressable(
        onTap: loading ? null : onTap,
        scaleDown: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 52),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: loading && kind == IlndButtonKind.primary
                ? bg.withValues(alpha: 0.5)
                : bg,
            borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
            border: border == null ? null : Border.all(color: border),
          ),
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(
                          fontSize: 14.5,
                          color: fg,
                          height: 1.25,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Geri oklu sayfa başlığı: `‹ Takibin` + altında tek satır açıklama.
///
/// Geri öğesi ekran okuyucuya "Geri" diye adlanır; 44px dokunma hedefi.
/// [onBack] verilmezse Navigator'dan bir önceki sayfaya döner. Yaprak
/// olmayan (sekme) ekranlar [showBack]'i false bırakır.
class IlndPageHeader extends StatelessWidget {
  const IlndPageHeader({
    super.key,
    required this.p,
    required this.title,
    this.subtitle,
    this.showBack = true,
    this.onBack,
    this.trailing,
    this.titleSize = 26,
  });

  final AppPalette p;
  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? trailing;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showBack)
              Semantics(
                button: true,
                label: l10n.a11yBack,
                child: Pressable(
                  onTap: onBack ?? () => Navigator.of(context).maybePop(),
                  child: SizedBox(
                    width: 36,
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 28,
                        color: p.text,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.pageTitle(
                  color: p.text,
                  fontSize: titleSize,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
          ),
        ],
      ],
    );
  }
}

/// Adaçayı zeminli pratik kartı: etiket, serif başlık, süre ve yuvarlak ok.
/// Bugün ("bugünün küçük pratiği") ve Keşfet ("sana uygun bir başlangıç")
/// aynı kartı kullanır.
class PracticeCard extends StatelessWidget {
  const PracticeCard({
    super.key,
    required this.p,
    required this.label,
    required this.title,
    required this.meta,
    required this.onTap,
  });

  final AppPalette p;
  final String label;
  final String title;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $meta',
      excludeSemantics: true,
      child: IlndCard(
        p: p,
        color: p.surfaceStrong,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.caption(color: p.textMuted)),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: AppTextStyles.serifTitle(
                      color: p.text,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    style: AppTextStyles.body(fontSize: 14, color: p.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: p.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: p.onAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ada kartı: gökyüzü + deniz iki tonu, üstünde isteğe bağlı içerik.
///
/// İllüstrasyon BİLEREK yok (owner kararı 2026-09-11: "ada çizimlerini
/// şimdilik boş bırak"). Kart yerini ve oranını korur ki çizim geldiğinde
/// tek bir yere, bu widget'ın arka planına girsin; Bugün, Adan, Karşılama,
/// Topluluk ve Odaklan aynı çerçeveyi kullanıyor.
class IslandFrame extends StatelessWidget {
  const IslandFrame({
    super.key,
    required this.p,
    this.height,
    this.radius = AppSpacing.radiusHero,
    this.child,
    this.seaColor,
  });

  final AppPalette p;

  /// null ise ebeveynin verdiği alanı doldurur.
  final double? height;
  final double radius;
  final Widget? child;

  /// Deniz katmanının rengi. Adan'da sessiz günlerde koyulaşan su bu
  /// katmandan anlatılır (ADR-0006); verilmezse `sea`.
  final Color? seaColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              // stretch ŞART: Column varsayılanı (center) çocuklara gevşek
              // genişlik verir ve çocuksuz bir ColoredBox o gevşeklikte
              // sıfır genişliğe düşer — kart görünmez olur (2026-09-12'de
              // tam olarak bu yaşandı, ada kartı boş çizildi).
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 51, child: ColoredBox(color: p.sky)),
                  Expanded(
                    flex: 49,
                    child: ColoredBox(color: seaColor ?? p.sea),
                  ),
                ],
              ),
            ),
            ?child,
          ],
        ),
      ),
    );
  }
}
