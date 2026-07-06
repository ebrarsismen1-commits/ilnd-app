import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/breath_ring.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Navigasyon v2 (docs/ilnd_tasarim_vizyonu.md §2):
/// Bugün · Keşfet · [nefes halkası → sohbet] · Topluluk · Sen
///
/// Merkez, ürünün kalbi olan ILND sohbetine aittir — halka bir buton değil,
/// markanın jestidir. Eski [+] (ekle sheet) Bugün ekranının üst çubuğuna
/// taşındı; "Takip" sekmesi kaldırıldı, verisine Sen (profil) içinden
/// erişilir (tam birleşme: roadmap NEXT-4 devamı).
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
        color: p.isDark ? p.base : Colors.white.withValues(alpha: 0.85),
        border: Border(top: BorderSide(color: p.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                p: p,
                icon: Icons.wb_sunny_outlined,
                activeIcon: Icons.wb_sunny_rounded,
                label: l10n.navHome,
                active: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                p: p,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore_rounded,
                label: l10n.navExplore,
                active: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _RingItem(p: p, l10n: l10n),
              _NavItem(
                p: p,
                icon: Icons.people_outline_rounded,
                activeIcon: Icons.people_rounded,
                label: l10n.navCommunity,
                active: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                p: p,
                icon: Icons.person_outline,
                activeIcon: Icons.person_rounded,
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

/// Merkez: sohbete açılan nefes halkası. Sekme değil — her sekmenin
/// üzerinden erişilebilen, markanın kalbine giden kapı.
class _RingItem extends StatelessWidget {
  const _RingItem({required this.p, required this.l10n});
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: () => context.push(routeChat),
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                button: true,
                label: l10n.a11yOpenChat,
                child: const BreathRing(size: 44),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.navRing,
                style: AppTextStyles.body(
                  fontSize: 9.5,
                  color: p.accent,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
              ),
            ],
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
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final AppPalette p;
  final IconData icon;
  final IconData activeIcon;
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
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.28, end: 0.90), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.0), weight: 30),
  ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOut));

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (!old.active && widget.active) {
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
      child: Pressable(
        onTap: widget.onTap,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _scale,
                builder: (context, child) => Transform.scale(
                  scale: widget.active ? _scale.value : 1.0,
                  child: child,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.active ? 12 : 0,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.active
                        ? p.accent.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    widget.active ? widget.activeIcon : widget.icon,
                    color: color,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppTextStyles.label(fontSize: 10, color: color).copyWith(
                  letterSpacing: 0,
                  fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
