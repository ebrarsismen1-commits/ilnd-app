import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/ilnd_toast.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/auth/shared_input_field.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';

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
  bool _hasFieldError = false;

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

  String? _validate() {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty) return 'Adını gir.';
    if (email.isEmpty) return 'E-posta adresini gir.';
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      return 'Geçerli bir e-posta adresi gir.';
    }
    if (password.length < 6) return 'Şifre en az 6 karakter olmalı.';
    if (password != confirm) return 'Şifreler eşleşmiyor.';
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() => _hasFieldError = true);
      IlndToast.error(context, error);
      return;
    }
    setState(() => _hasFieldError = false);

    await ref.read(authNotifierProvider.notifier).signUp(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          _nameCtrl.text.trim(),
        );

    if (!mounted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState is AuthError) {
      IlndToast.error(context, authState.message);
    } else if (authState is AuthAuthenticated) {
      IlndToast.success(context, 'Hesabın oluşturuldu! Hoş geldin 🌿');
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
              const SizedBox(height: 52),

              Text(
                'ilnd.',
                style: AppTextStyles.display(fontSize: 44),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'hesap oluştur.',
                style: AppTextStyles.body(
                  fontSize: 15,
                  color: AppColors.muted,
                ).copyWith(letterSpacing: 0.2),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              AuthInputField(
                controller: _nameCtrl,
                hint: 'adın',
                icon: Icons.person_outline_rounded,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                hasError: _hasFieldError,
              ),
              const SizedBox(height: 12),

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
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: 12),

              AuthInputField(
                controller: _confirmCtrl,
                hint: 'şifreyi tekrarla',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                hasError: _hasFieldError,
                trailing: Pressable(
                  onTap: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  child: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ),
              ),

              const SizedBox(height: 24),

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
                          'kayıt ol',
                          style: AppTextStyles.body(
                            fontSize: 15,
                            color: AppColors.white,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                ),
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
                          text: 'zaten hesabın var mı? ',
                          style: AppTextStyles.body(fontSize: 13, color: AppColors.muted),
                        ),
                        TextSpan(
                          text: 'giriş yap',
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
