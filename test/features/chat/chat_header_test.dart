import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/features/chat/chat_provider.dart';
import 'package:ilnd_app/features/chat/chat_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kayıtlı sohbetlere açılan kapı ÇIPLAK BİR İKON DEĞİL, etiketli bir
/// düğmedir ve bu bilerek böyle.
///
/// Önce saat ikonuyla yapılmıştı; kullanıcı iki kez arayıp bulamadı. İki
/// ayrı sebep üst üste bindi: release derlemesi ikon fontunu buduyor ve o
/// font uzun süre önbellekte kalıyor, yani YENİ eklenen bir glif boş
/// çizilebiliyor (bkz. test/web/hosting_cache_test.dart); üstüne çıplak bir
/// saat ikonu zaten "geçmiş sohbetler" demiyordu.
///
/// Metin uygulamanın kendi yazı tipinden gelir, ikon fontuna bağlı değildir.
/// Bu test kapının kaybolmasını da, sessizce ikona dönmesini de engeller.
class _StubChatNotifier extends ChatNotifier {
  _StubChatNotifier(super.ref);

  @override
  Future<void> greetIfNeeded(AppLocalizations l10n) async {}
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final l10n = lookupAppLocalizations(const Locale('tr'));

  Future<void> pumpChat(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatProvider.overrideWith((ref) => _StubChatNotifier(ref)),
          ilndMemoryProvider.overrideWith(
            (ref) => IlndMemoryNotifier(prefs, '', null),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('sohbetler kapısı yazıyla görünür ve ekranın içindedir', (
    tester,
  ) async {
    await pumpChat(tester);

    final gate = find.text(l10n.chatSessionsTitle);
    expect(
      gate,
      findsOneWidget,
      reason: 'Kapı bir kelimeyle duyurulur; çıplak ikon iki kez kaçırıldı.',
    );

    // Görünür alanın içinde mi: sağa taşan bir düğme de "yok" demektir.
    final box = tester.getRect(gate);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(box.right, lessThanOrEqualTo(screen.width));
    expect(box.left, greaterThanOrEqualTo(0));
    expect(box.top, greaterThanOrEqualTo(0));
  });

  testWidgets('sohbetler kapısına dokunmak listeyi açar', (tester) async {
    await pumpChat(tester);

    await tester.tap(find.text(l10n.chatSessionsTitle));
    // pumpAndSettle KULLANILMAZ: başlıktaki nefes halkası sonsuz döner ve
    // ekran hiçbir zaman "durmuş" sayılmaz.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Sayfanın kendi başlığı ve "yeni sohbet" düğmesi geldiyse liste açıldı.
    expect(find.text(l10n.chatSessionsNew), findsOneWidget);
  });
}
