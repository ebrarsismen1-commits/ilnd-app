import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/features/vibe_card/card_footer.dart';

/// Sohbetteki bir ILND cümlesinin 9:16 (story) kart hâli — "ILND bana ne
/// dedi" paylaşım formatı. Vibe card ile aynı görsel dil: aura gradyanı,
/// serif alıntı, altta kimlik satırı + davet kodu rozeti.
class QuoteCardWidget extends StatelessWidget {
  const QuoteCardWidget({
    super.key,
    required this.quote,
    required this.userName,
    required this.p,
    this.referralCode = '',
  });

  final String quote;
  final String userName;
  final AppPalette p;
  final String referralCode;

  /// Kart tek ekran: çok uzun mesajlar kartlaşırken kırpılır (paylaşılabilir
  /// alıntı zaten kısa vurucu cümledir; roman değil).
  static const int maxQuoteChars = 280;

  @override
  Widget build(BuildContext context) {
    final trimmed = quote.length <= maxQuoteChars
        ? quote
        : '${quote.substring(0, maxQuoteChars).trimRight()}…';
    // Uzun alıntı küçük puntoyla nefes alır; kısa cümle poster gibi büyür.
    final fontSize = trimmed.length < 80
        ? 28.0
        : trimmed.length < 160
        ? 22.0
        : 18.0;

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: p.aura,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ilnd.',
              style: AppTextStyles.display(fontSize: 22, color: p.accent),
            ),
            // Alıntı bloğu esnek: kart ne kadar dar/kısa olursa olsun taşmaz,
            // sığmayan kuyruk ellipsis'le kapanır.
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      '“$trimmed”',
                      maxLines: 10,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.display(
                        fontSize: fontSize,
                        color: p.text,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '— ilnd',
                    style: AppTextStyles.body(fontSize: 14, color: p.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CardFooter(userName: userName, p: p, referralCode: referralCode),
          ],
        ),
      ),
    );
  }
}
