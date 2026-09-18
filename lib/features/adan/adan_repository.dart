import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ilnd_app/core/services/app_check_headers.dart';
import 'package:ilnd_app/core/services/app_config.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';

/// `island/{uid}` dokümanı — SADECE OKUNUR. Yazma `firestore.rules`'da
/// kapalıdır; öğeyi yalnız `syncIslandItems` (Admin SDK) verir (ADR-0006).
final islandStateProvider = StreamProvider<IslandState>((ref) {
  // Sert Kural #2: hem auth durumu hem Firebase uid'i
  // izlenir. Yalnız birini izleyen provider ilk girişte ölü stream ya da
  // hesaplar arası sızıntı demek.
  final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
  final auth = ref.watch(authNotifierProvider);
  if (fbUid == null || auth is! AuthAuthenticated) {
    return Stream.value(const IslandState());
  }

  return FirebaseService.firestore
      .collection('island')
      .doc(fbUid)
      .snapshots()
      .map((doc) {
        // Sert Kural #3: doc.data()! yasak, her alanda varsayilan var.
        final data = doc.data() ?? const <String, dynamic>{};
        final raw = data['earned'] as List<dynamic>? ?? const [];
        return IslandState(
          earned: raw.map((e) => '$e').toSet(),
          quietDays: _quietDaysSince(data['lastActiveDate']),
        );
      });
});

/// `lastActiveDate` (YYYY-MM-DD, sunucu yazar) → bugüne kadar geçen sessiz
/// gün sayısı. Alan yoksa ya da bozuksa 0 döner: su berrak kalır. Bilinmeyen
/// bir durumda suyu koyulaştırmak, olmamış bir sessizliği kullanıcıya
/// göstermek olurdu.
int _quietDaysSince(Object? rawDate) {
  if (rawDate is! String) return 0;
  final last = DateTime.tryParse(rawDate);
  if (last == null) return 0;
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(last.year, last.month, last.day)).inDays;
  return days < 0 ? 0 : days;
}

/// Kazanımı sunucuya hesaplatır. İdempotent — kazanılmış öğe geri alınmaz,
/// bu yüzden gereğinden fazla çağrılması zararsızdır (yalnız maliyet).
///
/// Ekran açılışında ve öğe kazandırabilecek eylemlerden sonra çağrılır;
/// her build'de DEĞİL.
final syncIslandProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    if (!AppConfig.isFunctionsConfigured) return;
    final idToken = await fb_auth.FirebaseAuth.instance.currentUser
        ?.getIdToken();
    if (idToken == null) return;

    try {
      await http
          .post(
            Uri.parse(AppConfig.syncIslandItemsUrl),
            headers: {
              'Authorization': 'Bearer $idToken',
              'content-type': 'application/json',
              ...await appCheckHeaders(),
            },
            body: jsonEncode(const <String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Ağ/timeout — ada sessizce eski hâlinde kalır. Kazanım kaybolmaz,
      // bir sonraki açılışta yeniden denenir.
    }
    // Yanıt gövdesi okunmaz: doğru durum Firestore stream'inden gelir,
    // böylece iki kaynak arasında tutarsızlık ihtimali kalmaz.
  };
});
