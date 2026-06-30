import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/features/legal/legal_content.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Gizlilik Politikası ve Kullanım Şartları için ortak görüntüleme ekranı.
/// Apple/Google App Privacy gereksinimleri için uygulama içinden erişilebilir
/// olmaları zorunlu — bu ekran auth/onboarding durumundan bağımsız olarak
/// `app_router.dart`'taki redirect mantığında özel olarak izinli.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.title, required this.body});

  final String title;
  final String body;

  static const privacyPolicy = LegalScreen(
    title: 'Gizlilik Politikası',
    body: LegalContent.privacyPolicy,
  );

  static const termsOfService = LegalScreen(
    title: 'Kullanım Şartları',
    body: LegalContent.termsOfService,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);

    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_back_rounded, color: p.text),
                      tooltip: l10n.legalBackTooltip,
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.heading(
                          fontSize: 18,
                          color: p.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    12,
                    AppSpacing.screenPadding,
                    32,
                  ),
                  child: Text(
                    body,
                    style: AppTextStyles.body(
                      fontSize: 14,
                      color: p.text,
                    ).copyWith(height: 1.6),
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
