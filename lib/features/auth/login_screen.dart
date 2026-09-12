import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/utils/validators.dart';
import 'package:ilnd_app/core/widgets/ilnd_surfaces.dart';
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
  void initState() {
    super.initState();
    // Şifre sıfırlama linki çözülemediğinde router kullanıcıyı buraya
    // bırakır. Hata bu ekran açılmadan ÖNCE de gelmiş olabilir (soğuk
    // açılışta link takası ilk kareden önce biter), o yüzden dinlemenin
    // yanında ilk karede bir kez de okunur — yoksa kullanıcı neden şifre
    // yenileme ekranı yerine burada olduğunu hiç öğrenemez.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showLinkError());
  }

  // Toast tek sefer: bayrak provider'da DEĞİL burada tutulur. Provider'ı
  // temizlemek router'ı tekrar değerlendirir ve onboarding duvarı kullanıcıyı
  // giriş ekranından geri koparırdı (bkz. resolveRedirect/linkFailed).
  bool _linkErrorShown = false;

  void _showLinkError() {
    if (!mounted || _linkErrorShown) return;
    final code = ref.read(authLinkErrorProvider);
    if (code == null) return;
    _linkErrorShown = true;
    IlndToast.error(context, code.localized(AppLocalizations.of(context)!));
  }

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
    ref.listen<AuthErrorCode?>(authLinkErrorProvider, (_, next) {
      if (next != null) _showLinkError();
    });
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;

    final canPop = Navigator.of(context).canPop();

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
              // Karşılamadan gelindiyse geri ok; router'ın doğrudan bıraktığı
              // durumda (oturum düştü) dönülecek bir yer yok, yalnız boşluk.
              Align(
                alignment: Alignment.centerLeft,
                child: canPop
                    ? Semantics(
                        button: true,
                        label: l10n.a11yBack,
                        child: Pressable(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Icon(
                                Icons.chevron_left_rounded,
                                size: 28,
                                color: p.text,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(height: 44),
              ),
              const SizedBox(height: 4),

              Text(
                'ilnd.',
                style: AppTextStyles.display(fontSize: 38, color: p.text),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Text(
                l10n.loginTagline,
                style: AppTextStyles.display(fontSize: 25, color: p.text),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.loginSubtitle,
                style: AppTextStyles.body(fontSize: 14, color: p.textMuted),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              _FieldLabel(l10n.authEmailLabel, p: p),
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
              const SizedBox(height: 16),

              _FieldLabel(l10n.authPasswordLabel, p: p),
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

              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Pressable(
                  onTap: isLoading ? null : () => _forgotPassword(l10n),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      l10n.loginForgotPassword,
                      style: AppTextStyles.body(
                        fontSize: 12.5,
                        color: p.accent,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              IlndButton(
                p: p,
                label: l10n.loginSubmit,
                loading: isLoading,
                onTap: () => _submit(l10n),
              ),

              const SizedBox(height: 22),
              AuthDivider(label: l10n.authOrDivider),
              const SizedBox(height: 22),

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
    );
  }
}

/// Alanın üstündeki kalın etiket ("e-posta", "şifre").
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.p});
  final String text;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: AppTextStyles.body(
            fontSize: 13,
            color: p.text,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
