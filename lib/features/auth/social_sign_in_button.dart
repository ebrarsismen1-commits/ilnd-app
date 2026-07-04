import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';

enum SocialProvider { google, apple }

/// Branded outline button for Google/Apple sign-in — deliberately not the
/// stock colored Google button or a plain Material `OutlinedButton.icon`,
/// so it sits inside the app's own visual language instead of looking
/// bolted-on.
class SocialSignInButton extends ConsumerWidget {
  const SocialSignInButton({
    super.key,
    required this.provider,
    required this.label,
    this.onTap,
  });

  final SocialProvider provider;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(paletteProvider);

    return Pressable(
      onTap: onTap,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: p.surfaceStrong,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.border, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ProviderMark(provider: provider, color: p.text),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTextStyles.body(
                fontSize: 14,
                color: p.text,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small monogram mark — avoids bundling third-party brand SVGs while still
/// reading unambiguously as "Google" / "Apple" at a glance.
class _ProviderMark extends StatelessWidget {
  const _ProviderMark({required this.provider, required this.color});

  final SocialProvider provider;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (provider == SocialProvider.apple) {
      return Icon(Icons.apple_rounded, size: 20, color: color);
    }
    // Google's mark is multi-color by brand guideline; a flat "G" monogram
    // keeps the button inside our single-accent palette instead of
    // injecting Google's blue/red/yellow/green into an otherwise calm UI.
    return Text(
      'G',
      style: AppTextStyles.display(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

/// "veya" / "or" divider between email form and social buttons.
class AuthDivider extends ConsumerWidget {
  const AuthDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(paletteProvider);
    return Row(
      children: [
        Expanded(child: Divider(color: p.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: AppTextStyles.body(fontSize: 12, color: p.textMuted),
          ),
        ),
        Expanded(child: Divider(color: p.border, height: 1)),
      ],
    );
  }
}
