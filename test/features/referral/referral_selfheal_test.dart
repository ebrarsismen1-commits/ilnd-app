import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilnd_app/core/repositories/referral_repository.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/features/referral/referral_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bug: kullanıcı başkasının davet kodunu girebiliyor ama kendi kodunu
/// göremiyordu — ensureReferralCode kayıtta fire-and-forget'ti, köprü
/// yarışında sessizce düşünce kod hiç oluşmuyordu. Referral ekranı artık
/// açılışta kendini onarır: kod boşsa üretir ve gösterir.
class _FakeReferralRepo extends ReferralRepository {
  _FakeReferralRepo() : super('uid');
  int ensureCalls = 0;

  @override
  Future<String> ensureReferralCode() async {
    ensureCalls++;
    return 'NEWABC';
  }

  @override
  Future<UserGrowthProfile?> getMyGrowthProfile() async => UserGrowthProfile(
    // İlk okumada kod yok (bug durumu); ensure çağrıldıktan sonra dolu döner.
    referralCode: ensureCalls > 0 ? 'NEWABC' : '',
    foundingMember: false,
  );
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('kod boşsa açılışta üretilir ve karta yazılır', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fake = _FakeReferralRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          referralRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReferralScreen(),
        ),
      ),
    );

    // Microtask + iki future okuması + ensure + invalidate zinciri ilerlesin.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(fake.ensureCalls, greaterThanOrEqualTo(1));
    expect(find.text('NEWABC'), findsOneWidget);
    // Boş-durum yer tutucusu artık görünmemeli.
    expect(find.text('······'), findsNothing);
  });
}
