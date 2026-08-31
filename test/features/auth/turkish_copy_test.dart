import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Türkçe metinlerin üslup tutarlılığı.
///
/// Uygulamanın tamamı kullanıcıya "sen" diye hitap eder; auth hata bloğu ise
/// "siz" kullanıyordu ("bağlantınızı kontrol edin", "lütfen tekrar deneyin").
/// Aynı ekranda iki farklı hitap, metni çeviriden çıkmış gibi gösteriyordu.
/// Bu test o karışıklığın geri gelmesini engeller.
void main() {
  late AppLocalizations tr;
  late AppLocalizations en;

  setUpAll(() {
    tr = lookupAppLocalizations(const Locale('tr'));
    en = lookupAppLocalizations(const Locale('en'));
  });

  test('Türkçe metinlerde resmî (siz) hitap kalıbı yok', () {
    // Yalnız hitap kalıplarını arıyoruz: "henüz"/"deniz" gibi kelimelerin
    // içindeki -niz hecesi yanlış alarm vermesin diye kelime kökü değil,
    // fiil çekiminin tamamı hedefleniyor.
    final formal = RegExp(
      r'\b(?:deneyin|deneyiniz|girin|giriniz|edin|ediniz|yapın|yapınız|'
      r'seçin|seçiniz|bakın|bakınız|kontrol edin)\b|'
      r'\b\w+(?:nızı|nizi|nuzu|nüzü|nıza|nize)\b|'
      r'\w+(?:dır|dir|dur|dür)\.',
    );

    final offenders = <String, String>{};
    for (final entry in _trStrings(tr).entries) {
      if (formal.hasMatch(entry.value)) offenders[entry.key] = entry.value;
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Bu dizeler "siz" diye hitap ediyor, app geneli "sen" kullanıyor:\n'
          '${offenders.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}',
    );
  });

  test('"Welcome back" karşılığı "tekrar" içerir', () {
    // "Hoş geldin" tek başına "welcome" demek; "welcome back" için "tekrar"
    // şart. Kullanıcı şikayetinin çıkış noktası tam olarak bu eksikti.
    expect(en.newPasswordSuccess, contains('Welcome back'));
    expect(tr.newPasswordSuccess, contains('Tekrar hoş geldin'));
    expect(en.loginTagline, contains('welcome back'));
    expect(tr.loginTagline, contains('tekrar hoş geldin'));
  });

  test('gün/günlük ayrımı korunur: sayı etiketleri "günlük" demez', () {
    // Türkçede "günlük" hem journal hem daily demek. Haftalık özette
    // "günlük seri" (day streak) ile "günlük yazıldı" (journal entries)
    // yan yana duruyordu; rozetler "7 günlük" diyordu. Gün anlamındaki
    // etiketler "günlük" kelimesini kullanamaz.
    for (final s in [
      tr.profileBadgeSevenDays,
      tr.profileBadgeThirtyDays,
      tr.profileDayStreak,
    ]) {
      expect(
        s.contains('günlük'),
        isFalse,
        reason: '"$s" gün sayısını anlatıyor ama journal ile karışıyor.',
      );
    }

    // Journal tarafı "günlük" demeye devam etmeli (marka dili).
    expect(tr.journalTitle, 'günlük');
    expect(tr.profileJournalEntriesWritten, contains('günlük'));
  });

  test('bölüm etiketleri ALL CAPS yazılır', () {
    // AppTextStyles.sectionLabel metni büyütmez; büyük harf .arb'den gelir.
    // trioSectionTitle "Bugünün Üçlüsü" diye Title Case yazılmıştı ve aynı
    // stildeki diğer etiketlerin yanında tek başına farklı görünüyordu.
    // Ayrıca Türkçede tamlama zaten Title Case almaz.
    final labels = <String, String>{
      'homeTodaysReadTitle': tr.homeTodaysReadTitle,
      'trioSectionTitle': tr.trioSectionTitle,
      'exploreMoreLabel': tr.exploreMoreLabel,
      'exploreRitualsLabel': tr.exploreRitualsLabel,
      'profileGoalsLabel': tr.profileGoalsLabel,
      'profileBadgesLabel': tr.profileBadgesLabel,
      'profileWeeklySummaryLabel': tr.profileWeeklySummaryLabel,
      'profileSettingsLabel': tr.profileSettingsLabel,
      'takipMacrosLabel': tr.takipMacrosLabel,
      'takipMealsLabel': tr.takipMealsLabel,
      'takipActivityLabel': tr.takipActivityLabel,
      'takipHabitsLabel': tr.takipHabitsLabel,
      'movementShelfLabel': tr.movementShelfLabel,
      'topulukUpcomingLabel': tr.topulukUpcomingLabel,
      'adanLabel': tr.adanLabel,
      'adanItemsLabel': tr.adanItemsLabel,
      'referralYourCode': tr.referralYourCode,
    };

    for (final e in labels.entries) {
      // Türkçe'ye duyarlı büyütme: 'i' harfi 'İ' olmalı, toUpperCase() bunu
      // ortamdan bağımsız garanti etmediği için karşılaştırma değil,
      // "küçük harf içermiyor" kontrolü yapılıyor.
      expect(
        e.value,
        isNot(matches(RegExp(r'[a-zçğıöşü]'))),
        reason: '${e.key} bölüm etiketi ama küçük harf içeriyor: ${e.value}',
      );
    }
  });

  test('akış içi buton etiketleri küçük harfle başlar', () {
    // Ev üslubu: akış içindeki butonlar/durum metinleri küçük harf, yalnız
    // diyalog ve sistem bildirimleri (startupRetry, homeReminderInvite*,
    // profileDeleteAccountDialog*) cümle düzeniyle yazılır. Hareket özelliği
    // sonradan eklendi ve bu ayrımı kaçırıp "Başla / Devam et / Yeniden izle"
    // diye gelmişti — aynı ekrandaki "yumuşak", "tamamlandı" küçükken.
    final buttons = <String, String>{
      'welcomeStart': tr.welcomeStart,
      'quickSetupContinue': tr.quickSetupContinue,
      'journalRetry': tr.journalRetry,
      'journalSave': tr.journalSave,
      'recipeStartCooking': tr.recipeStartCooking,
      'recipeNextButton': tr.recipeNextButton,
      'breathAgainButton': tr.breathAgainButton,
      'breathCloseButton': tr.breathCloseButton,
      'sleepRitualContinueButton': tr.sleepRitualContinueButton,
      'sleepRitualSkipButton': tr.sleepRitualSkipButton,
      'yemekEkleRetryButton': tr.yemekEkleRetryButton,
      'yemekEkleSaveButton': tr.yemekEkleSaveButton,
      'gorevEkleSave': tr.gorevEkleSave,
      'movementStart': tr.movementStart,
      'movementContinue': tr.movementContinue,
      'movementReplay': tr.movementReplay,
      'movementPlayerRetry': tr.movementPlayerRetry,
      'movementPlayerError': tr.movementPlayerError,
      'movementSessionDone': tr.movementSessionDone,
      // Topluluk RSVP etiketleri 2026-08-31'e kadar "Katıl" / "Geliyorum"
      // diye büyük harfle duruyordu: kural vardı ama bu üçlü listeye hiç
      // eklenmemişti, yani kimse kırmızı görmedi. Kontenjan durumu
      // eklenirken düzeltildi ve kilide alındı.
      'topulukRsvpJoin': tr.topulukRsvpJoin,
      'topulukRsvpGoing': tr.topulukRsvpGoing,
      'topulukRsvpFull': tr.topulukRsvpFull,
    };

    for (final e in buttons.entries) {
      expect(
        e.value.substring(0, 1),
        matches(RegExp(r'[a-zçğıöşü0-9]')),
        reason:
            '${e.key} akış içi bir etiket, küçük harfle başlamalı: '
            '${e.value}',
      );
    }
  });

  test('kesme işareti her yerde düz (\') yazılır', () {
    // profileGoPremium tüm app'te kıvrık kesme (’) kullanan tek dizeydi;
    // diğer 12 dize düz kesme kullanıyor. Aynı ekranda iki farklı karakter
    // yazı tipinde gözle görülür bir tutarsızlık yaratıyor.
    for (final l in [tr, en]) {
      for (final s in <String>[
        l.profileGoPremium,
        l.profilePremiumMember,
        l.ekleAskIlndTitle,
        l.referralShareText('ABC123'),
        l.vibeCardShareText,
        l.topulukComingBody,
      ]) {
        expect(
          s.contains('’') || s.contains('‘'),
          isFalse,
          reason: 'Kıvrık kesme işareti kullanılmış: $s',
        );
      }
    }
  });

  test('hiçbir kullanıcı metninde uzun tire yok', () {
    // Kural önce yalnız ILND'nin ağzı için vardı (ilnd_character.dart
    // "Yazım kuralların" bölümü tireyi istisnasız yasaklıyor), sonra tüm
    // uygulamaya genişledi: owner 2026-08-20'de uzun tirenin metni yapay
    // gösterdiğini söyledi. Kural kafada kalırsa bir sonraki metin bloğu
    // yine getirir, o yüzden .arb doğrudan taranıyor.
    //
    // Yalnız KULLANICI metinleri taranır: @-anahtarları geliştiriciye bakan
    // açıklamalar taşır, orada tire serbest.
    for (final path in ['lib/l10n/app_tr.arb', 'lib/l10n/app_en.arb']) {
      final map =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final offenders = <String>[];
      map.forEach((key, value) {
        if (key.startsWith('@') || value is! String) return;
        if (value.contains('—') || value.contains('–')) {
          offenders.add('$key: $value');
        }
      });
      expect(
        offenders,
        isEmpty,
        reason:
            'Uzun tire kullanılmış. Yerine virgül, iki nokta, '
            'orta nokta veya ayrı bir cümle kullan: '
            '${offenders.join(" | ")}',
      );
    }

    // İçerik dosyası da kullanıcı metni taşıyor. Testin ilk hâli yalnız
    // .arb'ye bakıyordu ve 15 tarifin tamamındaki tireleri kaçırmıştı.
    final content = File('content/articles.json').readAsStringSync();
    expect(
      content.contains('—') || content.contains('–'),
      isFalse,
      reason: 'content/articles.json içinde uzun tire var',
    );
  });

  test('sayıdan sonra belirtme eki gelmez', () {
    // "3 alışkanlığı tamamladın" belirli nesne anlatır (hangi alışkanlık?);
    // sayıyla birlikte yalın hâl gerekir. Kardeş dize (günlük) zaten doğruydu.
    expect(tr.vibeCardSublineHabitCount(3), '3 alışkanlık tamamladın');
    expect(tr.vibeCardSublineHabitCount(1), '1 alışkanlık tamamladın');
    expect(tr.vibeCardSublineJournalCount(3), '3 günlük yazdın');
  });

  test('iki dilli slogan yalnız Türkçe için anlamlı', () {
    // Ekranlar bu satırı locale koşuluyla çiziyor; .arb tarafında da
    // Türkçe değerin gerçekten İngilizce metin taşıdığını doğrula, yoksa
    // koşul anlamsızlaşır.
    // Türkçede ikinci satır gerçekten farklı bir cümle (İngilizcesi).
    expect(tr.welcomeTaglineEn, isNot(tr.welcomeTagline));
    // İngilizcede ikisi birebir aynı: ekranda çizilseydi slogan iki kez
    // yazılırdı. Ekranların locale koşulunun gerekçesi tam olarak bu.
    expect(en.welcomeTaglineEn, en.welcomeTagline);
  });
}

/// Kullanıcıya görünen Türkçe dizeler. Yeni anahtar eklendiğinde buraya da
/// eklenmeli; liste değil getter taraması yapılamadığı için (kod üretimi)
/// üslup riski yüksek olan bloklar seçildi.
Map<String, String> _trStrings(AppLocalizations l) => {
  'authErrorInvalidCredentials': l.authErrorInvalidCredentials,
  'authErrorEmailInUse': l.authErrorEmailInUse,
  'authErrorWeakPassword': l.authErrorWeakPassword,
  'authErrorUserNotFound': l.authErrorUserNotFound,
  'authErrorNetwork': l.authErrorNetwork,
  'authErrorInvalidEmail': l.authErrorInvalidEmail,
  'authErrorGeneric': l.authErrorGeneric,
  'authErrorConfirmEmail': l.authErrorConfirmEmail,
  'authErrorSignupFailed': l.authErrorSignupFailed,
  'authErrorSignOutFailed': l.authErrorSignOutFailed,
  'authErrorGoogleFailed': l.authErrorGoogleFailed,
  'authErrorAppleFailed': l.authErrorAppleFailed,
  'authErrorResetFailed': l.authErrorResetFailed,
  'authErrorUpdatePasswordFailed': l.authErrorUpdatePasswordFailed,
  'authErrorDeleteUnavailable': l.authErrorDeleteUnavailable,
  'authErrorDeleteFailed': l.authErrorDeleteFailed,
  'validatorEmailRequired': l.validatorEmailRequired,
  'validatorEmailInvalid': l.validatorEmailInvalid,
  'validatorPasswordRequired': l.validatorPasswordRequired,
  'validatorPasswordTooShort': l.validatorPasswordTooShort,
  'validatorPasswordConfirmRequired': l.validatorPasswordConfirmRequired,
  'validatorPasswordMismatch': l.validatorPasswordMismatch,
  'validatorNameRequired': l.validatorNameRequired,
  'validatorNameTooShort': l.validatorNameTooShort,
  'startupFailedBody': l.startupFailedBody,
  'loginEnterValidEmailFirst': l.loginEnterValidEmailFirst,
  'loginResetLinkSent': l.loginResetLinkSent,
  'registerConfirmEmailSent': l.registerConfirmEmailSent,
  'ilndServiceGenericError': l.ilndServiceGenericError,
  'ilndServiceNoInternet': l.ilndServiceNoInternet,
  'ilndServiceDailyLimitReached': l.ilndServiceDailyLimitReached,
  'redeemCodeNetworkError': l.redeemCodeNetworkError,
  'redeemCodeNotReady': l.redeemCodeNotReady,
  'yemekEkleNoInternet': l.yemekEkleNoInternet,
  'yemekEkleAnalysisFailed': l.yemekEkleAnalysisFailed,
  'reminderPermissionDenied': l.reminderPermissionDenied,
  'profileDeleteAccountDialogBody': l.profileDeleteAccountDialogBody,
};
