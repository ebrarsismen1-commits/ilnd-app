import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/utils/validators.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/auth/auth_error_l10n.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/auth/shared_input_field.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Şifre sıfırlama linkinden gelen kullanıcının YENİ şifresini belirlediği
/// ekran. Router, [AuthPasswordRecovery] durumunda kullanıcıyı buraya
/// kilitler; başarı sonrası state [AuthAuthenticated]'a döner ve router
/// olağan akışa (hidratlama → home) devam eder.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _passwordError = false;
  bool _confirmError = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations l10n) async {
    final passwordErr = Validators.password(_passwordCtrl.text, l10n);
    final confirmErr = Validators.passwordConfirm(
      _confirmCtrl.text,
      _passwordCtrl.text,
      l10n,
    );
    setState(() {
      _passwordError = passwordErr != null;
      _confirmError = confirmErr != null;
    });
    final localErr = passwordErr ?? confirmErr;
    if (localErr != null) {
      IlndToast.error(context, localErr);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .updatePassword(_passwordCtrl.text);
      if (!mounted) return;
      IlndToast.success(context, l10n.newPasswordSuccess);
      // Yönlendirme router'a kalır: state Authenticated'a döndü, redirect
      // kullanıcıyı olağan akışa (hidratlama → home) taşır.
    } on AuthErrorCode catch (code) {
      if (!mounted) return;
      IlndToast.error(context, code.localized(l10n));
    } catch (_) {
      if (!mounted) return;
      IlndToast.error(context, l10n.authErrorGeneric);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);

    return Scaffold(
      backgroundColor: p.base,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 72),
              Text(
                'ilnd.',
                style: AppTextStyles.display(fontSize: 44, color: p.text),
              ),
              const SizedBox(height: 28),
              Text(
                l10n.newPasswordTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.display(fontSize: 24, color: p.text),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.newPasswordSubtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 13, color: p.textMuted),
              ),
              const SizedBox(height: 32),
              AuthInputField(
                controller: _passwordCtrl,
                hint: l10n.newPasswordHint,
                icon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                hasError: _passwordError,
                onChanged: (_) {
                  if (_passwordError) setState(() => _passwordError = false);
                },
                trailing: Pressable(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: p.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AuthInputField(
                controller: _confirmCtrl,
                hint: l10n.newPasswordConfirmHint,
                icon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(l10n),
                hasError: _confirmError,
                onChanged: (_) {
                  if (_confirmError) setState(() => _confirmError = false);
                },
              ),
              const SizedBox(height: 24),
              Pressable(
                onTap: _saving ? null : () => _submit(l10n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _saving ? p.accent.withValues(alpha: 0.5) : p.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.onAccent,
                          ),
                        )
                      : Text(
                          l10n.newPasswordSubmit,
                          style: AppTextStyles.body(
                            fontSize: 15,
                            color: p.onAccent,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
