import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/motion.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/ekle/ekle_sheet.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Navigasyon v3 ("Ada" tasarımı, Figma Page 2):
/// Bugün · Keşfet · [Sohbet halkası] · Topluluk · Sen
///
/// Merkez yine ürünün kalbi olan ILND sohbetine aittir, ama artık adıyla:
/// tasarım halkanın altına "Sohbet" yazıyor. Bu yüzden kısa basış doğrudan
/// sohbeti açar. Ekle sheet'i (yemek/günlük/alışkanlık/su) uzun basışa
/// geçti; aynı eylemlerin hepsinin görünür kapısı zaten var: Bugün'deki
/// Günlük ve Takip karoları, Takip ekranındaki öğün/su/alışkanlık satırları.
/// Uzun basış yalnız ikincil bir kısayoldur (bkz. [Pressable.onLongPress]).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(paletteProvider);
    return Scaffold(
      backgroundColor: p.base,
      body: navigationShell,
      bottomNavigationBar: _BottomNav(
        p: p,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

// ─── Bottom nav ───────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.p,
    required this.currentIndex,
    required this.onTap,
  });

  final AppPalette p;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: p.isDark ? p.base : p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          // Keep the normal bar compact; allow two-line accessibility labels.
          height:
              64 +
              (MediaQuery.textScalerOf(context).scale(24) - 24).clamp(
                0,
                double.infinity,
              ),
          child: Row(
            children: [
              _NavItem(
                p: p,
                icon: Icons.wb_sunny_outlined,
                label: l10n.navHome,
                active: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                p: p,
                icon: Icons.explore_outlined,
                label: l10n.navExplore,
                active: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _RingItem(p: p, l10n: l10n),
              _NavItem(
                p: p,
                icon: Icons.people_outline_rounded,
                label: l10n.navCommunity,
                active: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                p: p,
                icon: Icons.person_outline_rounded,
                label: l10n.navYou,
                active: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary action, not a fifth branch. Chat opens above the shell; returning
/// restores the selected branch without introducing a second selection state.
class _RingItem extends StatelessWidget {
  const _RingItem({required this.p, required this.l10n});
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: l10n.a11yOpenIlnd,
        child: Pressable(
          onTap: () => context.push(routeChat),
          onLongPress: () => showEkleSheet(context),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: p.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.accent),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: p.onAccent,
                  ),
                ),
                const SizedBox(height: 3),
                ExcludeSemantics(
                  child: Text(
                    l10n.navRing,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      fontSize: 10,
                      color: p.accent,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.p,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final AppPalette p;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.16), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.16, end: 0.94), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.0), weight: 30),
  ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOut));

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    // Zıplama tamamen dekoratif: sekmenin seçildiğini zaten renk, kalınlık
    // ve hap zemini anlatıyor. "Hareketi azalt" açıkken hiç oynamaz.
    if (!old.active && widget.active && !prefersReducedMotion(context)) {
      _bounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final color = widget.active ? p.accent : p.textMuted;

    return Expanded(
      // Ekran okuyucu hangi sekmede olduğumuzu söylemeli: aktiflik yalnız
      // renkle anlatılamaz.
      child: Semantics(
        button: true,
        selected: widget.active,
        label: widget.label,
        child: Pressable(
          onTap: widget.onTap,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _scale,
                  builder: (context, child) => Transform.scale(
                    scale: widget.active ? _scale.value : 1.0,
                    child: child,
                  ),
                  // Tasarımdaki aktif hap: 48 × 30, halka zemini tonunda.
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: 48,
                    height: 30,
                    decoration: BoxDecoration(
                      color: widget.active
                          ? p.accentSoft
                          : p.accentSoft.withValues(alpha: 0),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    alignment: Alignment.center,
                    child: Icon(widget.icon, color: color, size: 22),
                  ),
                ),
                const SizedBox(height: 3),
                ExcludeSemantics(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style:
                        AppTextStyles.body(
                          fontSize: 10,
                          color: color,
                          height: 1.2,
                        ).copyWith(
                          fontWeight: widget.active
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                    child: Text(
                      widget.label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
