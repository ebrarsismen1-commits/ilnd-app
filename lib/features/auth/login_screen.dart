import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/auth/shared_input_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _hasFieldError = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _localValidate() {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) return 'E-posta ve şifreyi doldur.';
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      return 'Geçerli bir e-posta adresi gir.';
    }
    return null;
  }

  Future<void> _submit() async {
    final localErr = _localValidate();
    if (localErr != null) {
      setState(() => _hasFieldError = true);
      IlndToast.error(context, localErr);
      return;
    }
    setState(() => _hasFieldError = false);

    await ref.read(authNotifierProvider.notifier).signIn(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );

    if (!mounted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState is AuthError) {
      IlndToast.error(context, authState.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;

    return Scaffold(
      body: SafeArea(
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
                style: AppTextStyles.display(fontSize: 52),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'kendi içine dön.',
                style: AppTextStyles.body(
                  fontSize: 15,
                  color: AppColors.muted,
                ).copyWith(letterSpacing: 0.2),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 52),

              AuthInputField(
                controller: _emailCtrl,
                hint: 'e-posta',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                hasError: _hasFieldError,
              ),
              const SizedBox(height: 12),

              AuthInputField(
                controller: _passwordCtrl,
                hint: 'şifre',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                hasError: _hasFieldError,
                trailing: Pressable(
                  onTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Pressable(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'şifremi unuttum',
                      style: AppTextStyles.body(fontSize: 13, color: AppColors.sage),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Pressable(
                onTap: isLoading ? null : _submit,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isLoading
                        ? AppColors.sage.withValues(alpha: 0.5)
                        : AppColors.sage,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Text(
                          'giriş yap',
                          style: AppTextStyles.body(
                            fontSize: 15,
                            color: AppColors.white,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                ),
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
                          text: 'hesabın yok mu? ',
                          style: AppTextStyles.body(fontSize: 13, color: AppColors.muted),
                        ),
                        TextSpan(
                          text: 'kayıt ol',
                          style: AppTextStyles.body(fontSize: 13, color: AppColors.sage)
                              .copyWith(fontWeight: FontWeight.w600),
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
