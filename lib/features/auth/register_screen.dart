import 'package:flutter/gestures.dart';
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
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Per-field error flags — only highlight the specific field that failed.
  bool _nameError = false;
  bool _emailError = false;
  bool _passwordError = false;
  bool _confirmError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = ref.read(userNameProvider);
      if (saved.isNotEmpty) _nameCtrl.text = saved;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /// Validates all fields, updates per-field error flags, and returns the
  /// first error message — or null when everything is valid.
  String? _validate(AppLocalizations l10n) {
    final nameErr = Validators.name(_nameCtrl.text, l10n);
    final emailErr = Validators.email(_emailCtrl.text, l10n);
    final passwordErr = Validators.password(_passwordCtrl.text, l10n);
    final confirmErr = Validators.passwordConfirm(
      _passwordCtrl.text,
      _confirmCtrl.text,
      l10n,
    );

    setState(() {
      _nameError = nameErr != null;
      _emailError = emailErr != null;
      _passwordError = passwordErr != null;
      _confirmError = confirmErr != null;
    });

    return nameErr ?? emailErr ?? passwordErr ?? confirmErr;
  }

  Future<void> _submit(AppLocalizations l10n) async {
    final error = _validate(l10n);
    if (error != null) {
      IlndToast.error(context, error);
      return;
    }

    await ref
        .read(authNotifierProvider.notifier)
        .signUp(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          _nameCtrl.text.trim(),
        );

    if (!mounted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState is AuthError) {
      IlndToast.error(context, authState.code.localized(l10n));
    } else if (authState is AuthAuthenticated) {
      IlndToast.success(context, l10n.registerSuccess);
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
                const SizedBox(height: 52),

                Text(
                  'ilnd.',
                  style: AppTextStyles.display(fontSize: 44, color: p.text),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.registerTagline,
                  style: AppTextStyles.body(
                    fontSize: 15,
                    color: p.textMuted,
                  ).copyWith(letterSpacing: 0.2),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                AuthInputField(
                  controller: _nameCtrl,
                  hint: l10n.registerNameHint,
                  icon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  hasError: _nameError,
                  onChanged: (_) {
                    if (_nameError) setState(() => _nameError = false);
                  },
                ),
                const SizedBox(height: 12),

                AuthInputField(
                  controller: _emailCtrl,
                  hint: l10n.registerEmailHint,
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
                  hint: l10n.registerPasswordHint,
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
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
                const SizedBox(height: 12),

                AuthInputField(
                  controller: _confirmCtrl,
                  hint: l10n.registerConfirmPasswordHint,
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(l10n),
                  hasError: _confirmError,
                  onChanged: (_) {
                    if (_confirmError) setState(() => _confirmError = false);
                  },
                  trailing: Pressable(
                    onTap: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    child: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: p.textMuted,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: l10n.registerTermsPrefix,
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: p.textMuted,
                          ),
                        ),
                        TextSpan(
                          text: l10n.registerTermsOfService,
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: p.accent,
                          ).copyWith(fontWeight: FontWeight.w600),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => context.push(routeTermsOfService),
                        ),
                        TextSpan(
                          text: l10n.registerTermsAnd,
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: p.textMuted,
                          ),
                        ),
                        TextSpan(
                          text: l10n.registerPrivacyPolicy,
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: p.accent,
                          ).copyWith(fontWeight: FontWeight.w600),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => context.push(routePrivacyPolicy),
                        ),
                        TextSpan(
                          text: l10n.registerTermsSuffix,
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: p.textMuted,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
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
                            l10n.registerSubmit,
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
                  onTap: () => context.pop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: l10n.registerHaveAccount,
                            style: AppTextStyles.body(
                              fontSize: 13,
                              color: p.textMuted,
                            ),
                          ),
                          TextSpan(
                            text: l10n.registerLoginLink,
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
