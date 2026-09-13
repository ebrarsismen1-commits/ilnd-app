import 'package:shared_preferences/shared_preferences.dart';

/// Cihazda tutulan, oturumdaki KİŞİYE ait veri ve hesap değişiminde temizliği.
///
/// Güvenlik denetimi H-2 (2026-09-13): onboarding cevapları (ad, kilo, boy,
/// yaş, alerjiler, hedefler) uid'siz anahtarlarda duruyordu. Paylaşılan bir
/// cihazda A çıkış yapıp B yeni bir hesapla girince, sunucuda profili olmayan
/// B için A'nın cevapları B'nin Supabase profiline ve AI hafızasına yazılıyor,
/// B onboarding'i hiç görmeden A'nın verisiyle devam ediyordu. `is_premium`,
/// seri, su ve ruh hali kayıtları da aynı şekilde sonraki hesaba taşınıyordu.
///
/// Bu dosya saftır (yalnız SharedPreferences): sağlayıcıları sıfırlama işi
/// `local_data_guard.dart`'ta.

/// Yerel profilin hangi hesaba ait olduğu. Oturum açılmadan yapılan
/// onboarding'de boştur; ilk giriş yapan hesap sahiplenir.
const kLocalProfileOwner = 'local_profile_owner';

/// Yerel veri şeması. 2'den küçükse sahip bilgisi hiç yazılmamış eski bir
/// kurulumdur (bkz. [isLegacyOrphanedProfile]).
const kLocalDataSchema = 'local_data_schema';
const kLocalDataSchemaVersion = 2;

/// Oturumdaki kişiye ait, uid'siz saklanan anahtarlar. Çıkışta silinir.
///
/// Bilerek DIŞARIDA kalanlar cihaz ayarıdır, kişisel veri değil:
/// hatırlatma saati/izni (`reminder_*`), tema, haftalık sosyal kanıt önbelleği.
const kPersonalKeys = <String>[
  'onboarding_done',
  'user_name',
  'onboarding_goals',
  'onboarding_frequency',
  'first_entry_done',
  'pending_referral_code',
  'onboarding_age',
  'onboarding_height',
  'onboarding_weight',
  'onboarding_diet',
  'onboarding_allergies',
  'quick_setup_step',
  'mood_checkin_date',
  'mood_checkin_value',
  'sleep_ritual_date',
  'sleep_ritual_done',
  'is_premium',
  'longest_streak',
  'last_observed_streak',
  kLocalProfileOwner,
  // uid kapsamından önceki tek anahtarlı sürümler. Bırakılırsa ilk giriş
  // yapan hesaba "göç" eder (IlndMemoryNotifier / ChatNotifier), yani başka
  // bir kişinin sohbeti ve hafızası ona geçer.
  'ilnd_memory',
  'chat_sessions',
  'chat_history',
];

/// Gün başına tutulan kişisel kayıtların önekleri (su: `water_YYYY-MM-DD`).
const kPersonalKeyPrefixes = <String>['water_'];

/// uid'e bağlı anahtar önekleri. Hesap değişiminde zaten ayrışıyorlar
/// (`ilnd_memory_<uid>`); yalnız HESAP SİLİNİNCE temizlenir.
const kUidScopedPrefixes = <String>[
  'ilnd_memory_',
  'chat_sessions_',
  'chat_history_',
];

/// Çıkışta / hesap değişiminde kişisel yerel veriyi siler.
///
/// SharedPreferences bellek önbelleğini `remove` çağrısı anında günceller;
/// yani bu fonksiyon döndüğü anda okuyanlar temiz değeri görür, disk yazımı
/// arkadan tamamlanır.
Future<void> clearPersonalLocalData(SharedPreferences prefs) {
  final keys = <String>{
    ...kPersonalKeys,
    for (final key in prefs.getKeys())
      if (kPersonalKeyPrefixes.any(key.startsWith)) key,
  };
  return Future.wait(keys.map(prefs.remove));
}

/// Silinen hesabın uid'e bağlı yerel verisini (sohbet, AI hafızası) siler.
Future<void> clearUidScopedLocalData(SharedPreferences prefs, String uid) {
  if (uid.isEmpty) return Future.value();
  return Future.wait([
    for (final prefix in kUidScopedPrefixes) prefs.remove('$prefix$uid'),
  ]);
}

/// Yerel profil bu hesaba mı ait? Sahibi yoksa (oturumsuz onboarding) evet.
bool localProfileBelongsTo(SharedPreferences prefs, String uid) {
  final owner = prefs.getString(kLocalProfileOwner);
  return owner == null || owner == uid;
}

/// Yerel profili bu hesaba bağlar.
Future<void> claimLocalProfile(SharedPreferences prefs, String uid) async {
  await prefs.setString(kLocalProfileOwner, uid);
  await prefs.setInt(kLocalDataSchema, kLocalDataSchemaVersion);
}

/// Sahipsiz eski kurulum: oturum yok, onboarding tamamlanmış, ama şema
/// işareti hiç yazılmamış. Bu, bu sürümden ÖNCE çıkış yapmış birinin
/// cevaplarıdır; kime ait olduğu bilinemez, sonraki hesaba verilmemeli.
///
/// Bu sürümde oturumsuz tamamlanan onboarding şema işaretini yazar
/// (OnboardingDoneNotifier.setDone), yani kayıt olmadan önce kapatılan yeni
/// bir kurulum yanlışlıkla silinmez.
bool isLegacyOrphanedProfile(
  SharedPreferences prefs, {
  required bool hasSession,
}) =>
    !hasSession &&
    (prefs.getBool('onboarding_done') ?? false) &&
    prefs.getInt(kLocalDataSchema) != kLocalDataSchemaVersion;

/// Oturum geçişinde yapılacak iş.
enum LocalDataAction { none, wipe }

/// Oturum durumunu izleyip ne zaman silineceğine karar verir. Saf: test
/// edilebilsin diye AuthState yerine yalnız uid ve "geçici mi" bilgisini alır.
///
/// Geçici durumlar (yükleniyor, hata, başlangıç) karar değiştirmez: örneğin
/// hesap silme sırasında durum kısa bir süre "yükleniyor" olur, bu bir çıkış
/// değildir.
class LocalDataGuard {
  String? _lastUid;

  LocalDataAction observe({required String? uid, required bool transient}) {
    if (transient) return LocalDataAction.none;
    final previous = _lastUid;
    _lastUid = uid;
    if (previous == null) return LocalDataAction.none;
    if (uid == null || uid != previous) return LocalDataAction.wipe;
    return LocalDataAction.none;
  }
}
