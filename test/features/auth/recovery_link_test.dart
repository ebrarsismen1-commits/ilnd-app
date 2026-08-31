import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';

/// `{{ .TokenHash }}` şablonuyla gelen şifre sıfırlama linkinin ayrıştırılması.
void main() {
  test('token_hash + type=recovery query parametrelerinden okunur', () {
    expect(
      recoveryTokenHashFrom(
        Uri.parse(
          'https://ilnd-app-8dcbd.web.app/?token_hash=pkce_abc123&type=recovery',
        ),
      ),
      'pkce_abc123',
    );
  });

  test('parametreler fragment arkasındaysa da okunur', () {
    // Şablon linki `#` arkasına koyarsa akış bozulmasın.
    expect(
      recoveryTokenHashFrom(
        Uri.parse(
          'https://ilnd-app-8dcbd.web.app/#token_hash=pkce_abc123&type=recovery',
        ),
      ),
      'pkce_abc123',
    );
  });

  test('başka type ile gelen link recovery sayılmaz', () {
    // Hesap onayı (signup) linki yeni-şifre ekranını açmamalı.
    expect(
      recoveryTokenHashFrom(
        Uri.parse('https://ilnd-app-8dcbd.web.app/?token_hash=x&type=signup'),
      ),
      isNull,
    );
  });

  test('eksik ya da boş token_hash yok sayılır', () {
    expect(
      recoveryTokenHashFrom(
        Uri.parse('https://ilnd-app-8dcbd.web.app/?type=recovery'),
      ),
      isNull,
    );
    expect(
      recoveryTokenHashFrom(
        Uri.parse('https://ilnd-app-8dcbd.web.app/?token_hash=&type=recovery'),
      ),
      isNull,
    );
  });

  test('sıradan uygulama adresi ve eski hata linki dokunulmadan geçer', () {
    // Flutter web hash stratejisinde fragment rota taşır; yanlış eşleşmemeli.
    expect(
      recoveryTokenHashFrom(
        Uri.parse('https://ilnd-app-8dcbd.web.app/#/onboarding/welcome'),
      ),
      isNull,
    );
    // ConfirmationURL akışının süresi dolmuş linki: token_hash yok.
    expect(
      recoveryTokenHashFrom(
        Uri.parse(
          'https://ilnd-app-8dcbd.web.app/?error=access_denied'
          '&error_code=otp_expired#/onboarding/welcome',
        ),
      ),
      isNull,
    );
  });
}
