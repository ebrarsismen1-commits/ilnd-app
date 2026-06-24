import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/ekle/ekle_sheet.dart';

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
        onAddTap: () => showEkleSheet(context),
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
    required this.onAddTap,
  });

  final AppPalette p;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: p.isDark ? p.base : Colors.white.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(color: p.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                p: p,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Ana Sayfa',
                active: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                p: p,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore_rounded,
                label: 'Keşfet',
                active: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _AddButton(p: p, onTap: onAddTap),
              _NavItem(
                p: p,
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart_rounded,
                label: 'Takip',
                active: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                p: p,
                icon: Icons.person_outline,
                activeIcon: Icons.person_rounded,
                label: 'Profil',
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

class _AddButton extends StatelessWidget {
  const _AddButton({required this.p, required this.onTap});
  final AppPalette p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: p.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: p.accent.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: p.onAccent,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final color = active ? p.accent : p.textMuted;

    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(active ? activeIcon : icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppTextStyles.label(
                  fontSize: 10,
                  color: color,
                ).copyWith(
                  letterSpacing: 0,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
