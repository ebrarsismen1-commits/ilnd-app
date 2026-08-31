// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get loginTagline => 'tekrar hoş geldin.';

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
  String get authOrDivider => 'veya';

  @override
  String get authContinueWithGoogle => 'Google ile devam et';

  @override
  String get authContinueWithApple => 'Apple ile devam et';

  @override
  String get navHome => 'Bugün';

  @override
  String get navExplore => 'Keşfet';

  @override
  String get navCommunity => 'Topluluk';

  @override
  String get navYou => 'Sen';

  @override
  String get navRing => 'ilnd';

  @override
  String get topulukTitle => 'topluluk.';

  @override
  String get topulukTagline => 'şehrinde, yanında';

  @override
  String get topulukComingTitle => 'ilk buluşma yolda';

  @override
  String get topulukComingBody =>
      'İstanbul\'da küçük, sıcak buluşmalarla başlıyoruz: sabah yürüyüşleri, atölyeler, sohbetler. İlk etkinlik duyurusu buraya düşecek.';

  @override
  String get topulukInviteCta => 'arkadaşını şimdiden davet et';

  @override
  String get topulukUpcomingLabel => 'YAKLAŞAN BULUŞMALAR';

  @override
  String get topulukRsvpJoin => 'katıl';

  @override
  String get topulukRsvpGoing => 'geliyorum';

  @override
  String get topulukRsvpFull => 'kontenjan doldu';

  @override
  String topulukGoingCount(int count) {
    return '$count kişi geliyor';
  }

  @override
  String topulukGoingCountOfCapacity(int count, int capacity) {
    return '$count/$capacity kişi geliyor';
  }

  @override
  String get topulukRsvpFailed => 'Kaydedilemedi. Tekrar dener misin?';

  @override
  String socialProofWeekly(int count) {
    return 'Bu hafta $count kişi kendine vakit ayırdı.';
  }

  @override
  String get legalPrivacyTitle => 'Gizlilik Politikası';

  @override
  String get legalTermsTitle => 'Kullanım Şartları';

  @override
  String get startupFailedTitle => 'ilnd başlatılamadı';

  @override
  String get startupFailedBody =>
      'İnternet bağlantını kontrol edip tekrar dene.';

  @override
  String get startupRetry => 'Tekrar dene';

  @override
  String get authErrorInvalidCredentials => 'E-posta veya şifre hatalı.';

  @override
  String get authErrorEmailInUse => 'Bu e-posta adresi zaten kullanılıyor.';

  @override
  String get authErrorWeakPassword => 'Şifre en az 6 karakter olmalı.';

  @override
  String get authErrorUserNotFound => 'Bu e-postayla kayıtlı bir hesap yok.';

  @override
  String get authErrorNetwork =>
      'Bağlantı hatası. İnternet bağlantını kontrol et.';

  @override
  String get authErrorInvalidEmail => 'Geçerli bir e-posta adresi gir.';

  @override
  String get authErrorGeneric => 'Bir şeyler ters gitti. Tekrar dener misin?';

  @override
  String get authErrorConfirmEmail =>
      'Giriş yapılamadı. Önce e-postanı onaylaman gerekiyor olabilir.';

  @override
  String get authErrorUpdatePasswordFailed =>
      'Şifre güncellenemedi. Tekrar dener misin?';

  @override
  String get newPasswordTitle => 'yeni şifreni belirle';

  @override
  String get newPasswordSubtitle =>
      'sıfırlama bağlantısı doğrulandı. şimdi yeni bir şifre seç.';

  @override
  String get newPasswordHint => 'yeni şifre';

  @override
  String get newPasswordConfirmHint => 'yeni şifre (tekrar)';

  @override
  String get newPasswordSubmit => 'şifreyi güncelle';

  @override
  String get newPasswordSuccess => 'Şifren güncellendi. Tekrar hoş geldin';

  @override
  String get authErrorSignupFailed =>
      'Hesabın oluşturulamadı. Tekrar dener misin?';

  @override
  String get authErrorSignOutFailed => 'Çıkış yapılamadı. Tekrar dener misin?';

  @override
  String get authErrorGoogleFailed =>
      'Google ile giriş yapılamadı. Tekrar dener misin?';

  @override
  String get authErrorAppleFailed =>
      'Apple ile giriş yapılamadı. Tekrar dener misin?';

  @override
  String get authErrorResetFailed =>
      'E-posta gönderilemedi. İnternet bağlantını kontrol et.';

  @override
  String get authErrorResetLinkInvalid =>
      'Şifre sıfırlama bağlantısının süresi dolmuş ya da daha önce kullanılmış. Yeni bir bağlantı iste.';

  @override
  String get authErrorDeleteUnavailable => 'Hesap silme şu an kullanılamıyor.';

  @override
  String get authErrorDeleteFailed => 'Hesap silinemedi. Tekrar dener misin?';

  @override
  String get crisisTitle => 'yanında gerçek biri olsun';

  @override
  String get crisisBody =>
      'Zor bir andan geçiyor olabilirsin ve bunu paylaşman değerli. ILND bir yapay zekâ. Böyle anlarda konuşabileceğin gerçek insanlar var:';

  @override
  String get crisisLine112 => '112 · Acil Yardım';

  @override
  String get crisisLine183 => '183 · Sosyal Destek Hattı (7/24, ücretsiz)';

  @override
  String get crisisDismiss => 'anladım';

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
  String get registerSuccess => 'Hesabın oluşturuldu! Hoş geldin';

  @override
  String get registerConfirmEmailSent =>
      'Onay bağlantısı e-postana gönderildi. Gelen kutunu (gerekirse spam klasörünü) kontrol et, sonra giriş yap.';

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
  String get welcomeBeatMemory => 'ILND yazdıklarından öğrenir, seni hatırlar';

  @override
  String get welcomeBeatCommunity =>
      'şehrindeki buluşmalarda yüz yüze görüşürüz';

  @override
  String get adanLabel => 'ADAN';

  @override
  String get adanTitle => 'adan.';

  @override
  String get adanLead => 'ada, tamamladığın işlerden büyüyor.';

  @override
  String get adanBody =>
      'her iş bir öğe kazandırır: fener, fırın, ay ışığı. öğeler adaya yerleşir, ada hafızanın haritası olur. hiçbir şey silinmez. sessiz geçen günler suyu koyulaştırır, cezalandırmaz.';

  @override
  String get adanItemsLabel => 'ÖĞELER';

  @override
  String get adanStateOpen => 'AÇIK';

  @override
  String get adanStateLocked => 'KİLİTLİ';

  @override
  String get adanItemLantern => 'fener';

  @override
  String get adanItemPine => 'çam';

  @override
  String get adanItemOven => 'fırın';

  @override
  String get adanItemMoonlight => 'ay ışığı';

  @override
  String get adanItemWindrose => 'rüzgâr gülü';

  @override
  String get adanItemMeetingStone => 'buluşma taşı';

  @override
  String get adanHowLantern => 'ilk günlük';

  @override
  String get adanHowPine => '3 gün seri';

  @override
  String get adanHowOven => '10 öğün yazıldı';

  @override
  String get adanHowMoonlight => 'ilk gece ritüeli';

  @override
  String get adanHowWindrose => '7 günlük seri';

  @override
  String get adanHowMeetingStone => 'ilk topluluk buluşması';

  @override
  String get adanEarnedSuffix => 'kazanıldı';

  @override
  String get adanEmptyProgress => 'henüz öğe yok';

  @override
  String get profileStatIslandItems => 'ADA ÖĞESİ';

  @override
  String get welcomeBeatIsland => 'her gün üç küçük iş, bitince adan büyür';

  @override
  String adanProgress(int count, String next) {
    return '$count öğe · sıradaki: $next';
  }

  @override
  String adanCanvasSemantics(int count) {
    return 'ada görseli, $count öğe yerleşti';
  }

  @override
  String adanNextNote(String next, String how) {
    return '$next $how tamamlandığında yerleşecek.';
  }

  @override
  String get welcomeStart => 'başla';

  @override
  String get welcomeHaveAccount => 'zaten hesabın var mı? ';

  @override
  String get welcomeLoginLink => 'giriş yap';

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
  String get quickSetupBodyTitle => 'birkaç rakam daha';

  @override
  String get quickSetupBodySubtitle => 'önerileri sana göre ayarlamak için';

  @override
  String get quickSetupAgeHint => 'yaş';

  @override
  String get quickSetupHeightHint => 'boy (cm)';

  @override
  String get quickSetupWeightHint => 'kilo (kg)';

  @override
  String get quickSetupActivityTitle => 'ne kadar hareketlisin?';

  @override
  String get quickSetupActivitySedentary => 'az hareketli';

  @override
  String get quickSetupActivityModerate => 'orta';

  @override
  String get quickSetupActivityActive => 'aktif';

  @override
  String get quickSetupDietTitle => 'beslenme tercihin var mı?';

  @override
  String get quickSetupDietNone => 'yok';

  @override
  String get quickSetupDietVegetarian => 'vejetaryen';

  @override
  String get quickSetupDietVegan => 'vegan';

  @override
  String get quickSetupDietGlutenFree => 'glütensiz';

  @override
  String get quickSetupDietLactoseFree => 'laktozsuz';

  @override
  String get quickSetupAllergiesTitle => 'alerjin var mı?';

  @override
  String get quickSetupAllergiesSubtitle => 'varsa seç, yoksa geç';

  @override
  String get quickSetupAllergyNuts => 'fındık/kabuklu yemiş';

  @override
  String get quickSetupAllergyDairy => 'süt/laktoz';

  @override
  String get quickSetupAllergyGluten => 'gluten';

  @override
  String get quickSetupAllergySeafood => 'deniz ürünü';

  @override
  String get quickSetupAllergyEgg => 'yumurta';

  @override
  String get quickSetupInviteCodeTitle => 'davet kodun var mı?';

  @override
  String get quickSetupInviteCodeHint => 'davet kodu';

  @override
  String get quickSetupHaveInviteCode => 'davet kodum var';

  @override
  String get quickSetupContinue => 'devam et';

  @override
  String get firstEntryHeader => 'BAŞLAYALIM';

  @override
  String get firstEntrySkip => 'şimdi değil';

  @override
  String get firstEntryNeedsPrompt => 'neye ihtiyacın var?';

  @override
  String get firstEntryNeedsLoading =>
      'senin için birkaç öneri hazırlıyorum...';

  @override
  String get homeTrackRowSubtitle => 'öğünler, su, alışkanlıklar';

  @override
  String get homeWeeklyCardRowTitle => 'haftalık kartın hazır';

  @override
  String get homeWeeklyCardRowSubtitle => 'paylaş ya da sadece sen gör';

  @override
  String get homeTodaysReadTitle => 'BUGÜNÜN OKUMASI';

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
  String homeMoodAnsweredToday(String mood) {
    return 'bugün: $mood';
  }

  @override
  String homeReadTimeArrow(String readTime) {
    return '$readTime oku →';
  }

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
      'bugün nasıl hissettiğini ya da aklından geçeni yaz. ILND seninle düşünür.';

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
  String get profilePhotoFromGallery => 'galeriden seç';

  @override
  String get profilePhotoRemove => 'fotoğrafı kaldır';

  @override
  String get profilePhotoUpdated => 'profil fotoğrafın güncellendi';

  @override
  String get profilePhotoTooLarge =>
      'bu resim çok büyük, daha küçük bir tane seç';

  @override
  String get profilePhotoFailed => 'fotoğraf yüklenemedi';

  @override
  String get a11yEditPhoto => 'Profil fotoğrafını değiştir';

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
  String get profileBadgesLabel => 'ROZETLER';

  @override
  String get profileBadgeFirstStep => 'ilk adım';

  @override
  String get profileBadgeSevenDays => '7 gün';

  @override
  String get profileBadgeReader => 'okur';

  @override
  String get profileBadgeThirtyDays => '30 gün';

  @override
  String get profileWeekdaysShort => 'Pt,Sa,Ça,Pe,Cu,Ct,Pa';

  @override
  String get profileWeekEmpty => 'bu hafta henüz iz yok. acelesi de yok.';

  @override
  String get profileWeeklySummaryLabel => 'HAFTALIK ÖZET';

  @override
  String get profileThisWeek => 'bu hafta';

  @override
  String get profileMealsAdded => 'yemek eklendi';

  @override
  String get profileDayStreak => 'gün serisi';

  @override
  String get profileJournalEntriesWritten => 'günlük yazıldı';

  @override
  String get profileSynced => 'senkronize';

  @override
  String get profilePremiumMember => 'ILND+ üyesisin';

  @override
  String get profileGoPremium => 'ILND+\'a geç';

  @override
  String get profilePreferences => 'bilgilerin ve tercihlerin';

  @override
  String get preferencesTitle => 'tercihler';

  @override
  String get preferencesNameLabel => 'AD';

  @override
  String get preferencesGoalsLabel => 'HEDEFLER';

  @override
  String get preferencesBodyLabel => 'BEDEN';

  @override
  String get preferencesActivityLabel => 'HAREKET';

  @override
  String get preferencesDietLabel => 'BESLENME';

  @override
  String get preferencesAllergiesLabel => 'ALERJİLER';

  @override
  String get preferencesAllergiesHelp => 'ILND tarif önerirken bunları eler.';

  @override
  String get preferencesGoalsHelp =>
      'Bugün ekranındaki okuma bunlara göre seçilir.';

  @override
  String get preferencesSave => 'kaydet';

  @override
  String get preferencesSaved => 'Tercihlerin güncellendi.';

  @override
  String get preferencesSaveFailed => 'Kaydedilemedi. Tekrar dener misin?';

  @override
  String get profileSettingsLabel => 'AYARLAR';

  @override
  String get profileInviteFriend => 'arkadaşını davet et';

  @override
  String get profilePrivacyPolicy => 'gizlilik politikası';

  @override
  String get profileTermsOfService => 'kullanım şartları';

  @override
  String get profileSignedOut => 'Çıkış yapıldı. Görüşürüz';

  @override
  String get profileSignOut => 'çıkış yap';

  @override
  String get profileDeleteAccount => 'hesabımı sil';

  @override
  String get journalDeleteTitle => 'Bu girdiyi sil';

  @override
  String get journalDeleteBody =>
      'Bu yazı kalıcı olarak silinecek. O günü yazmış olman değişmiyor, serin bozulmuyor.';

  @override
  String get journalDeleted => 'Girdi silindi.';

  @override
  String get journalDeleteFailed => 'Silinemedi. Tekrar dener misin?';

  @override
  String get habitDeleteTitle => 'Bu alışkanlığı sil';

  @override
  String get habitDeleteBody =>
      'Alışkanlık ve geçmiş işaretlemeleri listeden kalkacak.';

  @override
  String get habitDeleted => 'Alışkanlık silindi.';

  @override
  String get habitDeleteFailed => 'Silinemedi. Tekrar dener misin?';

  @override
  String get deleteAction => 'sil';

  @override
  String get cancelAction => 'vazgeç';

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
  String get profileAccountDeleted => 'Hesabın silindi. Kendine iyi bak';

  @override
  String get exploreTitle => 'keşfet.';

  @override
  String get exploreSubtitle => 'iyi hissetmenin küçük adımları';

  @override
  String get exploreFilterMeditation => 'meditasyon';

  @override
  String get exploreFilterRecipes => 'tarifler';

  @override
  String get exploreFilterNutrition => 'beslenme';

  @override
  String get exploreFilterMovement => 'hareket';

  @override
  String get exploreFilterSelfCare => 'öz bakım';

  @override
  String get exploreFilterGrowth => 'gelişim';

  @override
  String get exploreFilterAll => 'hepsi';

  @override
  String get exploreFilterEmpty => 'bu etikette henüz yazı yok';

  @override
  String get exploreMoreLabel => 'DAHA FAZLA';

  @override
  String get exploreRitualsLabel => 'RİTÜELLER';

  @override
  String get exploreRitualBreathTitle => '2 dk nefes';

  @override
  String get exploreRitualSleepTitle => 'gece ritüeli';

  @override
  String get exploreRitualMovementTitle => 'hareket molası';

  @override
  String get sleepRitualTitle => 'uyku ritüeli';

  @override
  String get sleepRitualPreparing => 'ilnd bu geceni hazırlıyor…';

  @override
  String get recipeNutritionLabel => 'PORSİYON BAŞINA';

  @override
  String get recipeNutritionApprox =>
      'yaklaşık değerler, malzemeye göre değişir';

  @override
  String get recipeNutritionFiber => 'lif';

  @override
  String get articleSourcesLabel => 'KAYNAKLAR';

  @override
  String get recipeIngredientsTitle => 'malzemeler';

  @override
  String get recipeStartCooking => 'pişirmeye başla';

  @override
  String recipeStepProgress(int current, int total) {
    return 'adım $current / $total';
  }

  @override
  String get recipeNextButton => 'sonraki adım';

  @override
  String get recipeFinishButton => 'afiyet olsun';

  @override
  String get breathScreenTitle => 'nefes';

  @override
  String breathMinutesChip(int minutes) {
    return '$minutes dk';
  }

  @override
  String get breathPhaseInhale => 'al';

  @override
  String get breathPhaseHold => 'tut';

  @override
  String get breathPhaseExhale => 'ver';

  @override
  String breathCycleProgress(int current, int total) {
    return 'nefes $current / $total';
  }

  @override
  String get breathDoneTitle => 'güzel nefes aldın.';

  @override
  String get breathAgainButton => 'bir tur daha';

  @override
  String get breathCloseButton => 'kapat';

  @override
  String get sleepRitualContinueButton => 'devam';

  @override
  String get sleepRitualSkipButton => 'geç';

  @override
  String get sleepRitualFinishButton => 'iyi geceler';

  @override
  String sleepRitualStepProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get sleepRitualStepPrepTitle => 'hazırlık';

  @override
  String get sleepRitualPrepItemLights => 'ışıkları kıs';

  @override
  String get sleepRitualPrepItemPhone => 'telefonu sessize al';

  @override
  String get sleepRitualPrepItemBed => 'yatağını hazırla';

  @override
  String get sleepRitualUnloadPrompt =>
      'yarına kalan bir düşünceyi buraya bırak';

  @override
  String get sleepRitualUnloadHint => 'aklındakini tek cümleyle yaz…';

  @override
  String get sleepRitualGratitudePrompt =>
      'bugünden aklında kalan güzel bir an';

  @override
  String get sleepRitualGratitudeHint => 'küçük bir şey de olur…';

  @override
  String get sleepRitualClosing1 => 'bugün buradaydın, bu yeter. iyi uykular.';

  @override
  String get sleepRitualClosing2 =>
      'gün bitti, yükünü bıraktın. şimdi dinlenme zamanı.';

  @override
  String get sleepRitualClosing3 => 'yarın yeni bir sayfa. bu gece sadece uyu.';

  @override
  String get sleepRitualClosing4 =>
      'kendine bu alanı açtığın için teşekkürler. iyi geceler.';

  @override
  String get sleepRitualHomeCardTitle => 'gece ritüeline hazır mısın?';

  @override
  String get sleepRitualHomeCardSubtitle => 'birkaç dakika, sonra uyku';

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
  String get referralTitle => 'arkadaşını davet et';

  @override
  String get referralSubtitle => 'kodunu paylaş, ikiniz de ödül kazanın';

  @override
  String get referralEnterCode => 'davet kodu gir';

  @override
  String get vibeCardShareText => 'ilnd\'deki ruh halimi paylaşıyorum';

  @override
  String vibeCardShareTextWithCode(String code) {
    return 'ilnd\'deki ruh halimi paylaşıyorum davet kodum: $code';
  }

  @override
  String get streakCardHeadlineWeek =>
      'Bir haftadır her gün kendine dönüyorsun.';

  @override
  String get streakCardHeadlineMonth =>
      'Bir aydır her gün buradasın. Bunu az insan yapar.';

  @override
  String get streakCardHeadlineHundred => '100 gün. Sessizce, istikrarla.';

  @override
  String get streakCardDaysLabel => 'gün üst üste';

  @override
  String streakCardShareText(int days) {
    return 'ilnd\'de $days gündür buradayım';
  }

  @override
  String streakCardShareTextWithCode(int days, String code) {
    return 'ilnd\'de $days gündür buradayım davet kodum: $code';
  }

  @override
  String get chatQuoteCardButton => 'Karta çevir';

  @override
  String get quoteCardShareText => 'ilnd bugün bana bunu dedi';

  @override
  String quoteCardShareTextWithCode(String code) {
    return 'ilnd bugün bana bunu dedi davet kodum: $code';
  }

  @override
  String vibeCardInviteCode(String code) {
    return 'davet kodum: $code';
  }

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
  String get chatPaywallReason => 'bu hafta benimle çok konuştun';

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
  String get chatListening => 'ilnd · seni dinliyor';

  @override
  String get redeemCodeSuccess => 'Davet kodu kullanıldı!';

  @override
  String get redeemCodeInvalid => 'Böyle bir davet kodu yok. Tekrar bak.';

  @override
  String get redeemCodeSelfReferral =>
      'Bu senin kendi kodun Bir arkadaşının kodunu dene.';

  @override
  String get redeemCodeAlreadyUsed => 'Zaten bir davet kodu kullanmışsın.';

  @override
  String get redeemCodeNotReady =>
      'Hesabın daha hazırlanıyor. Birkaç saniye sonra tekrar dene.';

  @override
  String get redeemCodeNetworkError =>
      'Bağlanamadık. İnternetini kontrol edip tekrar dene.';

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
    return 'benimle ilnd\'e katıl! davet kodum: $code';
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
  String get takipHabitsDoneLabel => 'ALIŞKANLIK TAMAM';

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
  String get ekleHabitSubtitle => 'yeni alışkanlık ekle';

  @override
  String get ekleWaterTitle => 'su';

  @override
  String get ekleWaterSubtitle => 'bir bardak ekle';

  @override
  String get ekleSheetSubtitle => 'ne yapmak istersin?';

  @override
  String get ekleAskIlndTitle => 'ILND\'ye sor';

  @override
  String get ekleAskIlndSubtitle => 'aklındakini konuş';

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
  String get yemekEklePaywallReason => 'bugünlük yemek analizi hakkın doldu';

  @override
  String get yemekEklePhotoAccessError => 'Fotoğrafa erişilemedi. Tekrar dene.';

  @override
  String get yemekEkleAnalysisFailed =>
      'Analiz başarısız oldu. Tekrar dener misin?';

  @override
  String get yemekEkleUnsupportedImage =>
      'Bu görsel biçimi desteklenmiyor. JPEG veya PNG bir fotoğraf dener misin?';

  @override
  String get yemekEklePhotoTooLarge =>
      'Fotoğraf çok büyük. Daha küçük bir fotoğraf dener misin?';

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
  String get yemekEkleProtein => 'PROTEİN';

  @override
  String get yemekEkleCarbs => 'KARBONHİDRAT';

  @override
  String get yemekEkleFat => 'YAĞ';

  @override
  String get yemekEkleIngredients => 'MALZEMELER';

  @override
  String get yemekEklePortionQuestion => 'Tabakta ne kadar vardı?';

  @override
  String get yemekEklePortionHint =>
      'Tahmin yanlışsa buradan ayarla, değerler güncellenir.';

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
  String get ilndFallbackGreeting1 => 'iyi ki geldin. bugün nasıl geçiyor?';

  @override
  String get ilndFallbackGreeting2 =>
      'buradayım. anlatmak istediğin bir şey var mı, yoksa biraz sessizce mi takılalım?';

  @override
  String get ilndFallbackGreeting3 =>
      'selam. bugün kendine nasıl davranıyorsun?';

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
      'keyifli görünüyor. suçluluk yok. küçük dokunuşlar yeter, baskı değil.';

  @override
  String get ilndFallbackNeed1 => 'kısa bir nefes molası';

  @override
  String get ilndFallbackNeed2 => 'güne uygun bir tarif';

  @override
  String get ilndFallbackNeed3 => 'cilt bakım rutini';

  @override
  String get ilndFallbackNeed4 => 'küçük bir hareket önerisi';

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
    return '$days. gün, devam ediyorsun.';
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
      'Bu hafta sessizdi. Yeni haftaya hazır mısın?';

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
      other: '$count alışkanlık tamamladın',
      one: '1 alışkanlık tamamladın',
    );
    return '$_temp0';
  }

  @override
  String get a11yToggleTheme => 'Açık/koyu temayı değiştir';

  @override
  String get a11yOpenProfile => 'Profili aç';

  @override
  String get a11yOpenIlnd => 'ILND\'yi aç';

  @override
  String get a11yBack => 'Geri';

  @override
  String get a11yClose => 'Kapat';

  @override
  String get reminderSettingLabel => 'Günlük hatırlatma';

  @override
  String get reminderSettingSubtitle => 'Gün geçip gitmeden nazik bir dokunuş';

  @override
  String reminderTimeLabel(String time) {
    return 'Saat: $time';
  }

  @override
  String get reminderNotificationTitle => 'Kendine bir alan aç';

  @override
  String get reminderNotificationBody =>
      'Bugün için küçük bir an yeter. Bir cümle, bir nefes. ILND burada.';

  @override
  String get reminderPermissionDenied =>
      'Bildirim izni verilmedi. Cihaz ayarlarından izin verirsen hatırlatabilirim.';

  @override
  String get planShelfLabel => 'PLANLAR';

  @override
  String planDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün',
      one: '1 gün',
    );
    return '$_temp0';
  }

  @override
  String planProgress(int done, int total) {
    return '$done/$total gün';
  }

  @override
  String get planStart => 'başla';

  @override
  String planContinue(int day) {
    return '$day. güne devam et';
  }

  @override
  String get planAllDone => 'planı tamamladın';

  @override
  String get planDayDone => 'tamamlandı';

  @override
  String planDayLabel(int day) {
    return '$day. gün';
  }

  @override
  String get planDayComplete => 'bugünü tamamla';

  @override
  String get planDayRead => 'günün okuması';

  @override
  String get planDayAction => 'günün adımı';

  @override
  String get planActionBreath => 'nefes al';

  @override
  String get planActionMove => 'hareket et';

  @override
  String get planActionWater => 'su iç';

  @override
  String get planActionJournal => 'günlüğüne yaz';

  @override
  String get planPaywallReason => 'bu plan ILND+ üyelerine özel';

  @override
  String get planPremiumBadge => 'ILND+';

  @override
  String get planSwitchTitle => 'Devam eden planın var';

  @override
  String planSwitchBody(String title) {
    return '$title planı duraklar, ilerlemen kaybolmaz. Yeni plana geçilsin mi?';
  }

  @override
  String get planSwitchConfirm => 'geç';

  @override
  String get planSwitchCancel => 'vazgeç';

  @override
  String get homeActivePlanLabel => 'PLANIN';

  @override
  String get movementShelfLabel => 'HAREKET PROGRAMLARI';

  @override
  String get movementLevelEasy => 'yumuşak';

  @override
  String get movementLevelMedium => 'orta';

  @override
  String get movementLevelStrong => 'güçlü';

  @override
  String movementSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seans',
      one: '1 seans',
    );
    return '$_temp0';
  }

  @override
  String movementMinutes(int m) {
    return '$m dk';
  }

  @override
  String movementProgress(int done, int total) {
    return '$done/$total seans';
  }

  @override
  String get movementStart => 'başla';

  @override
  String get movementContinue => 'devam et';

  @override
  String get movementReplay => 'yeniden izle';

  @override
  String get movementAllDone => 'programı tamamladın';

  @override
  String get movementSessionDone => 'tamamlandı';

  @override
  String get movementPlayerError => 'video şu an açılamadı';

  @override
  String get movementPlayerRetry => 'tekrar dene';

  @override
  String get movementPaywallReason => 'bu program ILND+ üyelerine özel';

  @override
  String get movementPremiumBadge => 'ILND+';

  @override
  String get a11yMovementPlay => 'Videoyu oynat';

  @override
  String get a11yMovementPause => 'Videoyu duraklat';
}
