import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// Login screen tagline below the logo
  ///
  /// In tr, this message translates to:
  /// **'hoş geldin geri.'**
  String get loginTagline;

  /// Login email field placeholder
  ///
  /// In tr, this message translates to:
  /// **'e-posta'**
  String get loginEmailHint;

  /// Login password field placeholder
  ///
  /// In tr, this message translates to:
  /// **'şifre'**
  String get loginPasswordHint;

  /// Forgot password link
  ///
  /// In tr, this message translates to:
  /// **'şifremi unuttum'**
  String get loginForgotPassword;

  /// Login submit button
  ///
  /// In tr, this message translates to:
  /// **'giriş yap'**
  String get loginSubmit;

  /// Prefix before register link
  ///
  /// In tr, this message translates to:
  /// **'hesabın yok mu? '**
  String get loginNoAccount;

  /// Register link on login screen
  ///
  /// In tr, this message translates to:
  /// **'kayıt ol'**
  String get loginRegisterLink;

  /// Shown when requesting password reset without a valid email
  ///
  /// In tr, this message translates to:
  /// **'Önce geçerli bir e-posta adresi gir.'**
  String get loginEnterValidEmailFirst;

  /// Shown after password reset email is sent
  ///
  /// In tr, this message translates to:
  /// **'Şifre sıfırlama bağlantısı e-postana gönderildi.'**
  String get loginResetLinkSent;

  /// Divider label between email form and social sign-in buttons
  ///
  /// In tr, this message translates to:
  /// **'veya'**
  String get authOrDivider;

  /// Google sign-in button label
  ///
  /// In tr, this message translates to:
  /// **'Google ile devam et'**
  String get authContinueWithGoogle;

  /// Apple sign-in button label
  ///
  /// In tr, this message translates to:
  /// **'Apple ile devam et'**
  String get authContinueWithApple;

  /// Bottom nav: home tab
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get navHome;

  /// Bottom nav: explore tab
  ///
  /// In tr, this message translates to:
  /// **'Keşfet'**
  String get navExplore;

  /// Bottom nav: tracking tab
  ///
  /// In tr, this message translates to:
  /// **'Takip'**
  String get navTracking;

  /// Bottom nav: profile tab
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// Bottom nav: community tab
  ///
  /// In tr, this message translates to:
  /// **'Topluluk'**
  String get navCommunity;

  /// Bottom nav: you tab (profile+tracking)
  ///
  /// In tr, this message translates to:
  /// **'Sen'**
  String get navYou;

  /// Center breathing ring label
  ///
  /// In tr, this message translates to:
  /// **'ilnd'**
  String get navRing;

  /// Accessibility label for the center ring
  ///
  /// In tr, this message translates to:
  /// **'ILND ile sohbeti aç'**
  String get a11yOpenChat;

  /// Community screen title
  ///
  /// In tr, this message translates to:
  /// **'topluluk.'**
  String get topulukTitle;

  /// Community screen tagline
  ///
  /// In tr, this message translates to:
  /// **'şehrinde, yanında'**
  String get topulukTagline;

  /// Community v1 coming-soon headline
  ///
  /// In tr, this message translates to:
  /// **'ilk buluşma yolda'**
  String get topulukComingTitle;

  /// Community v1 coming-soon body
  ///
  /// In tr, this message translates to:
  /// **'İstanbul\'da küçük, sıcak buluşmalarla başlıyoruz — sabah yürüyüşleri, atölyeler, sohbetler. İlk etkinlik duyurusu buraya düşecek.'**
  String get topulukComingBody;

  /// Community v1 CTA routing to referral
  ///
  /// In tr, this message translates to:
  /// **'arkadaşını şimdiden davet et'**
  String get topulukInviteCta;

  /// Anonymous aggregate social proof badge
  ///
  /// In tr, this message translates to:
  /// **'Bu hafta {count} kişi kendine vakit ayırdı.'**
  String socialProofWeekly(int count);

  /// Privacy policy screen title
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik Politikası'**
  String get legalPrivacyTitle;

  /// Terms of service screen title
  ///
  /// In tr, this message translates to:
  /// **'Kullanım Şartları'**
  String get legalTermsTitle;

  /// Shown when Supabase init fails at startup
  ///
  /// In tr, this message translates to:
  /// **'ilnd başlatılamadı'**
  String get startupFailedTitle;

  /// Startup failure explanation
  ///
  /// In tr, this message translates to:
  /// **'İnternet bağlantını kontrol edip tekrar dene.'**
  String get startupFailedBody;

  /// Startup failure retry button
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get startupRetry;

  /// Auth error: wrong email/password
  ///
  /// In tr, this message translates to:
  /// **'E-posta veya şifre hatalı.'**
  String get authErrorInvalidCredentials;

  /// Auth error: email already registered
  ///
  /// In tr, this message translates to:
  /// **'Bu e-posta adresi zaten kullanılıyor.'**
  String get authErrorEmailInUse;

  /// Auth error: weak password
  ///
  /// In tr, this message translates to:
  /// **'Şifre en az 6 karakter olmalıdır.'**
  String get authErrorWeakPassword;

  /// Auth error: user not found
  ///
  /// In tr, this message translates to:
  /// **'Bu e-posta ile kayıtlı kullanıcı bulunamadı.'**
  String get authErrorUserNotFound;

  /// Auth error: network problem
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı hatası. İnternet bağlantınızı kontrol edin.'**
  String get authErrorNetwork;

  /// Auth error: invalid email format
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir e-posta adresi girin.'**
  String get authErrorInvalidEmail;

  /// Auth error: generic fallback
  ///
  /// In tr, this message translates to:
  /// **'Bir hata oluştu. Lütfen tekrar deneyin.'**
  String get authErrorGeneric;

  /// Auth error: sign-in returned no session
  ///
  /// In tr, this message translates to:
  /// **'Giriş yapılamadı. E-posta onayı gerekiyor olabilir.'**
  String get authErrorConfirmEmail;

  /// Auth error: sign-up failed
  ///
  /// In tr, this message translates to:
  /// **'Kayıt oluşturulamadı. Lütfen tekrar deneyin.'**
  String get authErrorSignupFailed;

  /// Auth error: sign-out failed
  ///
  /// In tr, this message translates to:
  /// **'Çıkış yapılamadı. Tekrar dener misin?'**
  String get authErrorSignOutFailed;

  /// Auth error: Google sign-in failed
  ///
  /// In tr, this message translates to:
  /// **'Google ile giriş yapılamadı. Tekrar dener misin?'**
  String get authErrorGoogleFailed;

  /// Auth error: Apple sign-in failed
  ///
  /// In tr, this message translates to:
  /// **'Apple ile giriş yapılamadı. Tekrar dener misin?'**
  String get authErrorAppleFailed;

  /// Auth error: password reset email failed
  ///
  /// In tr, this message translates to:
  /// **'E-posta gönderilemedi. İnternet bağlantınızı kontrol edin.'**
  String get authErrorResetFailed;

  /// Auth error: delete account service unavailable
  ///
  /// In tr, this message translates to:
  /// **'Hesap silme servisi şu an kullanılamıyor.'**
  String get authErrorDeleteUnavailable;

  /// Auth error: delete account failed
  ///
  /// In tr, this message translates to:
  /// **'Hesap silinemedi. Tekrar dener misin?'**
  String get authErrorDeleteFailed;

  /// Crisis resource sheet title
  ///
  /// In tr, this message translates to:
  /// **'yanında gerçek biri olsun'**
  String get crisisTitle;

  /// Crisis resource sheet body
  ///
  /// In tr, this message translates to:
  /// **'Zor bir andan geçiyor olabilirsin ve bunu paylaşman değerli. ILND bir yapay zekâ — böyle anlarda konuşabileceğin gerçek insanlar var:'**
  String get crisisBody;

  /// Emergency line
  ///
  /// In tr, this message translates to:
  /// **'112 — Acil Yardım'**
  String get crisisLine112;

  /// Psychosocial support line
  ///
  /// In tr, this message translates to:
  /// **'183 — Sosyal Destek Hattı (7/24, ücretsiz)'**
  String get crisisLine183;

  /// Crisis sheet dismiss button
  ///
  /// In tr, this message translates to:
  /// **'anladım'**
  String get crisisDismiss;

  /// Register screen tagline below the logo
  ///
  /// In tr, this message translates to:
  /// **'hesap oluştur.'**
  String get registerTagline;

  /// Register name field placeholder
  ///
  /// In tr, this message translates to:
  /// **'adın'**
  String get registerNameHint;

  /// Register email field placeholder
  ///
  /// In tr, this message translates to:
  /// **'e-posta'**
  String get registerEmailHint;

  /// Register password field placeholder
  ///
  /// In tr, this message translates to:
  /// **'şifre'**
  String get registerPasswordHint;

  /// Register confirm-password field placeholder
  ///
  /// In tr, this message translates to:
  /// **'şifreyi tekrarla'**
  String get registerConfirmPasswordHint;

  /// Terms acceptance text, part 1
  ///
  /// In tr, this message translates to:
  /// **'kayıt olarak '**
  String get registerTermsPrefix;

  /// Terms of Service link text
  ///
  /// In tr, this message translates to:
  /// **'Kullanım Şartları'**
  String get registerTermsOfService;

  /// Terms acceptance text, 'and' connector
  ///
  /// In tr, this message translates to:
  /// **' ve '**
  String get registerTermsAnd;

  /// Privacy Policy link text
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik Politikası\'nı'**
  String get registerPrivacyPolicy;

  /// Terms acceptance text, suffix
  ///
  /// In tr, this message translates to:
  /// **' kabul ediyorsun.'**
  String get registerTermsSuffix;

  /// Register submit button
  ///
  /// In tr, this message translates to:
  /// **'kayıt ol'**
  String get registerSubmit;

  /// Prefix before login link
  ///
  /// In tr, this message translates to:
  /// **'zaten hesabın var mı? '**
  String get registerHaveAccount;

  /// Login link on register screen
  ///
  /// In tr, this message translates to:
  /// **'giriş yap'**
  String get registerLoginLink;

  /// Shown after successful registration
  ///
  /// In tr, this message translates to:
  /// **'Hesabın oluşturuldu! Hoş geldin 🌿'**
  String get registerSuccess;

  /// Email validation: empty
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresi gerekli.'**
  String get validatorEmailRequired;

  /// Email validation: invalid format
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir e-posta adresi gir.'**
  String get validatorEmailInvalid;

  /// Password validation: empty
  ///
  /// In tr, this message translates to:
  /// **'Şifre gerekli.'**
  String get validatorPasswordRequired;

  /// Password validation: too short
  ///
  /// In tr, this message translates to:
  /// **'Şifre en az 6 karakter olmalı.'**
  String get validatorPasswordTooShort;

  /// Password confirm validation: empty
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi tekrar gir.'**
  String get validatorPasswordConfirmRequired;

  /// Password confirm validation: mismatch
  ///
  /// In tr, this message translates to:
  /// **'Şifreler eşleşmiyor.'**
  String get validatorPasswordMismatch;

  /// Name validation: empty
  ///
  /// In tr, this message translates to:
  /// **'Adını gir.'**
  String get validatorNameRequired;

  /// Name validation: too short
  ///
  /// In tr, this message translates to:
  /// **'Adın en az 2 karakter olmalı.'**
  String get validatorNameTooShort;

  /// Welcome screen tagline (Turkish)
  ///
  /// In tr, this message translates to:
  /// **'günlük tut, ruh halini takip et, ILND\'le konuş.'**
  String get welcomeTagline;

  /// Welcome screen tagline (English subtitle shown alongside Turkish)
  ///
  /// In tr, this message translates to:
  /// **'journal, track your mood, talk to ILND.'**
  String get welcomeTaglineEn;

  /// Welcome screen start button
  ///
  /// In tr, this message translates to:
  /// **'başla'**
  String get welcomeStart;

  /// Quick setup screen title (Turkish)
  ///
  /// In tr, this message translates to:
  /// **'seni biraz tanıyalım'**
  String get quickSetupTitle;

  /// Quick setup screen title (English subtitle)
  ///
  /// In tr, this message translates to:
  /// **'let\'s get to know you a little'**
  String get quickSetupTitleEn;

  /// Quick setup name field placeholder
  ///
  /// In tr, this message translates to:
  /// **'adın ne?'**
  String get quickSetupNameHint;

  /// Quick setup goals section title
  ///
  /// In tr, this message translates to:
  /// **'neye odaklanmak istersin?'**
  String get quickSetupGoalsTitle;

  /// Quick setup goals section subtitle
  ///
  /// In tr, this message translates to:
  /// **'istediğin kadar seçebilirsin'**
  String get quickSetupGoalsSubtitle;

  /// Goal option: calorie/nutrition tracking
  ///
  /// In tr, this message translates to:
  /// **'kalori/besin takibi'**
  String get quickSetupGoalCalories;

  /// Goal option: lose/gain weight
  ///
  /// In tr, this message translates to:
  /// **'kilo vermek/almak'**
  String get quickSetupGoalWeight;

  /// Goal option: more movement
  ///
  /// In tr, this message translates to:
  /// **'daha fazla hareket'**
  String get quickSetupGoalMovement;

  /// Goal option: water/sleep tracking
  ///
  /// In tr, this message translates to:
  /// **'su/uyku takibi'**
  String get quickSetupGoalWaterSleep;

  /// Goal option: building habits
  ///
  /// In tr, this message translates to:
  /// **'alışkanlık oluşturma'**
  String get quickSetupGoalHabit;

  /// Goal option: mood tracking
  ///
  /// In tr, this message translates to:
  /// **'ruh hali takibi'**
  String get quickSetupGoalMood;

  /// Invite code section title
  ///
  /// In tr, this message translates to:
  /// **'davet kodun var mı?'**
  String get quickSetupInviteCodeTitle;

  /// Invite code field placeholder
  ///
  /// In tr, this message translates to:
  /// **'davet kodu'**
  String get quickSetupInviteCodeHint;

  /// Link to reveal the invite code field
  ///
  /// In tr, this message translates to:
  /// **'davet kodum var'**
  String get quickSetupHaveInviteCode;

  /// Quick setup continue button
  ///
  /// In tr, this message translates to:
  /// **'devam et'**
  String get quickSetupContinue;

  /// First entry screen header label
  ///
  /// In tr, this message translates to:
  /// **'İLK GÜNLÜK'**
  String get firstEntryHeader;

  /// Skip first entry
  ///
  /// In tr, this message translates to:
  /// **'şimdi değil'**
  String get firstEntrySkip;

  /// Continue button after ILND's response
  ///
  /// In tr, this message translates to:
  /// **'hazırım'**
  String get firstEntryReady;

  /// Save the first journal entry
  ///
  /// In tr, this message translates to:
  /// **'kaydet'**
  String get firstEntrySave;

  /// First entry writing prompt
  ///
  /// In tr, this message translates to:
  /// **'bugün nasılsın?'**
  String get firstEntryPrompt;

  /// First entry text field hint
  ///
  /// In tr, this message translates to:
  /// **'ne aklından geçiyorsa yaz...'**
  String get firstEntryHint;

  /// Home screen section title for today's article
  ///
  /// In tr, this message translates to:
  /// **'BUGÜNÜN OKUMASI'**
  String get homeTodaysReadTitle;

  /// Home screen section title for daily intention
  ///
  /// In tr, this message translates to:
  /// **'BUGÜNKÜ NİYETİN'**
  String get homeTodaysIntentionTitle;

  /// Greeting shown before 6am
  ///
  /// In tr, this message translates to:
  /// **'iyi geceler'**
  String get homeGreetingNight;

  /// Greeting shown 6am-12pm
  ///
  /// In tr, this message translates to:
  /// **'günaydın'**
  String get homeGreetingMorning;

  /// Greeting shown 12pm-6pm
  ///
  /// In tr, this message translates to:
  /// **'iyi günler'**
  String get homeGreetingDay;

  /// Greeting shown after 6pm
  ///
  /// In tr, this message translates to:
  /// **'iyi akşamlar'**
  String get homeGreetingEvening;

  /// Greeting combined with the user's name
  ///
  /// In tr, this message translates to:
  /// **'{greeting}, {name}'**
  String homeGreetingWithName(String greeting, String name);

  /// Proactive line referencing the user's first goal
  ///
  /// In tr, this message translates to:
  /// **'\"{goal}\" hedefin için buradayım.'**
  String homeProactiveGoal(String goal);

  /// Proactive line when the user has recent notes but no goal
  ///
  /// In tr, this message translates to:
  /// **'son yazdıklarını okudum, konuşmak ister misin?'**
  String get homeProactiveRecentNotes;

  /// Default proactive line when no memory exists yet
  ///
  /// In tr, this message translates to:
  /// **'bugün nasıl geçiyor?'**
  String get homeProactiveDefault;

  /// Mood check-in question
  ///
  /// In tr, this message translates to:
  /// **'şu an nasılsın?'**
  String get homeMoodQuestion;

  /// Mood option: calm
  ///
  /// In tr, this message translates to:
  /// **'sakin'**
  String get homeMoodCalm;

  /// Mood option: good
  ///
  /// In tr, this message translates to:
  /// **'iyi'**
  String get homeMoodGood;

  /// Mood option: okay
  ///
  /// In tr, this message translates to:
  /// **'fena değil'**
  String get homeMoodOkay;

  /// Mood option: tired
  ///
  /// In tr, this message translates to:
  /// **'yorgun'**
  String get homeMoodTired;

  /// Mood option: hard
  ///
  /// In tr, this message translates to:
  /// **'zor'**
  String get homeMoodHard;

  /// Article read time with arrow; readTime already includes its own unit, e.g. '5 dk'
  ///
  /// In tr, this message translates to:
  /// **'{readTime} oku →'**
  String homeReadTimeArrow(String readTime);

  /// Edit the daily intention
  ///
  /// In tr, this message translates to:
  /// **'düzenle'**
  String get homeIntentionEdit;

  /// Daily intention input hint
  ///
  /// In tr, this message translates to:
  /// **'bugün neye odaklanmak istiyorsun?'**
  String get homeIntentionHint;

  /// Save the daily intention
  ///
  /// In tr, this message translates to:
  /// **'kaydet'**
  String get homeIntentionSave;

  /// Journal screen title
  ///
  /// In tr, this message translates to:
  /// **'günlük'**
  String get journalTitle;

  /// Journal error state title
  ///
  /// In tr, this message translates to:
  /// **'bağlantı sorunu'**
  String get journalConnectionError;

  /// Journal error state body
  ///
  /// In tr, this message translates to:
  /// **'günlüğüne şu an erişilemiyor. bağlantını kontrol et.'**
  String get journalConnectionErrorBody;

  /// Journal error state retry button
  ///
  /// In tr, this message translates to:
  /// **'tekrar dene'**
  String get journalRetry;

  /// Journal empty state title
  ///
  /// In tr, this message translates to:
  /// **'henüz bir şey yazmadın'**
  String get journalEmptyTitle;

  /// Journal empty state body
  ///
  /// In tr, this message translates to:
  /// **'bugün nasıl hissettiğini, ya da aklından geçeni yaz. ILND seninle düşünür.'**
  String get journalEmptyBody;

  /// Journal empty state CTA
  ///
  /// In tr, this message translates to:
  /// **'ilk yazını yaz'**
  String get journalWriteFirst;

  /// New journal entry button
  ///
  /// In tr, this message translates to:
  /// **'yeni günlük yaz'**
  String get journalNewEntry;

  /// Comma-separated abbreviated month names, January through December, split at call sites
  ///
  /// In tr, this message translates to:
  /// **'Oca,Şub,Mar,Nis,May,Haz,Tem,Ağu,Eyl,Eki,Kas,Ara'**
  String get journalMonths;

  /// Comma-separated abbreviated weekday names, Monday through Sunday
  ///
  /// In tr, this message translates to:
  /// **'Pt,Sa,Ça,Pe,Cu,Ct,Pa'**
  String get journalWeekdaysShort;

  /// Comma-separated full weekday names, Monday through Sunday
  ///
  /// In tr, this message translates to:
  /// **'Pazartesi,Salı,Çarşamba,Perşembe,Cuma,Cumartesi,Pazar'**
  String get journalWeekdaysLong;

  /// Finish writing a journal entry after ILND's response
  ///
  /// In tr, this message translates to:
  /// **'bitti'**
  String get journalDone;

  /// Save a journal entry
  ///
  /// In tr, this message translates to:
  /// **'kaydet'**
  String get journalSave;

  /// Journal entry text field hint
  ///
  /// In tr, this message translates to:
  /// **'ne düşünüyorsun?'**
  String get journalWritingHint;

  /// Share weekly summary row on profile
  ///
  /// In tr, this message translates to:
  /// **'haftalık özeti paylaş'**
  String get profileShareWeeklySummary;

  /// Fallback display name when none is set
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı'**
  String get profileDefaultUserName;

  /// Memory card heading on profile
  ///
  /// In tr, this message translates to:
  /// **'ILND seni hatırlıyor'**
  String get profileMemoryHeading;

  /// Goals section label in memory card
  ///
  /// In tr, this message translates to:
  /// **'HEDEFLERİN'**
  String get profileGoalsLabel;

  /// Facts-about-you section label in memory card
  ///
  /// In tr, this message translates to:
  /// **'SENİN HAKKINDA'**
  String get profileAboutYouLabel;

  /// Streak stat label
  ///
  /// In tr, this message translates to:
  /// **'seri'**
  String get profileStatStreak;

  /// Points stat label
  ///
  /// In tr, this message translates to:
  /// **'puan'**
  String get profileStatPoints;

  /// Badge count stat label
  ///
  /// In tr, this message translates to:
  /// **'rozet'**
  String get profileStatBadge;

  /// Badges section label
  ///
  /// In tr, this message translates to:
  /// **'ROZETLER'**
  String get profileBadgesLabel;

  /// First-entry badge label
  ///
  /// In tr, this message translates to:
  /// **'ilk adım'**
  String get profileBadgeFirstStep;

  /// 7-day streak badge label
  ///
  /// In tr, this message translates to:
  /// **'7 günlük'**
  String get profileBadgeSevenDays;

  /// Reader badge label
  ///
  /// In tr, this message translates to:
  /// **'okur'**
  String get profileBadgeReader;

  /// 30-day streak badge label
  ///
  /// In tr, this message translates to:
  /// **'30 günlük'**
  String get profileBadgeThirtyDays;

  /// Comma-separated abbreviated weekday names for the weekly bar chart, Monday through Sunday
  ///
  /// In tr, this message translates to:
  /// **'Pt,Sa,Ça,Pe,Cu,Ct,Pa'**
  String get profileWeekdaysShort;

  /// Weekly summary card section label
  ///
  /// In tr, this message translates to:
  /// **'HAFTALIK ÖZET'**
  String get profileWeeklySummaryLabel;

  /// Weekly summary card heading
  ///
  /// In tr, this message translates to:
  /// **'bu hafta'**
  String get profileThisWeek;

  /// Weekly summary: meals added stat label
  ///
  /// In tr, this message translates to:
  /// **'yemek eklendi'**
  String get profileMealsAdded;

  /// Weekly summary: day streak stat label
  ///
  /// In tr, this message translates to:
  /// **'günlük seri'**
  String get profileDayStreak;

  /// Weekly summary: journal entries written stat label
  ///
  /// In tr, this message translates to:
  /// **'günlük yazıldı'**
  String get profileJournalEntriesWritten;

  /// Weekly summary: synced status label
  ///
  /// In tr, this message translates to:
  /// **'senkronize'**
  String get profileSynced;

  /// Shown when the user already has premium
  ///
  /// In tr, this message translates to:
  /// **'ILND+ üyesisin'**
  String get profilePremiumMember;

  /// CTA to upgrade to premium
  ///
  /// In tr, this message translates to:
  /// **'ILND+’a geç'**
  String get profileGoPremium;

  /// Settings section label
  ///
  /// In tr, this message translates to:
  /// **'AYARLAR'**
  String get profileSettingsLabel;

  /// Invite a friend settings row
  ///
  /// In tr, this message translates to:
  /// **'arkadaşını davet et'**
  String get profileInviteFriend;

  /// Generic settings row
  ///
  /// In tr, this message translates to:
  /// **'ayarlar'**
  String get profileSettingsRow;

  /// Privacy policy settings row
  ///
  /// In tr, this message translates to:
  /// **'gizlilik politikası'**
  String get profilePrivacyPolicy;

  /// Terms of service settings row
  ///
  /// In tr, this message translates to:
  /// **'kullanım şartları'**
  String get profileTermsOfService;

  /// Toast shown after signing out
  ///
  /// In tr, this message translates to:
  /// **'Çıkış yapıldı. Görüşürüz 👋'**
  String get profileSignedOut;

  /// Sign out settings row
  ///
  /// In tr, this message translates to:
  /// **'çıkış yap'**
  String get profileSignOut;

  /// Delete account settings row
  ///
  /// In tr, this message translates to:
  /// **'hesabımı sil'**
  String get profileDeleteAccount;

  /// Delete account confirmation dialog title
  ///
  /// In tr, this message translates to:
  /// **'Hesabını sil'**
  String get profileDeleteAccountDialogTitle;

  /// Delete account confirmation dialog body
  ///
  /// In tr, this message translates to:
  /// **'Bu işlem geri alınamaz. Günlüklerin, yemek kayıtların, seri geçmişin ve hesabınla ilgili her şey kalıcı olarak silinir.'**
  String get profileDeleteAccountDialogBody;

  /// Delete account dialog cancel button
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get profileDeleteAccountCancel;

  /// Delete account dialog confirm button
  ///
  /// In tr, this message translates to:
  /// **'Hesabımı sil'**
  String get profileDeleteAccountConfirm;

  /// Toast shown after successful account deletion
  ///
  /// In tr, this message translates to:
  /// **'Hesabın silindi. İyi günler 👋'**
  String get profileAccountDeleted;

  /// Explore screen title
  ///
  /// In tr, this message translates to:
  /// **'keşfet.'**
  String get exploreTitle;

  /// Explore screen subtitle
  ///
  /// In tr, this message translates to:
  /// **'iyi hissetmenin küçük adımları'**
  String get exploreSubtitle;

  /// Explore filter: all
  ///
  /// In tr, this message translates to:
  /// **'hepsi'**
  String get exploreFilterAll;

  /// Explore filter: wellness
  ///
  /// In tr, this message translates to:
  /// **'wellness'**
  String get exploreFilterWellness;

  /// Explore filter: recipes
  ///
  /// In tr, this message translates to:
  /// **'tarifler'**
  String get exploreFilterRecipes;

  /// Explore filter: articles
  ///
  /// In tr, this message translates to:
  /// **'yazılar'**
  String get exploreFilterArticles;

  /// Featured section label
  ///
  /// In tr, this message translates to:
  /// **'ÖNE ÇIKANLAR'**
  String get exploreFeaturedLabel;

  /// See-all link with arrow
  ///
  /// In tr, this message translates to:
  /// **'hepsi →'**
  String get exploreSeeAllArrow;

  /// Story tile: breathing
  ///
  /// In tr, this message translates to:
  /// **'nefes'**
  String get exploreStoryBreathing;

  /// Story tile: sleep
  ///
  /// In tr, this message translates to:
  /// **'uyku'**
  String get exploreStorySleep;

  /// Story tile: water
  ///
  /// In tr, this message translates to:
  /// **'su'**
  String get exploreStoryWater;

  /// Story tile: movement
  ///
  /// In tr, this message translates to:
  /// **'hareket'**
  String get exploreStoryMovement;

  /// Story tile: meditation
  ///
  /// In tr, this message translates to:
  /// **'meditasyon'**
  String get exploreStoryMeditation;

  /// Story tile: self-care
  ///
  /// In tr, this message translates to:
  /// **'öz-bakım'**
  String get exploreStorySelfCare;

  /// Daily quote on explore screen
  ///
  /// In tr, this message translates to:
  /// **'\"Bugün küçük bir adım, yarının büyük farkı.\"'**
  String get exploreQuote;

  /// Daily quote section label
  ///
  /// In tr, this message translates to:
  /// **'günün alıntısı'**
  String get exploreQuoteSubtitle;

  /// Paywall subtitle under the ILND+ heading
  ///
  /// In tr, this message translates to:
  /// **'sınırsız sohbet, daha derin hafıza, kişisel plan.'**
  String get paywallSubtitle;

  /// Paywall benefit: unlimited chat title
  ///
  /// In tr, this message translates to:
  /// **'sınırsız sohbet'**
  String get paywallBenefitUnlimitedChatTitle;

  /// Paywall benefit: unlimited chat subtitle
  ///
  /// In tr, this message translates to:
  /// **'ILND ile istediğin kadar konuş'**
  String get paywallBenefitUnlimitedChatSubtitle;

  /// Paywall benefit: long memory title
  ///
  /// In tr, this message translates to:
  /// **'daha derin hafıza'**
  String get paywallBenefitLongMemoryTitle;

  /// Paywall benefit: long memory subtitle
  ///
  /// In tr, this message translates to:
  /// **'ILND seni daha uzun süre hatırlar'**
  String get paywallBenefitLongMemorySubtitle;

  /// Paywall benefit: proactive support title
  ///
  /// In tr, this message translates to:
  /// **'proaktif destek'**
  String get paywallBenefitProactiveTitle;

  /// Paywall benefit: proactive support subtitle
  ///
  /// In tr, this message translates to:
  /// **'ILND seni düşünür, sana ulaşır'**
  String get paywallBenefitProactiveSubtitle;

  /// Paywall benefit: personal plan title
  ///
  /// In tr, this message translates to:
  /// **'kişisel plan'**
  String get paywallBenefitPersonalPlanTitle;

  /// Paywall benefit: personal plan subtitle
  ///
  /// In tr, this message translates to:
  /// **'hedeflerine göre özelleştirilmiş yol'**
  String get paywallBenefitPersonalPlanSubtitle;

  /// Paywall pricing plan: yearly
  ///
  /// In tr, this message translates to:
  /// **'yıllık'**
  String get paywallYearly;

  /// Paywall pricing plan: free trial note
  ///
  /// In tr, this message translates to:
  /// **'7 gün ücretsiz dene'**
  String get paywallFreeTrial;

  /// Paywall pricing plan: discount badge
  ///
  /// In tr, this message translates to:
  /// **'%40 indirim'**
  String get paywallDiscount;

  /// Paywall purchase button
  ///
  /// In tr, this message translates to:
  /// **'ücretsiz denemeyi başlat'**
  String get paywallStartFreeTrial;

  /// Paywall dismiss link
  ///
  /// In tr, this message translates to:
  /// **'şimdi değil'**
  String get paywallNotNow;

  /// Paywall restore purchases link
  ///
  /// In tr, this message translates to:
  /// **'satın alımları geri yükle'**
  String get paywallRestore;

  /// Toast shown when purchase is cancelled
  ///
  /// In tr, this message translates to:
  /// **'Satın alma iptal edildi.'**
  String get paywallPurchaseCancelled;

  /// Toast shown when purchase fails
  ///
  /// In tr, this message translates to:
  /// **'Satın alma başarısız. Tekrar dene.'**
  String get paywallPurchaseFailed;

  /// Toast shown when restore succeeds
  ///
  /// In tr, this message translates to:
  /// **'Satın alımların geri yüklendi!'**
  String get paywallRestoreSuccess;

  /// Toast shown when there's nothing to restore
  ///
  /// In tr, this message translates to:
  /// **'Aktif abonelik bulunamadı.'**
  String get paywallNoActiveSubscription;

  /// Toast shown when restore fails
  ///
  /// In tr, this message translates to:
  /// **'Geri yükleme başarısız. Tekrar dene.'**
  String get paywallRestoreFailed;

  /// Article detail read time next to category tag; readTime already includes its own unit, e.g. '5 dk'
  ///
  /// In tr, this message translates to:
  /// **'  ·  {readTime}'**
  String articleDetailReadTime(String readTime);

  /// Soft sign-off shown at the end of an article
  ///
  /// In tr, this message translates to:
  /// **'🌿'**
  String get articleDetailSignOff;

  /// Referral screen title
  ///
  /// In tr, this message translates to:
  /// **'arkadaşını davet et'**
  String get referralTitle;

  /// Referral screen subtitle
  ///
  /// In tr, this message translates to:
  /// **'kodunu paylaş, ikiniz de ödül kazanın'**
  String get referralSubtitle;

  /// Button to open the redeem-code sheet
  ///
  /// In tr, this message translates to:
  /// **'davet kodu gir'**
  String get referralEnterCode;

  /// Share sheet text when sharing the vibe card
  ///
  /// In tr, this message translates to:
  /// **'ilnd\'deki ruh halimi paylaşıyorum 🌿'**
  String get vibeCardShareText;

  /// Vibe card error state
  ///
  /// In tr, this message translates to:
  /// **'kart oluşturulamadı.'**
  String get vibeCardError;

  /// Vibe card share button
  ///
  /// In tr, this message translates to:
  /// **'paylaş'**
  String get vibeCardShare;

  /// Toast shown when sharing the vibe card fails
  ///
  /// In tr, this message translates to:
  /// **'Paylaşılamadı. Tekrar dene.'**
  String get vibeCardShareFailed;

  /// Vibe card stat: streak
  ///
  /// In tr, this message translates to:
  /// **'seri'**
  String get vibeCardStatStreak;

  /// Vibe card stat: journal count
  ///
  /// In tr, this message translates to:
  /// **'günlük'**
  String get vibeCardStatJournal;

  /// Vibe card stat: habit completion count
  ///
  /// In tr, this message translates to:
  /// **'alışkanlık'**
  String get vibeCardStatHabit;

  /// Context shown on the paywall when the weekly chat limit is reached
  ///
  /// In tr, this message translates to:
  /// **'bu hafta benimle çok konuştun 🌿'**
  String get chatPaywallReason;

  /// Chat empty state greeting without a name
  ///
  /// In tr, this message translates to:
  /// **'selam.'**
  String get chatGreeting;

  /// Chat empty state greeting with the user's name
  ///
  /// In tr, this message translates to:
  /// **'selam, {name}.'**
  String chatGreetingWithName(String name);

  /// Chat empty state prompt
  ///
  /// In tr, this message translates to:
  /// **'ne düşünüyorsun? seninle buradayım.'**
  String get chatEmptyPrompt;

  /// Chat message composer hint
  ///
  /// In tr, this message translates to:
  /// **'bir şey yaz...'**
  String get chatComposerHint;

  /// Toast shown when a referral code is redeemed successfully
  ///
  /// In tr, this message translates to:
  /// **'Davet kodu kullanıldı! 🎉'**
  String get redeemCodeSuccess;

  /// Toast shown when a referral code can't be redeemed
  ///
  /// In tr, this message translates to:
  /// **'Geçersiz kod ya da zaten kullanılmış.'**
  String get redeemCodeInvalid;

  /// Redeem code bottom sheet title
  ///
  /// In tr, this message translates to:
  /// **'davet kodun var mı?'**
  String get redeemCodeTitle;

  /// Redeem code text field hint
  ///
  /// In tr, this message translates to:
  /// **'davet kodu'**
  String get redeemCodeHint;

  /// Redeem code confirm button
  ///
  /// In tr, this message translates to:
  /// **'kullan'**
  String get redeemCodeConfirm;

  /// Referral code load error title
  ///
  /// In tr, this message translates to:
  /// **'kod yüklenemedi'**
  String get referralCodeLoadError;

  /// Referral code load error body
  ///
  /// In tr, this message translates to:
  /// **'davet kodun şu an yüklenemiyor. bağlantını kontrol et.'**
  String get referralCodeLoadErrorBody;

  /// Referral code load error retry button
  ///
  /// In tr, this message translates to:
  /// **'tekrar dene'**
  String get referralRetry;

  /// Toast shown when the referral code is copied
  ///
  /// In tr, this message translates to:
  /// **'Kod kopyalandı!'**
  String get referralCodeCopied;

  /// Share sheet text when sharing the referral code
  ///
  /// In tr, this message translates to:
  /// **'ilnd\'e benimle katıl! davet kodum: {code}'**
  String referralShareText(String code);

  /// Share sheet subject when sharing the referral code
  ///
  /// In tr, this message translates to:
  /// **'ilnd davet kodum'**
  String get referralShareSubject;

  /// Founding member badge label
  ///
  /// In tr, this message translates to:
  /// **'KURUCU ÜYE'**
  String get referralFoundingMember;

  /// Referral code label
  ///
  /// In tr, this message translates to:
  /// **'DAVET KODUN'**
  String get referralYourCode;

  /// Copy referral code button
  ///
  /// In tr, this message translates to:
  /// **'kopyala'**
  String get referralCopy;

  /// Share referral code button
  ///
  /// In tr, this message translates to:
  /// **'paylaş'**
  String get referralShare;

  /// Splash screen tagline under the logo
  ///
  /// In tr, this message translates to:
  /// **'iyi hisset, iyi yaşa'**
  String get splashTagline;

  /// Takip (tracking) screen title
  ///
  /// In tr, this message translates to:
  /// **'takip'**
  String get takipTitle;

  /// Macros card section label
  ///
  /// In tr, this message translates to:
  /// **'MAKROLAR'**
  String get takipMacrosLabel;

  /// Macro row label: calories
  ///
  /// In tr, this message translates to:
  /// **'kalori'**
  String get takipCalories;

  /// Macro row label: protein
  ///
  /// In tr, this message translates to:
  /// **'protein'**
  String get takipProtein;

  /// Macro row label: carbs
  ///
  /// In tr, this message translates to:
  /// **'karbonhidrat'**
  String get takipCarbs;

  /// Macro row label: fat
  ///
  /// In tr, this message translates to:
  /// **'yağ'**
  String get takipFat;

  /// Meals section label
  ///
  /// In tr, this message translates to:
  /// **'ÖĞÜNLER'**
  String get takipMealsLabel;

  /// Empty meals list message
  ///
  /// In tr, this message translates to:
  /// **'henüz öğün eklenmedi'**
  String get takipNoMealsYet;

  /// Add meal row CTA
  ///
  /// In tr, this message translates to:
  /// **'öğün ekle'**
  String get takipAddMeal;

  /// Macro breakdown summary for a food entry
  ///
  /// In tr, this message translates to:
  /// **'{protein}g protein · {carbs}g karbonhidrat · {fat}g yağ'**
  String takipMacroSummary(int protein, int carbs, int fat);

  /// Calorie count for a food entry
  ///
  /// In tr, this message translates to:
  /// **'{kcal} kcal'**
  String takipKcal(int kcal);

  /// Activity section label
  ///
  /// In tr, this message translates to:
  /// **'AKTİVİTE'**
  String get takipActivityLabel;

  /// Steps stat label
  ///
  /// In tr, this message translates to:
  /// **'ADIM'**
  String get takipSteps;

  /// Water intake goal
  ///
  /// In tr, this message translates to:
  /// **'hedef: {ml}ml'**
  String takipWaterGoal(int ml);

  /// Habits section label
  ///
  /// In tr, this message translates to:
  /// **'ALIŞKANLIKLAR'**
  String get takipHabitsLabel;

  /// Empty habits list message
  ///
  /// In tr, this message translates to:
  /// **'henüz alışkanlık eklenmedi'**
  String get takipNoHabitsYet;

  /// Error when no Firebase ID token is available for the AI proxy
  ///
  /// In tr, this message translates to:
  /// **'Oturum doğrulanamadı.'**
  String get ilndServiceSessionError;

  /// Error when the AI proxy isn't configured
  ///
  /// In tr, this message translates to:
  /// **'ILND şu an yanıt veremiyor.'**
  String get ilndServiceUnavailable;

  /// Error when the daily AI usage cap is hit
  ///
  /// In tr, this message translates to:
  /// **'Bugünlük ILND ile konuşma hakkın doldu, yarın tekrar dene.'**
  String get ilndServiceDailyLimitReached;

  /// Generic AI proxy failure with HTTP status code
  ///
  /// In tr, this message translates to:
  /// **'ILND yanıt veremedi ({statusCode}).'**
  String ilndServiceResponseFailed(int statusCode);

  /// Error shown on SocketException
  ///
  /// In tr, this message translates to:
  /// **'İnternet bağlantısı yok. Bağlantını kontrol et.'**
  String get ilndServiceNoInternet;

  /// Generic fallback error message
  ///
  /// In tr, this message translates to:
  /// **'Bir şeyler ters gitti. Birazdan tekrar dener misin?'**
  String get ilndServiceGenericError;

  /// Add-sheet title
  ///
  /// In tr, this message translates to:
  /// **'ekle.'**
  String get ekleTitle;

  /// Add-sheet action: food
  ///
  /// In tr, this message translates to:
  /// **'yemek'**
  String get ekleFoodTitle;

  /// Add-sheet action subtitle: food
  ///
  /// In tr, this message translates to:
  /// **'fotoğraf çek, analiz et'**
  String get ekleFoodSubtitle;

  /// Add-sheet action: journal
  ///
  /// In tr, this message translates to:
  /// **'günlük'**
  String get ekleJournalTitle;

  /// Add-sheet action subtitle: journal
  ///
  /// In tr, this message translates to:
  /// **'bugünü yaz'**
  String get ekleJournalSubtitle;

  /// Add-sheet action: habit
  ///
  /// In tr, this message translates to:
  /// **'alışkanlık'**
  String get ekleHabitTitle;

  /// Add-sheet action subtitle: habit
  ///
  /// In tr, this message translates to:
  /// **'yeni hedef ekle'**
  String get ekleHabitSubtitle;

  /// Add-sheet action: water
  ///
  /// In tr, this message translates to:
  /// **'su'**
  String get ekleWaterTitle;

  /// Add-sheet action subtitle: water
  ///
  /// In tr, this message translates to:
  /// **'bir bardak ekle'**
  String get ekleWaterSubtitle;

  /// Error when habit name is empty
  ///
  /// In tr, this message translates to:
  /// **'Önce alışkanlığa bir ad ver.'**
  String get gorevEkleNameEmpty;

  /// Toast shown when a habit is saved
  ///
  /// In tr, this message translates to:
  /// **'Alışkanlık eklendi!'**
  String get gorevEkleSuccess;

  /// Toast shown when saving a habit fails
  ///
  /// In tr, this message translates to:
  /// **'Eklenemedi. Tekrar dene.'**
  String get gorevEkleFailed;

  /// Add-habit sheet title
  ///
  /// In tr, this message translates to:
  /// **'yeni alışkanlık'**
  String get gorevEkleTitle;

  /// Habit name field hint
  ///
  /// In tr, this message translates to:
  /// **'alışkanlığın ne?'**
  String get gorevEkleHint;

  /// Target days per week label
  ///
  /// In tr, this message translates to:
  /// **'HAFTADA KAÇ GÜN'**
  String get gorevEkleDaysPerWeek;

  /// Save habit button
  ///
  /// In tr, this message translates to:
  /// **'kaydet'**
  String get gorevEkleSave;

  /// Add-water sheet title
  ///
  /// In tr, this message translates to:
  /// **'su takibi'**
  String get suEkleTitle;

  /// Daily water goal
  ///
  /// In tr, this message translates to:
  /// **'günlük hedef: {ml}ml'**
  String suEkleDailyGoal(int ml);

  /// Water progress, current of goal
  ///
  /// In tr, this message translates to:
  /// **'{current}ml / {goal}ml'**
  String suEkleProgress(int current, int goal);

  /// Toast shown after resetting water intake
  ///
  /// In tr, this message translates to:
  /// **'Sıfırlandı.'**
  String get suEkleReset;

  /// Reset water intake button
  ///
  /// In tr, this message translates to:
  /// **'sıfırla'**
  String get suEkleResetButton;

  /// Quick-add water amount section label
  ///
  /// In tr, this message translates to:
  /// **'NE KADAR EKLEYELİM'**
  String get suEkleHowMuch;

  /// Toast shown after adding water
  ///
  /// In tr, this message translates to:
  /// **'+{ml}ml eklendi'**
  String suEkleAdded(int ml);

  /// Unit label under a quick-add water amount
  ///
  /// In tr, this message translates to:
  /// **'ML'**
  String get suEkleMl;

  /// Context shown on the paywall when the daily food-scan limit is reached
  ///
  /// In tr, this message translates to:
  /// **'bugünlük yemek analizi hakkın doldu 🌿'**
  String get yemekEklePaywallReason;

  /// Error when picking a photo fails
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafa erişilemedi. Tekrar dene.'**
  String get yemekEklePhotoAccessError;

  /// Generic food analysis failure
  ///
  /// In tr, this message translates to:
  /// **'Analiz başarısız oldu. Tekrar dener misin?'**
  String get yemekEkleAnalysisFailed;

  /// Food analysis failure with HTTP status code
  ///
  /// In tr, this message translates to:
  /// **'Analiz başarısız oldu ({statusCode}).'**
  String yemekEkleAnalysisFailedStatus(int statusCode);

  /// Error shown on SocketException during food analysis
  ///
  /// In tr, this message translates to:
  /// **'İnternet bağlantısı yok. Bağlantını kontrol et.'**
  String get yemekEkleNoInternet;

  /// Add-food screen title
  ///
  /// In tr, this message translates to:
  /// **'yemek ekle'**
  String get yemekEkleTitle;

  /// Add-food picker prompt
  ///
  /// In tr, this message translates to:
  /// **'ne yiyorsun?'**
  String get yemekEklePhotoPrompt;

  /// Add-food picker prompt body
  ///
  /// In tr, this message translates to:
  /// **'fotoğrafını çek, ILND kalorisini ve makrolarını tahmin etsin'**
  String get yemekEklePhotoPromptBody;

  /// Open camera button
  ///
  /// In tr, this message translates to:
  /// **'kamerayı aç'**
  String get yemekEkleOpenCamera;

  /// Choose from gallery button
  ///
  /// In tr, this message translates to:
  /// **'galeriden seç'**
  String get yemekEkleChooseFromGallery;

  /// Food photo analysis loading message
  ///
  /// In tr, this message translates to:
  /// **'analiz ediliyor...'**
  String get yemekEkleAnalyzing;

  /// Macro card label: calories
  ///
  /// In tr, this message translates to:
  /// **'KALORİ'**
  String get yemekEkleCalories;

  /// Macro card label: protein
  ///
  /// In tr, this message translates to:
  /// **'PROTEİN'**
  String get yemekEkleProtein;

  /// Macro card label: carbs
  ///
  /// In tr, this message translates to:
  /// **'KARBONHİDRAT'**
  String get yemekEkleCarbs;

  /// Macro card label: fat
  ///
  /// In tr, this message translates to:
  /// **'YAĞ'**
  String get yemekEkleFat;

  /// Ingredients section label
  ///
  /// In tr, this message translates to:
  /// **'MALZEMELER'**
  String get yemekEkleIngredients;

  /// Save food entry button
  ///
  /// In tr, this message translates to:
  /// **'kaydet'**
  String get yemekEkleSaveButton;

  /// Retry button
  ///
  /// In tr, this message translates to:
  /// **'tekrar dene'**
  String get yemekEkleRetryButton;

  /// Food analysis error state title
  ///
  /// In tr, this message translates to:
  /// **'bir şeyler ters gitti'**
  String get yemekEkleErrorTitle;

  /// Placeholder while ILND's comment on the food entry is loading
  ///
  /// In tr, this message translates to:
  /// **'ILND düşünüyor...'**
  String get yemekEkleIlndThinking;

  /// Back button tooltip on legal screens
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get legalBackTooltip;

  /// ILND offline chat fallback reply 1
  ///
  /// In tr, this message translates to:
  /// **'seni dinliyorum. biraz daha anlatmak ister misin?'**
  String get ilndFallbackChat1;

  /// ILND offline chat fallback reply 2
  ///
  /// In tr, this message translates to:
  /// **'bunu paylaşman güzel. şu an bedeninde bunu nerede hissediyorsun?'**
  String get ilndFallbackChat2;

  /// ILND offline chat fallback reply 3
  ///
  /// In tr, this message translates to:
  /// **'buradayım. bugün sana en çok dokunan şey neydi?'**
  String get ilndFallbackChat3;

  /// ILND offline chat fallback reply 4
  ///
  /// In tr, this message translates to:
  /// **'anlıyorum. bunu biraz daha açsak, altında ne var sence?'**
  String get ilndFallbackChat4;

  /// ILND offline journal fallback reply 1
  ///
  /// In tr, this message translates to:
  /// **'bunu yazdığın için teşekkürler. bugün sana iyi gelen tek küçük şey neydi?'**
  String get ilndFallbackJournal1;

  /// ILND offline journal fallback reply 2
  ///
  /// In tr, this message translates to:
  /// **'duygularını buraya bırakman değerli. yarın kendine ne dilemek istersin?'**
  String get ilndFallbackJournal2;

  /// ILND offline journal fallback reply 3
  ///
  /// In tr, this message translates to:
  /// **'seni duyuyorum. bu hissin sana söylemeye çalıştığı şey ne olabilir?'**
  String get ilndFallbackJournal3;

  /// ILND offline food-comment fallback 1
  ///
  /// In tr, this message translates to:
  /// **'güzel bir seçim. yanına biraz yeşillik eklersen dengesi tam olur.'**
  String get ilndFallbackFood1;

  /// ILND offline food-comment fallback 2
  ///
  /// In tr, this message translates to:
  /// **'iyi görünüyor. bol su içmeyi de unutma, sana iyi gelir.'**
  String get ilndFallbackFood2;

  /// ILND offline food-comment fallback 3
  ///
  /// In tr, this message translates to:
  /// **'dengeli bir öğün. protein iyi, sonraki öğünde lif eklemeyi deneyebilirsin.'**
  String get ilndFallbackFood3;

  /// ILND offline food-comment fallback 4
  ///
  /// In tr, this message translates to:
  /// **'keyifli görünüyor. suçluluk yok — küçük dokunuşlar yeter, baskı değil.'**
  String get ilndFallbackFood4;

  /// Streak banner text for 30+ day streaks
  ///
  /// In tr, this message translates to:
  /// **'{days} gündür kendine sadıksın. bu bir alışkanlık artık.'**
  String streakCopyLongStreak(int days);

  /// Streak banner text for 7-29 day streaks
  ///
  /// In tr, this message translates to:
  /// **'{days} gündür kendine vakit ayırıyorsun.'**
  String streakCopyWeekStreak(int days);

  /// Streak banner text for 1-6 day streaks
  ///
  /// In tr, this message translates to:
  /// **'{days}. gün — devam ediyorsun.'**
  String streakCopyDayStreak(int days);

  /// Streak banner text shown after a streak breaks but a longest streak exists
  ///
  /// In tr, this message translates to:
  /// **'yeniden başlamak da bir başlangıç. bugün küçük bir adım at.'**
  String get streakCopyRestart;

  /// Vibe card headline for 7+ day streaks
  ///
  /// In tr, this message translates to:
  /// **'Bir haftadır kendine sadıksın.'**
  String get vibeCardHeadlineWeekStreak;

  /// Vibe card headline for 3+ journal entries this week
  ///
  /// In tr, this message translates to:
  /// **'Bu hafta kendine zaman ayırdın.'**
  String get vibeCardHeadlineActiveWeek;

  /// Vibe card headline for 1-2 journal entries this week
  ///
  /// In tr, this message translates to:
  /// **'İlk adımı attın bile.'**
  String get vibeCardHeadlineFirstStep;

  /// Vibe card headline for a week with no entries
  ///
  /// In tr, this message translates to:
  /// **'Bu hafta sessizdi — yeni haftaya hazır mısın?'**
  String get vibeCardHeadlineQuietWeek;

  /// Vibe card subline when there's no journal or habit activity
  ///
  /// In tr, this message translates to:
  /// **'Her şey küçük bir başlangıçla başlar.'**
  String get vibeCardSublineEmpty;

  /// Vibe card subline fragment: journal entry count
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, =1{1 günlük yazdın} other{{count} günlük yazdın}}'**
  String vibeCardSublineJournalCount(int count);

  /// Vibe card subline fragment: completed habit count
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, =1{1 alışkanlığı tamamladın} other{{count} alışkanlığı tamamladın}}'**
  String vibeCardSublineHabitCount(int count);

  /// Screen-reader label for the theme toggle icon button
  ///
  /// In tr, this message translates to:
  /// **'Açık/koyu temayı değiştir'**
  String get a11yToggleTheme;

  /// Screen-reader label for the profile avatar icon button
  ///
  /// In tr, this message translates to:
  /// **'Profili aç'**
  String get a11yOpenProfile;

  /// Screen-reader label for a back icon button
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get a11yBack;

  /// Screen-reader label for a close icon button
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get a11yClose;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
