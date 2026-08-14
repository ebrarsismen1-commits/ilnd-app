import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Adım adım pişirme modu: her adım tek ekran, mutfakta uzaktan okunacak
/// büyüklükte yazı. Ritüel koşucusuyla aynı dil (ilerleme + AnimatedSwitcher).
class CookingModeScreen extends ConsumerStatefulWidget {
  const CookingModeScreen({super.key, required this.article});

  final Article article;

  @override
  ConsumerState<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends ConsumerState<CookingModeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final steps = widget.article.steps;
    final isLast = _index == steps.length - 1;

    return Scaffold(
      backgroundColor: p.base,
      appBar: AppBar(
        backgroundColor: p.base,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: p.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.article.title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w300,
            color: p.text,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                l10n.recipeStepProgress(_index + 1, steps.length),
                style: AppTextStyles.label(fontSize: 11.5, color: p.textMuted),
              ),
              const SizedBox(height: 10),
              // İlerleme çizgisi: tamamlanan adımlar dolar.
              Row(
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i <= _index
                              ? p.accent
                              : p.accent.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    if (i < steps.length - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOut,
                  child: Column(
                    key: ValueKey(_index),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Büyük adım numarası — göz atınca neredeyim sorusunun
                      // cevabı.
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.accentSoft,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${_index + 1}',
                          style: AppTextStyles.display(
                            fontSize: 24,
                            color: p.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        steps[_index],
                        textAlign: TextAlign.center,
                        style: AppTextStyles.display(
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          color: p.text,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  if (_index > 0) ...[
                    Pressable(
                      onTap: () => setState(() => _index--),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.border),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: p.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Pressable(
                      onTap: () {
                        if (isLast) {
                          Navigator.of(context).pop();
                        } else {
                          setState(() => _index++);
                        }
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: p.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isLast
                              ? l10n.recipeFinishButton
                              : l10n.recipeNextButton,
                          style: AppTextStyles.body(
                            fontSize: 15,
                            color: p.onAccent,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
