// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get loginTagline => 'hoş geldin geri.';

  @override
  String get loginEmailHint => 'e-posta';

  @override
  String get loginPasswordHint => 'şifre';

  @override
  String get loginForgotPassword => 'şifremi unuttum';

  @override
  String get loginSubmit => 'giriş yap';

  @override
  String get loginNoAccount => 'hesabın yok mu? ';

  @override
  String get loginRegisterLink => 'kayıt ol';

  @override
  String get loginEnterValidEmailFirst =>
      'Önce geçerli bir e-posta adresi gir.';

  @override
  String get loginResetLinkSent =>
      'Şifre sıfırlama bağlantısı e-postana gönderildi.';

  @override
  String get registerTagline => 'hesap oluştur.';

  @override
  String get registerNameHint => 'adın';

  @override
  String get registerEmailHint => 'e-posta';

  @override
  String get registerPasswordHint => 'şifre';

  @override
  String get registerConfirmPasswordHint => 'şifreyi tekrarla';

  @override
  String get registerTermsPrefix => 'kayıt olarak ';

  @override
  String get registerTermsOfService => 'Kullanım Şartları';

  @override
  String get registerTermsAnd => ' ve ';

  @override
  String get registerPrivacyPolicy => 'Gizlilik Politikası\'nı';

  @override
  String get registerTermsSuffix => ' kabul ediyorsun.';

  @override
  String get registerSubmit => 'kayıt ol';

  @override
  String get registerHaveAccount => 'zaten hesabın var mı? ';

  @override
  String get registerLoginLink => 'giriş yap';

  @override
  String get registerSuccess => 'Hesabın oluşturuldu! Hoş geldin 🌿';

  @override
  String get validatorEmailRequired => 'E-posta adresi gerekli.';

  @override
  String get validatorEmailInvalid => 'Geçerli bir e-posta adresi gir.';

  @override
  String get validatorPasswordRequired => 'Şifre gerekli.';

  @override
  String get validatorPasswordTooShort => 'Şifre en az 6 karakter olmalı.';

  @override
  String get validatorPasswordConfirmRequired => 'Şifreyi tekrar gir.';

  @override
  String get validatorPasswordMismatch => 'Şifreler eşleşmiyor.';

  @override
  String get validatorNameRequired => 'Adını gir.';

  @override
  String get validatorNameTooShort => 'Adın en az 2 karakter olmalı.';

  @override
  String get welcomeTagline =>
      'günlük tut, ruh halini takip et, ILND\'le konuş.';

  @override
  String get welcomeTaglineEn => 'journal, track your mood, talk to ILND.';

  @override
  String get welcomeStart => 'başla';

  @override
  String get quickSetupTitle => 'seni biraz tanıyalım';

  @override
  String get quickSetupTitleEn => 'let\'s get to know you a little';

  @override
  String get quickSetupNameHint => 'adın ne?';

  @override
  String get quickSetupGoalsTitle => 'neye odaklanmak istersin?';

  @override
  String get quickSetupGoalsSubtitle => 'istediğin kadar seçebilirsin';

  @override
  String get quickSetupGoalCalories => 'kalori/besin takibi';

  @override
  String get quickSetupGoalWeight => 'kilo vermek/almak';

  @override
  String get quickSetupGoalMovement => 'daha fazla hareket';

  @override
  String get quickSetupGoalWaterSleep => 'su/uyku takibi';

  @override
  String get quickSetupGoalHabit => 'alışkanlık oluşturma';

  @override
  String get quickSetupGoalMood => 'ruh hali takibi';

  @override
  String get quickSetupInviteCodeTitle => 'davet kodun var mı?';

  @override
  String get quickSetupInviteCodeHint => 'davet kodu';

  @override
  String get quickSetupHaveInviteCode => 'davet kodum var';

  @override
  String get quickSetupContinue => 'devam et';

  @override
  String get firstEntryHeader => 'İLK GÜNLÜK';

  @override
  String get firstEntrySkip => 'şimdi değil';

  @override
  String get firstEntryReady => 'hazırım';

  @override
  String get firstEntrySave => 'kaydet';

  @override
  String get firstEntryPrompt => 'bugün nasılsın?';

  @override
  String get firstEntryHint => 'ne aklından geçiyorsa yaz...';

  @override
  String get homeTodaysReadTitle => 'BUGÜNÜN OKUMASI';

  @override
  String get homeTodaysIntentionTitle => 'BUGÜNKÜ NİYETİN';

  @override
  String get homeGreetingNight => 'iyi geceler';

  @override
  String get homeGreetingMorning => 'günaydın';

  @override
  String get homeGreetingDay => 'iyi günler';

  @override
  String get homeGreetingEvening => 'iyi akşamlar';

  @override
  String homeGreetingWithName(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String homeProactiveGoal(String goal) {
    return '\"$goal\" hedefin için buradayım.';
  }

  @override
  String get homeProactiveRecentNotes =>
      'son yazdıklarını okudum, konuşmak ister misin?';

  @override
  String get homeProactiveDefault => 'bugün nasıl geçiyor?';

  @override
  String get homeMoodQuestion => 'şu an nasılsın?';

  @override
  String get homeMoodCalm => 'sakin';

  @override
  String get homeMoodGood => 'iyi';

  @override
  String get homeMoodOkay => 'fena değil';

  @override
  String get homeMoodTired => 'yorgun';

  @override
  String get homeMoodHard => 'zor';

  @override
  String homeReadTimeArrow(String readTime) {
    return '$readTime oku →';
  }

  @override
  String get homeIntentionEdit => 'düzenle';

  @override
  String get homeIntentionHint => 'bugün neye odaklanmak istiyorsun?';

  @override
  String get homeIntentionSave => 'kaydet';

  @override
  String get journalTitle => 'günlük';

  @override
  String get journalConnectionError => 'bağlantı sorunu';

  @override
  String get journalConnectionErrorBody =>
      'günlüğüne şu an erişilemiyor. bağlantını kontrol et.';

  @override
  String get journalRetry => 'tekrar dene';

  @override
  String get journalEmptyTitle => 'henüz bir şey yazmadın';

  @override
  String get journalEmptyBody =>
      'bugün nasıl hissettiğini, ya da aklından geçeni yaz. ILND seninle düşünür.';

  @override
  String get journalWriteFirst => 'ilk yazını yaz';

  @override
  String get journalNewEntry => 'yeni günlük yaz';

  @override
  String get journalMonths => 'Oca,Şub,Mar,Nis,May,Haz,Tem,Ağu,Eyl,Eki,Kas,Ara';

  @override
  String get journalWeekdaysShort => 'Pt,Sa,Ça,Pe,Cu,Ct,Pa';

  @override
  String get journalWeekdaysLong =>
      'Pazartesi,Salı,Çarşamba,Perşembe,Cuma,Cumartesi,Pazar';

  @override
  String get journalDone => 'bitti';

  @override
  String get journalSave => 'kaydet';

  @override
  String get journalWritingHint => 'ne düşünüyorsun?';

  @override
  String get profileShareWeeklySummary => 'haftalık özeti paylaş';

  @override
  String get profileDefaultUserName => 'Kullanıcı';

  @override
  String get profileMemoryHeading => 'ILND seni hatırlıyor';

  @override
  String get profileGoalsLabel => 'HEDEFLERİN';

  @override
  String get profileAboutYouLabel => 'SENİN HAKKINDA';

  @override
  String get profileStatStreak => 'seri';

  @override
  String get profileStatPoints => 'puan';

  @override
  String get profileStatBadge => 'rozet';

  @override
  String get profileBadgesLabel => 'ROZETLER';

  @override
  String get profileBadgeFirstStep => 'ilk adım';

  @override
  String get profileBadgeSevenDays => '7 günlük';

  @override
  String get profileBadgeReader => 'okur';

  @override
  String get profileBadgeThirtyDays => '30 günlük';

  @override
  String get profileWeekdaysShort => 'Pt,Sa,Ça,Pe,Cu,Ct,Pa';

  @override
  String get profileWeeklySummaryLabel => 'HAFTALIK ÖZET';

  @override
  String get profileThisWeek => 'bu hafta';

  @override
  String get profileMealsAdded => 'yemek eklendi';

  @override
  String get profileDayStreak => 'günlük seri';

  @override
  String get profileJournalEntriesWritten => 'günlük yazıldı';

  @override
  String get profileSynced => 'senkronize';

  @override
  String get profilePremiumMember => 'ILND+ üyesisin';

  @override
  String get profileGoPremium => 'ILND+’a geç';

  @override
  String get profileSettingsLabel => 'AYARLAR';

  @override
  String get profileInviteFriend => 'arkadaşını davet et';

  @override
  String get profileSettingsRow => 'ayarlar';

  @override
  String get profilePrivacyPolicy => 'gizlilik politikası';

  @override
  String get profileTermsOfService => 'kullanım şartları';

  @override
  String get profileSignedOut => 'Çıkış yapıldı. Görüşürüz 👋';

  @override
  String get profileSignOut => 'çıkış yap';

  @override
  String get profileDeleteAccount => 'hesabımı sil';

  @override
  String get profileDeleteAccountDialogTitle => 'Hesabını sil';

  @override
  String get profileDeleteAccountDialogBody =>
      'Bu işlem geri alınamaz. Günlüklerin, yemek kayıtların, seri geçmişin ve hesabınla ilgili her şey kalıcı olarak silinir.';

  @override
  String get profileDeleteAccountCancel => 'Vazgeç';

  @override
  String get profileDeleteAccountConfirm => 'Hesabımı sil';

  @override
  String get profileAccountDeleted => 'Hesabın silindi. İyi günler 👋';

  @override
  String get exploreTitle => 'keşfet.';

  @override
  String get exploreSubtitle => 'iyi hissetmenin küçük adımları';

  @override
  String get exploreFilterAll => 'hepsi';

  @override
  String get exploreFilterWellness => 'wellness';

  @override
  String get exploreFilterRecipes => 'tarifler';

  @override
  String get exploreFilterArticles => 'yazılar';

  @override
  String get exploreFeaturedLabel => 'ÖNE ÇIKANLAR';

  @override
  String get exploreSeeAllArrow => 'hepsi →';

  @override
  String get exploreStoryBreathing => 'nefes';

  @override
  String get exploreStorySleep => 'uyku';

  @override
  String get exploreStoryWater => 'su';

  @override
  String get exploreStoryMovement => 'hareket';

  @override
  String get exploreStoryMeditation => 'meditasyon';

  @override
  String get exploreStorySelfCare => 'öz-bakım';

  @override
  String get exploreQuote => '\"Bugün küçük bir adım, yarının büyük farkı.\"';

  @override
  String get exploreQuoteSubtitle => 'günün alıntısı';

  @override
  String get paywallSubtitle =>
      'sınırsız sohbet, daha derin hafıza, kişisel plan.';

  @override
  String get paywallBenefitUnlimitedChatTitle => 'sınırsız sohbet';

  @override
  String get paywallBenefitUnlimitedChatSubtitle =>
      'ILND ile istediğin kadar konuş';

  @override
  String get paywallBenefitLongMemoryTitle => 'daha derin hafıza';

  @override
  String get paywallBenefitLongMemorySubtitle =>
      'ILND seni daha uzun süre hatırlar';

  @override
  String get paywallBenefitProactiveTitle => 'proaktif destek';

  @override
  String get paywallBenefitProactiveSubtitle =>
      'ILND seni düşünür, sana ulaşır';

  @override
  String get paywallBenefitPersonalPlanTitle => 'kişisel plan';

  @override
  String get paywallBenefitPersonalPlanSubtitle =>
      'hedeflerine göre özelleştirilmiş yol';

  @override
  String get paywallYearly => 'yıllık';

  @override
  String get paywallFreeTrial => '7 gün ücretsiz dene';

  @override
  String get paywallDiscount => '%40 indirim';

  @override
  String get paywallStartFreeTrial => 'ücretsiz denemeyi başlat';

  @override
  String get paywallNotNow => 'şimdi değil';

  @override
  String get paywallRestore => 'satın alımları geri yükle';

  @override
  String get paywallPurchaseCancelled => 'Satın alma iptal edildi.';

  @override
  String get paywallPurchaseFailed => 'Satın alma başarısız. Tekrar dene.';

  @override
  String get paywallRestoreSuccess => 'Satın alımların geri yüklendi!';

  @override
  String get paywallNoActiveSubscription => 'Aktif abonelik bulunamadı.';

  @override
  String get paywallRestoreFailed => 'Geri yükleme başarısız. Tekrar dene.';

  @override
  String articleDetailReadTime(String readTime) {
    return '  ·  $readTime';
  }

  @override
  String get articleDetailSignOff => '🌿';

  @override
  String get referralTitle => 'arkadaşını davet et';

  @override
  String get referralSubtitle => 'kodunu paylaş, ikiniz de ödül kazanın';

  @override
  String get referralEnterCode => 'davet kodu gir';

  @override
  String get vibeCardShareText => 'ilnd\'deki ruh halimi paylaşıyorum 🌿';

  @override
  String get vibeCardError => 'kart oluşturulamadı.';

  @override
  String get vibeCardShare => 'paylaş';

  @override
  String get vibeCardShareFailed => 'Paylaşılamadı. Tekrar dene.';

  @override
  String get vibeCardStatStreak => 'seri';

  @override
  String get vibeCardStatJournal => 'günlük';

  @override
  String get vibeCardStatHabit => 'alışkanlık';

  @override
  String get chatPaywallReason => 'bu hafta benimle çok konuştun 🌿';

  @override
  String get chatGreeting => 'selam.';

  @override
  String chatGreetingWithName(String name) {
    return 'selam, $name.';
  }

  @override
  String get chatEmptyPrompt => 'ne düşünüyorsun? seninle buradayım.';

  @override
  String get chatComposerHint => 'bir şey yaz...';

  @override
  String get redeemCodeSuccess => 'Davet kodu kullanıldı! 🎉';

  @override
  String get redeemCodeInvalid => 'Geçersiz kod ya da zaten kullanılmış.';

  @override
  String get redeemCodeTitle => 'davet kodun var mı?';

  @override
  String get redeemCodeHint => 'davet kodu';

  @override
  String get redeemCodeConfirm => 'kullan';

  @override
  String get referralCodeLoadError => 'kod yüklenemedi';

  @override
  String get referralCodeLoadErrorBody =>
      'davet kodun şu an yüklenemiyor. bağlantını kontrol et.';

  @override
  String get referralRetry => 'tekrar dene';

  @override
  String get referralCodeCopied => 'Kod kopyalandı!';

  @override
  String referralShareText(String code) {
    return 'ilnd\'e benimle katıl! davet kodum: $code';
  }

  @override
  String get referralShareSubject => 'ilnd davet kodum';

  @override
  String get referralFoundingMember => 'KURUCU ÜYE';

  @override
  String get referralYourCode => 'DAVET KODUN';

  @override
  String get referralCopy => 'kopyala';

  @override
  String get referralShare => 'paylaş';

  @override
  String get splashTagline => 'iyi hisset, iyi yaşa';

  @override
  String get takipTitle => 'takip';

  @override
  String get takipMacrosLabel => 'MAKROLAR';

  @override
  String get takipCalories => 'kalori';

  @override
  String get takipProtein => 'protein';

  @override
  String get takipCarbs => 'karbonhidrat';

  @override
  String get takipFat => 'yağ';

  @override
  String get takipMealsLabel => 'ÖĞÜNLER';

  @override
  String get takipNoMealsYet => 'henüz öğün eklenmedi';

  @override
  String get takipAddMeal => 'öğün ekle';

  @override
  String takipMacroSummary(int protein, int carbs, int fat) {
    return '${protein}g protein · ${carbs}g karbonhidrat · ${fat}g yağ';
  }

  @override
  String takipKcal(int kcal) {
    return '$kcal kcal';
  }

  @override
  String get takipActivityLabel => 'AKTİVİTE';

  @override
  String get takipSteps => 'ADIM';

  @override
  String takipWaterGoal(int ml) {
    return 'hedef: ${ml}ml';
  }

  @override
  String get takipHabitsLabel => 'ALIŞKANLIKLAR';

  @override
  String get takipNoHabitsYet => 'henüz alışkanlık eklenmedi';

  @override
  String get ilndServiceSessionError => 'Oturum doğrulanamadı.';

  @override
  String get ilndServiceUnavailable => 'ILND şu an yanıt veremiyor.';

  @override
  String get ilndServiceDailyLimitReached =>
      'Bugünlük ILND ile konuşma hakkın doldu, yarın tekrar dene.';

  @override
  String ilndServiceResponseFailed(int statusCode) {
    return 'ILND yanıt veremedi ($statusCode).';
  }

  @override
  String get ilndServiceNoInternet =>
      'İnternet bağlantısı yok. Bağlantını kontrol et.';

  @override
  String get ilndServiceGenericError =>
      'Bir şeyler ters gitti. Birazdan tekrar dener misin?';

  @override
  String get ekleTitle => 'ekle.';

  @override
  String get ekleFoodTitle => 'yemek';

  @override
  String get ekleFoodSubtitle => 'fotoğraf çek, analiz et';

  @override
  String get ekleJournalTitle => 'günlük';

  @override
  String get ekleJournalSubtitle => 'bugünü yaz';

  @override
  String get ekleHabitTitle => 'alışkanlık';

  @override
  String get ekleHabitSubtitle => 'yeni hedef ekle';

  @override
  String get ekleWaterTitle => 'su';

  @override
  String get ekleWaterSubtitle => 'bir bardak ekle';

  @override
  String get gorevEkleNameEmpty => 'Önce alışkanlığa bir ad ver.';

  @override
  String get gorevEkleSuccess => 'Alışkanlık eklendi!';

  @override
  String get gorevEkleFailed => 'Eklenemedi. Tekrar dene.';

  @override
  String get gorevEkleTitle => 'yeni alışkanlık';

  @override
  String get gorevEkleHint => 'alışkanlığın ne?';

  @override
  String get gorevEkleDaysPerWeek => 'HAFTADA KAÇ GÜN';

  @override
  String get gorevEkleSave => 'kaydet';

  @override
  String get suEkleTitle => 'su takibi';

  @override
  String suEkleDailyGoal(int ml) {
    return 'günlük hedef: ${ml}ml';
  }

  @override
  String suEkleProgress(int current, int goal) {
    return '${current}ml / ${goal}ml';
  }

  @override
  String get suEkleReset => 'Sıfırlandı.';

  @override
  String get suEkleResetButton => 'sıfırla';

  @override
  String get suEkleHowMuch => 'NE KADAR EKLEYELİM';

  @override
  String suEkleAdded(int ml) {
    return '+${ml}ml eklendi';
  }

  @override
  String get suEkleMl => 'ML';

  @override
  String get yemekEklePaywallReason => 'bugünlük yemek analizi hakkın doldu 🌿';

  @override
  String get yemekEklePhotoAccessError => 'Fotoğrafa erişilemedi. Tekrar dene.';

  @override
  String get yemekEkleAnalysisFailed =>
      'Analiz başarısız oldu. Tekrar dener misin?';

  @override
  String yemekEkleAnalysisFailedStatus(int statusCode) {
    return 'Analiz başarısız oldu ($statusCode).';
  }

  @override
  String get yemekEkleNoInternet =>
      'İnternet bağlantısı yok. Bağlantını kontrol et.';

  @override
  String get yemekEkleTitle => 'yemek ekle';

  @override
  String get yemekEklePhotoPrompt => 'ne yiyorsun?';

  @override
  String get yemekEklePhotoPromptBody =>
      'fotoğrafını çek, ILND kalorisini ve makrolarını tahmin etsin';

  @override
  String get yemekEkleOpenCamera => 'kamerayı aç';

  @override
  String get yemekEkleChooseFromGallery => 'galeriden seç';

  @override
  String get yemekEkleAnalyzing => 'analiz ediliyor...';

  @override
  String get yemekEkleCalories => 'KALORİ';

  @override
  String get yemekEkleProtein => 'PROTEİN';

  @override
  String get yemekEkleCarbs => 'KARBONHİDRAT';

  @override
  String get yemekEkleFat => 'YAĞ';

  @override
  String get yemekEkleIngredients => 'MALZEMELER';

  @override
  String get yemekEkleSaveButton => 'kaydet';

  @override
  String get yemekEkleRetryButton => 'tekrar dene';

  @override
  String get yemekEkleErrorTitle => 'bir şeyler ters gitti';

  @override
  String get yemekEkleIlndThinking => 'ILND düşünüyor...';

  @override
  String get legalBackTooltip => 'Geri';

  @override
  String get ilndFallbackChat1 =>
      'seni dinliyorum. biraz daha anlatmak ister misin?';

  @override
  String get ilndFallbackChat2 =>
      'bunu paylaşman güzel. şu an bedeninde bunu nerede hissediyorsun?';

  @override
  String get ilndFallbackChat3 =>
      'buradayım. bugün sana en çok dokunan şey neydi?';

  @override
  String get ilndFallbackChat4 =>
      'anlıyorum. bunu biraz daha açsak, altında ne var sence?';

  @override
  String get ilndFallbackJournal1 =>
      'bunu yazdığın için teşekkürler. bugün sana iyi gelen tek küçük şey neydi?';

  @override
  String get ilndFallbackJournal2 =>
      'duygularını buraya bırakman değerli. yarın kendine ne dilemek istersin?';

  @override
  String get ilndFallbackJournal3 =>
      'seni duyuyorum. bu hissin sana söylemeye çalıştığı şey ne olabilir?';

  @override
  String get ilndFallbackFood1 =>
      'güzel bir seçim. yanına biraz yeşillik eklersen dengesi tam olur.';

  @override
  String get ilndFallbackFood2 =>
      'iyi görünüyor. bol su içmeyi de unutma, sana iyi gelir.';

  @override
  String get ilndFallbackFood3 =>
      'dengeli bir öğün. protein iyi, sonraki öğünde lif eklemeyi deneyebilirsin.';

  @override
  String get ilndFallbackFood4 =>
      'keyifli görünüyor. suçluluk yok — küçük dokunuşlar yeter, baskı değil.';

  @override
  String streakCopyLongStreak(int days) {
    return '$days gündür kendine sadıksın. bu bir alışkanlık artık.';
  }

  @override
  String streakCopyWeekStreak(int days) {
    return '$days gündür kendine vakit ayırıyorsun.';
  }

  @override
  String streakCopyDayStreak(int days) {
    return '$days. gün — devam ediyorsun.';
  }

  @override
  String get streakCopyRestart =>
      'yeniden başlamak da bir başlangıç. bugün küçük bir adım at.';

  @override
  String get vibeCardHeadlineWeekStreak => 'Bir haftadır kendine sadıksın.';

  @override
  String get vibeCardHeadlineActiveWeek => 'Bu hafta kendine zaman ayırdın.';

  @override
  String get vibeCardHeadlineFirstStep => 'İlk adımı attın bile.';

  @override
  String get vibeCardHeadlineQuietWeek =>
      'Bu hafta sessizdi — yeni haftaya hazır mısın?';

  @override
  String get vibeCardSublineEmpty => 'Her şey küçük bir başlangıçla başlar.';

  @override
  String vibeCardSublineJournalCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count günlük yazdın',
      one: '1 günlük yazdın',
    );
    return '$_temp0';
  }

  @override
  String vibeCardSublineHabitCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alışkanlığı tamamladın',
      one: '1 alışkanlığı tamamladın',
    );
    return '$_temp0';
  }

  @override
  String get a11yToggleTheme => 'Açık/koyu temayı değiştir';

  @override
  String get a11yOpenProfile => 'Profili aç';

  @override
  String get a11yBack => 'Geri';

  @override
  String get a11yClose => 'Kapat';
}
