import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/utils/validators.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/auth/auth_error_l10n.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/auth/shared_input_field.dart';
import 'package:ilnd_app/features/auth/social_sign_in_button.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  // Per-field error flags — only highlight the field that actually failed.
  bool _emailError = false;
  bool _passwordError = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Returns the first validation error, or null when both fields are valid.
  /// As a side-effect, updates per-field error state so the correct field
  /// turns red.
  String? _validate(AppLocalizations l10n) {
    final emailErr = Validators.email(_emailCtrl.text, l10n);
    final passwordErr = Validators.password(_passwordCtrl.text, l10n);

    setState(() {
      _emailError = emailErr != null;
      _passwordError = passwordErr != null;
    });

    return emailErr ?? passwordErr;
  }

  Future<void> _submit(AppLocalizations l10n) async {
    final localErr = _validate(l10n);
    if (localErr != null) {
      IlndToast.error(context, localErr);
      return;
    }

    await ref
        .read(authNotifierProvider.notifier)
        .signIn(_emailCtrl.text.trim(), _passwordCtrl.text);

    if (!mounted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState is AuthError) {
      IlndToast.error(context, authState.code.localized(l10n));
    }
  }

  Future<void> _signInWithGoogle(AppLocalizations l10n) async {
    await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState is AuthError) {
      IlndToast.error(context, authState.code.localized(l10n));
    }
  }

  Future<void> _signInWithApple(AppLocalizations l10n) async {
    await ref.read(authNotifierProvider.notifier).signInWithApple();
    if (!mounted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState is AuthError) {
      IlndToast.error(context, authState.code.localized(l10n));
    }
  }

  Future<void> _forgotPassword(AppLocalizations l10n) async {
    final email = _emailCtrl.text.trim();
    if (Validators.email(email, l10n) != null) {
      IlndToast.error(context, l10n.loginEnterValidEmailFirst);
      setState(() => _emailError = true);
      return;
    }
    try {
      await ref.read(authNotifierProvider.notifier).resetPassword(email);
      if (!mounted) return;
      IlndToast.success(context, l10n.loginResetLinkSent);
    } on AuthErrorCode catch (code) {
      if (!mounted) return;
      IlndToast.error(context, code.localized(l10n));
    } catch (_) {
      if (!mounted) return;
      IlndToast.error(context, l10n.authErrorGeneric);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;

    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 64),

                Text(
                  'ilnd.',
                  style: AppTextStyles.display(fontSize: 52, color: p.text),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.loginTagline,
                  style: AppTextStyles.body(
                    fontSize: 15,
                    color: p.textMuted,
                  ).copyWith(letterSpacing: 0.2),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 52),

                AuthInputField(
                  controller: _emailCtrl,
                  hint: l10n.loginEmailHint,
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  hasError: _emailError,
                  onChanged: (_) {
                    if (_emailError) setState(() => _emailError = false);
                  },
                ),
                const SizedBox(height: 12),

                AuthInputField(
                  controller: _passwordCtrl,
                  hint: l10n.loginPasswordHint,
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(l10n),
                  hasError: _passwordError,
                  onChanged: (_) {
                    if (_passwordError) setState(() => _passwordError = false);
                  },
                  trailing: Pressable(
                    onTap: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    child: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: p.textMuted,
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Pressable(
                    onTap: isLoading ? null : () => _forgotPassword(l10n),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        l10n.loginForgotPassword,
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: p.accent,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Pressable(
                  onTap: isLoading ? null : () => _submit(l10n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 52,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isLoading
                          ? p.accent.withValues(alpha: 0.5)
                          : p.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: p.onAccent,
                            ),
                          )
                        : Text(
                            l10n.loginSubmit,
                            style: AppTextStyles.body(
                              fontSize: 15,
                              color: p.onAccent,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),

                const SizedBox(height: 24),
                AuthDivider(label: l10n.authOrDivider),
                const SizedBox(height: 24),

                SocialSignInButton(
                  provider: SocialProvider.google,
                  label: l10n.authContinueWithGoogle,
                  onTap: isLoading ? null : () => _signInWithGoogle(l10n),
                ),
                const SizedBox(height: 12),
                SocialSignInButton(
                  provider: SocialProvider.apple,
                  label: l10n.authContinueWithApple,
                  onTap: isLoading ? null : () => _signInWithApple(l10n),
                ),

                const SizedBox(height: 20),

                Pressable(
                  onTap: () => context.push(routeRegister),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: l10n.loginNoAccount,
                            style: AppTextStyles.body(
                              fontSize: 13,
                              color: p.textMuted,
                            ),
                          ),
                          TextSpan(
                            text: l10n.loginRegisterLink,
                            style: AppTextStyles.body(
                              fontSize: 13,
                              color: p.accent,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
