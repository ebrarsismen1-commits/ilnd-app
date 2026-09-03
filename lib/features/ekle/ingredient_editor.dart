import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/core/widgets/secondary_button.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

// ─── Malzeme editörü ─────────────────────────────────────────────────────────

/// Malzemeler artık salt okunur bir liste değil: AI yanlış gördüyse ya da
/// kullanıcı elle eklediyse liste düzeltilebilir. Düzeltme makroları
/// kendiliğinden değiştirmez; yeniden hesaplama bir analiz çağrısıdır ve
/// haftalık haktan düştüğü için kullanıcının açık onayıyla çalışır.
class IngredientEditor extends StatefulWidget {
  const IngredientEditor({
    super.key,
    required this.ingredients,
    required this.onAdd,
    required this.onRemove,
    required this.onRecalculate,
    required this.macrosStale,
    required this.recalculating,
    required this.p,
    required this.l10n,
  });

  final List<String> ingredients;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final VoidCallback onRecalculate;
  final bool macrosStale;
  final bool recalculating;
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  State<IngredientEditor> createState() => _IngredientEditorState();
}

class _IngredientEditorState extends State<IngredientEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text;
    if (value.trim().isEmpty) return;
    widget.onAdd(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final l10n = widget.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.ingredients.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.ingredients
                      .map(
                        (m) => Container(
                          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                          decoration: BoxDecoration(
                            color: p.amber.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                m,
                                style: AppTextStyles.label(
                                  fontSize: 11.5,
                                  color: p.amber,
                                ).copyWith(letterSpacing: 0),
                              ),
                              const SizedBox(width: 4),
                              Semantics(
                                button: true,
                                label: l10n.yemekEkleIngredientRemove(m),
                                child: Pressable(
                                  onTap: () => widget.onRemove(m),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: p.amber,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              if (widget.ingredients.isNotEmpty) const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        style: AppTextStyles.body(fontSize: 14, color: p.text),
                        decoration: InputDecoration(
                          hintText: l10n.yemekEkleIngredientHint,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: l10n.yemekEkleIngredientAdd,
                    child: Pressable(
                      onTap: _submit,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: p.surfaceStrong,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.add_rounded, size: 20, color: p.text),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (widget.macrosStale || widget.recalculating) ...[
          const SizedBox(height: 12),
          Text(
            l10n.yemekEkleRecalculateHint,
            style: AppTextStyles.body(
              fontSize: 11.5,
              color: p.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          if (widget.recalculating)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.amber,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.yemekEkleRecalculating,
                  style: AppTextStyles.body(fontSize: 12.5, color: p.textMuted),
                ),
              ],
            )
          else
            SecondaryButton(
              icon: Icons.calculate_outlined,
              label: l10n.yemekEkleRecalculate,
              onTap: widget.onRecalculate,
              p: p,
            ),
        ],
      ],
    );
  }
}
