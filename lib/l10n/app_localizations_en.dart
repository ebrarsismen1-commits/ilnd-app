// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loginTagline => 'welcome back.';

  @override
  String get loginEmailHint => 'email';

  @override
  String get loginPasswordHint => 'password';

  @override
  String get loginForgotPassword => 'forgot password';

  @override
  String get loginSubmit => 'sign in';

  @override
  String get loginNoAccount => 'don\'t have an account? ';

  @override
  String get loginRegisterLink => 'sign up';

  @override
  String get loginEnterValidEmailFirst => 'Enter a valid email address first.';

  @override
  String get loginResetLinkSent =>
      'A password reset link has been sent to your email.';

  @override
  String get authOrDivider => 'or';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authContinueWithApple => 'Continue with Apple';

  @override
  String get navHome => 'Today';

  @override
  String get navExplore => 'Explore';

  @override
  String get navTracking => 'Tracking';

  @override
  String get navProfile => 'Profile';

  @override
  String get navCommunity => 'Community';

  @override
  String get navYou => 'You';

  @override
  String get navRing => 'ilnd';

  @override
  String get a11yOpenChat => 'Open chat with ILND';

  @override
  String get topulukTitle => 'community.';

  @override
  String get topulukTagline => 'in your city, by your side';

  @override
  String get topulukComingTitle => 'the first meetup is on its way';

  @override
  String get topulukComingBody =>
      'We\'re starting with small, warm gatherings in Istanbul — morning walks, workshops, conversations. The first event announcement will land right here.';

  @override
  String get topulukInviteCta => 'invite a friend ahead of time';

  @override
  String get topulukUpcomingLabel => 'UPCOMING MEETUPS';

  @override
  String get topulukRsvpJoin => 'Join';

  @override
  String get topulukRsvpGoing => 'I\'m going';

  @override
  String topulukGoingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people going',
      one: '1 person going',
    );
    return '$_temp0';
  }

  @override
  String get topulukRsvpFailed => 'Couldn\'t save that. Try again?';

  @override
  String socialProofWeekly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people made time for themselves this week.',
      one: '1 person made time for themselves this week.',
    );
    return '$_temp0';
  }

  @override
  String get legalPrivacyTitle => 'Privacy Policy';

  @override
  String get legalTermsTitle => 'Terms of Service';

  @override
  String get startupFailedTitle => 'ilnd couldn\'t start';

  @override
  String get startupFailedBody =>
      'Check your internet connection and try again.';

  @override
  String get startupRetry => 'Try again';

  @override
  String get authErrorInvalidCredentials => 'Incorrect email or password.';

  @override
  String get authErrorEmailInUse => 'This email address is already in use.';

  @override
  String get authErrorWeakPassword => 'Password must be at least 6 characters.';

  @override
  String get authErrorUserNotFound => 'No account found with this email.';

  @override
  String get authErrorNetwork =>
      'Connection error. Check your internet connection.';

  @override
  String get authErrorInvalidEmail => 'Enter a valid email address.';

  @override
  String get authErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get authErrorConfirmEmail =>
      'Couldn\'t sign in. You may need to confirm your email.';

  @override
  String get authErrorSignupFailed =>
      'Couldn\'t create your account. Please try again.';

  @override
  String get authErrorSignOutFailed => 'Couldn\'t sign out. Try again?';

  @override
  String get authErrorGoogleFailed =>
      'Couldn\'t sign in with Google. Try again?';

  @override
  String get authErrorAppleFailed => 'Couldn\'t sign in with Apple. Try again?';

  @override
  String get authErrorResetFailed =>
      'Couldn\'t send the email. Check your internet connection.';

  @override
  String get authErrorDeleteUnavailable =>
      'Account deletion is unavailable right now.';

  @override
  String get authErrorDeleteFailed =>
      'Couldn\'t delete your account. Try again?';

  @override
  String get crisisTitle => 'you deserve real support';

  @override
  String get crisisBody =>
      'It sounds like you might be going through a hard moment, and sharing that matters. ILND is an AI — there are real people you can talk to right now:';

  @override
  String get crisisLine112 => '112 — Emergency (Türkiye)';

  @override
  String get crisisLine183 => '183 — Social Support Line (24/7, free)';

  @override
  String get crisisDismiss => 'got it';

  @override
  String get registerTagline => 'create an account.';

  @override
  String get registerNameHint => 'your name';

  @override
  String get registerEmailHint => 'email';

  @override
  String get registerPasswordHint => 'password';

  @override
  String get registerConfirmPasswordHint => 'confirm password';

  @override
  String get registerTermsPrefix => 'by signing up you accept the ';

  @override
  String get registerTermsOfService => 'Terms of Service';

  @override
  String get registerTermsAnd => ' and ';

  @override
  String get registerPrivacyPolicy => 'Privacy Policy';

  @override
  String get registerTermsSuffix => '.';

  @override
  String get registerSubmit => 'sign up';

  @override
  String get registerHaveAccount => 'already have an account? ';

  @override
  String get registerLoginLink => 'sign in';

  @override
  String get registerSuccess => 'Your account has been created! Welcome 🌿';

  @override
  String get validatorEmailRequired => 'Email address is required.';

  @override
  String get validatorEmailInvalid => 'Enter a valid email address.';

  @override
  String get validatorPasswordRequired => 'Password is required.';

  @override
  String get validatorPasswordTooShort =>
      'Password must be at least 6 characters.';

  @override
  String get validatorPasswordConfirmRequired => 'Re-enter your password.';

  @override
  String get validatorPasswordMismatch => 'Passwords don\'t match.';

  @override
  String get validatorNameRequired => 'Enter your name.';

  @override
  String get validatorNameTooShort => 'Name must be at least 2 characters.';

  @override
  String get welcomeTagline => 'journal, track your mood, talk to ILND.';

  @override
  String get welcomeTaglineEn => 'journal, track your mood, talk to ILND.';

  @override
  String get welcomeStart => 'start';

  @override
  String get welcomeHaveAccount => 'already have an account? ';

  @override
  String get welcomeLoginLink => 'sign in';

  @override
  String get quickSetupTitle => 'let\'s get to know you';

  @override
  String get quickSetupTitleEn => 'let\'s get to know you a little';

  @override
  String get quickSetupNameHint => 'what\'s your name?';

  @override
  String get quickSetupGoalsTitle => 'what do you want to focus on?';

  @override
  String get quickSetupGoalsSubtitle => 'pick as many as you like';

  @override
  String get quickSetupGoalCalories => 'calorie/nutrition tracking';

  @override
  String get quickSetupGoalWeight => 'lose/gain weight';

  @override
  String get quickSetupGoalMovement => 'more movement';

  @override
  String get quickSetupGoalWaterSleep => 'water/sleep tracking';

  @override
  String get quickSetupGoalHabit => 'building habits';

  @override
  String get quickSetupGoalMood => 'mood tracking';

  @override
  String get quickSetupBodyTitle => 'a few more numbers';

  @override
  String get quickSetupBodySubtitle => 'to tailor suggestions to you';

  @override
  String get quickSetupAgeHint => 'age';

  @override
  String get quickSetupHeightHint => 'height (cm)';

  @override
  String get quickSetupWeightHint => 'weight (kg)';

  @override
  String get quickSetupActivityTitle => 'how active are you?';

  @override
  String get quickSetupActivitySedentary => 'sedentary';

  @override
  String get quickSetupActivityModerate => 'moderate';

  @override
  String get quickSetupActivityActive => 'active';

  @override
  String get quickSetupDietTitle => 'any dietary preference?';

  @override
  String get quickSetupDietNone => 'none';

  @override
  String get quickSetupDietVegetarian => 'vegetarian';

  @override
  String get quickSetupDietVegan => 'vegan';

  @override
  String get quickSetupDietGlutenFree => 'gluten-free';

  @override
  String get quickSetupDietLactoseFree => 'lactose-free';

  @override
  String get quickSetupAllergiesTitle => 'any allergies?';

  @override
  String get quickSetupAllergiesSubtitle => 'pick if any, skip if not';

  @override
  String get quickSetupAllergyNuts => 'nuts';

  @override
  String get quickSetupAllergyDairy => 'dairy/lactose';

  @override
  String get quickSetupAllergyGluten => 'gluten';

  @override
  String get quickSetupAllergySeafood => 'seafood';

  @override
  String get quickSetupAllergyEgg => 'egg';

  @override
  String get quickSetupInviteCodeTitle => 'have an invite code?';

  @override
  String get quickSetupInviteCodeHint => 'invite code';

  @override
  String get quickSetupHaveInviteCode => 'I have an invite code';

  @override
  String get quickSetupContinue => 'continue';

  @override
  String get firstEntryHeader => 'LET\'S BEGIN';

  @override
  String get firstEntrySkip => 'not now';

  @override
  String get firstEntryNeedsPrompt => 'what do you need?';

  @override
  String get firstEntryNeedsLoading => 'getting a few ideas ready for you...';

  @override
  String get homeTodaysReadTitle => 'TODAY\'S READ';

  @override
  String get homeGreetingNight => 'good night';

  @override
  String get homeGreetingMorning => 'good morning';

  @override
  String get homeGreetingDay => 'good day';

  @override
  String get homeGreetingEvening => 'good evening';

  @override
  String homeGreetingWithName(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String homeProactiveGoal(String goal) {
    return 'I\'m here for your \"$goal\" goal.';
  }

  @override
  String get homeProactiveRecentNotes =>
      'I read what you wrote recently — want to talk?';

  @override
  String get homeProactiveDefault => 'how\'s today going?';

  @override
  String get homeMoodQuestion => 'how are you right now?';

  @override
  String get homeMoodCalm => 'calm';

  @override
  String get homeMoodGood => 'good';

  @override
  String get homeMoodOkay => 'okay';

  @override
  String get homeMoodTired => 'tired';

  @override
  String get homeMoodHard => 'hard';

  @override
  String homeMoodAnsweredToday(String mood) {
    return 'today: $mood';
  }

  @override
  String homeReadTimeArrow(String readTime) {
    return '$readTime read →';
  }

  @override
  String get journalTitle => 'journal';

  @override
  String get journalConnectionError => 'connection issue';

  @override
  String get journalConnectionErrorBody =>
      'can\'t reach your journal right now. check your connection.';

  @override
  String get journalRetry => 'try again';

  @override
  String get journalEmptyTitle => 'you haven\'t written anything yet';

  @override
  String get journalEmptyBody =>
      'write how you\'re feeling today, or whatever\'s on your mind. ILND will think it through with you.';

  @override
  String get journalWriteFirst => 'write your first entry';

  @override
  String get journalNewEntry => 'write a new entry';

  @override
  String get journalMonths => 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';

  @override
  String get journalWeekdaysShort => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

  @override
  String get journalWeekdaysLong =>
      'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday';

  @override
  String get journalDone => 'done';

  @override
  String get journalSave => 'save';

  @override
  String get journalWritingHint => 'what\'s on your mind?';

  @override
  String get profileShareWeeklySummary => 'share your weekly summary';

  @override
  String get profileDefaultUserName => 'User';

  @override
  String get profilePhotoFromGallery => 'choose from gallery';

  @override
  String get profilePhotoRemove => 'remove photo';

  @override
  String get profilePhotoUpdated => 'your profile photo is updated';

  @override
  String get profilePhotoTooLarge =>
      'that image is too large, pick a smaller one';

  @override
  String get profilePhotoFailed => 'couldn\'t upload the photo';

  @override
  String get a11yEditPhoto => 'Change profile photo';

  @override
  String get profileMemoryHeading => 'ILND remembers you';

  @override
  String get profileGoalsLabel => 'YOUR GOALS';

  @override
  String get profileAboutYouLabel => 'ABOUT YOU';

  @override
  String get profileStatStreak => 'streak';

  @override
  String get profileStatPoints => 'points';

  @override
  String get profileStatBadge => 'badges';

  @override
  String get profileBadgesLabel => 'BADGES';

  @override
  String get profileBadgeFirstStep => 'first step';

  @override
  String get profileBadgeSevenDays => '7-day';

  @override
  String get profileBadgeReader => 'reader';

  @override
  String get profileBadgeThirtyDays => '30-day';

  @override
  String get profileWeekdaysShort => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

  @override
  String get profileWeeklySummaryLabel => 'WEEKLY SUMMARY';

  @override
  String get profileThisWeek => 'this week';

  @override
  String get profileMealsAdded => 'meals added';

  @override
  String get profileDayStreak => 'day streak';

  @override
  String get profileJournalEntriesWritten => 'journal entries written';

  @override
  String get profileSynced => 'synced';

  @override
  String get profilePremiumMember => 'you\'re an ILND+ member';

  @override
  String get profileGoPremium => 'upgrade to ILND+';

  @override
  String get profileSettingsLabel => 'SETTINGS';

  @override
  String get profileInviteFriend => 'invite a friend';

  @override
  String get profileSettingsRow => 'settings';

  @override
  String get profilePrivacyPolicy => 'privacy policy';

  @override
  String get profileTermsOfService => 'terms of service';

  @override
  String get profileSignedOut => 'Signed out. See you soon 👋';

  @override
  String get profileSignOut => 'sign out';

  @override
  String get profileDeleteAccount => 'delete my account';

  @override
  String get profileDeleteAccountDialogTitle => 'Delete your account';

  @override
  String get profileDeleteAccountDialogBody =>
      'This can\'t be undone. Your journal entries, meal logs, streak history, and everything tied to your account will be permanently deleted.';

  @override
  String get profileDeleteAccountCancel => 'Cancel';

  @override
  String get profileDeleteAccountConfirm => 'Delete my account';

  @override
  String get profileAccountDeleted =>
      'Your account has been deleted. Take care 👋';

  @override
  String get exploreTitle => 'explore.';

  @override
  String get exploreSubtitle => 'small steps toward feeling good';

  @override
  String get exploreFilterAll => 'all';

  @override
  String get exploreFilterWellness => 'wellness';

  @override
  String get exploreFilterRecipes => 'recipes';

  @override
  String get exploreFilterArticles => 'articles';

  @override
  String get exploreFeaturedLabel => 'FEATURED';

  @override
  String get exploreSeeAllArrow => 'see all →';

  @override
  String get exploreStoryBreathing => 'breathing';

  @override
  String get exploreStorySleep => 'sleep';

  @override
  String get exploreStoryWater => 'water';

  @override
  String get exploreStoryMovement => 'movement';

  @override
  String get exploreStoryMeditation => 'meditation';

  @override
  String get exploreStorySelfCare => 'self-care';

  @override
  String get exploreRitualsLabel => 'RITUALS';

  @override
  String get exploreRitualBreathTitle => '2 min breath';

  @override
  String get exploreRitualSleepTitle => 'night ritual';

  @override
  String get exploreRitualMovementTitle => 'movement break';

  @override
  String get exploreQuote =>
      '\"A small step today, a big difference tomorrow.\"';

  @override
  String get exploreQuoteSubtitle => 'quote of the day';

  @override
  String get paywallSubtitle =>
      'unlimited chat, deeper memory, a personal plan.';

  @override
  String get paywallBenefitUnlimitedChatTitle => 'unlimited chat';

  @override
  String get paywallBenefitUnlimitedChatSubtitle =>
      'talk to ILND as much as you want';

  @override
  String get paywallBenefitLongMemoryTitle => 'deeper memory';

  @override
  String get paywallBenefitLongMemorySubtitle =>
      'ILND remembers you for longer';

  @override
  String get paywallBenefitProactiveTitle => 'proactive support';

  @override
  String get paywallBenefitProactiveSubtitle =>
      'ILND thinks of you and reaches out';

  @override
  String get paywallBenefitPersonalPlanTitle => 'personal plan';

  @override
  String get paywallBenefitPersonalPlanSubtitle =>
      'a path tailored to your goals';

  @override
  String get paywallYearly => 'yearly';

  @override
  String get paywallFreeTrial => 'try free for 7 days';

  @override
  String get paywallDiscount => '40% off';

  @override
  String get paywallStartFreeTrial => 'start free trial';

  @override
  String get paywallNotNow => 'not now';

  @override
  String get paywallRestore => 'restore purchases';

  @override
  String get paywallPurchaseCancelled => 'Purchase cancelled.';

  @override
  String get paywallPurchaseFailed => 'Purchase failed. Try again.';

  @override
  String get paywallRestoreSuccess => 'Your purchases have been restored!';

  @override
  String get paywallNoActiveSubscription => 'No active subscription found.';

  @override
  String get paywallRestoreFailed => 'Restore failed. Try again.';

  @override
  String articleDetailReadTime(String readTime) {
    return '  ·  $readTime';
  }

  @override
  String get articleDetailSignOff => '🌿';

  @override
  String get referralTitle => 'invite a friend';

  @override
  String get referralSubtitle => 'share your code, you both get a reward';

  @override
  String get referralEnterCode => 'enter invite code';

  @override
  String get vibeCardShareText => 'sharing my mood on ilnd 🌿';

  @override
  String get vibeCardError => 'couldn\'t generate the card.';

  @override
  String get vibeCardShare => 'share';

  @override
  String get vibeCardShareFailed => 'Couldn\'t share. Try again.';

  @override
  String get vibeCardStatStreak => 'streak';

  @override
  String get vibeCardStatJournal => 'journal';

  @override
  String get vibeCardStatHabit => 'habits';

  @override
  String get chatPaywallReason => 'you\'ve talked to me a lot this week 🌿';

  @override
  String get chatGreeting => 'hey.';

  @override
  String chatGreetingWithName(String name) {
    return 'hey, $name.';
  }

  @override
  String get chatEmptyPrompt => 'what\'s on your mind? I\'m here with you.';

  @override
  String get chatComposerHint => 'write something...';

  @override
  String get chatListening => 'ilnd · listening';

  @override
  String get redeemCodeSuccess => 'Invite code redeemed! 🎉';

  @override
  String get redeemCodeInvalid => 'Invalid code, or it\'s already been used.';

  @override
  String get redeemCodeTitle => 'have an invite code?';

  @override
  String get redeemCodeHint => 'invite code';

  @override
  String get redeemCodeConfirm => 'redeem';

  @override
  String get referralCodeLoadError => 'couldn\'t load your code';

  @override
  String get referralCodeLoadErrorBody =>
      'your invite code can\'t be loaded right now. check your connection.';

  @override
  String get referralRetry => 'try again';

  @override
  String get referralCodeCopied => 'Code copied!';

  @override
  String referralShareText(String code) {
    return 'join me on ilnd! my invite code: $code';
  }

  @override
  String get referralShareSubject => 'my ilnd invite code';

  @override
  String get referralFoundingMember => 'FOUNDING MEMBER';

  @override
  String get referralYourCode => 'YOUR INVITE CODE';

  @override
  String get referralCopy => 'copy';

  @override
  String get referralShare => 'share';

  @override
  String get splashTagline => 'feel good, live good';

  @override
  String get takipTitle => 'tracking';

  @override
  String get takipMacrosLabel => 'MACROS';

  @override
  String get takipCalories => 'calories';

  @override
  String get takipProtein => 'protein';

  @override
  String get takipCarbs => 'carbs';

  @override
  String get takipFat => 'fat';

  @override
  String get takipMealsLabel => 'MEALS';

  @override
  String get takipNoMealsYet => 'no meals added yet';

  @override
  String get takipAddMeal => 'add a meal';

  @override
  String takipMacroSummary(int protein, int carbs, int fat) {
    return '${protein}g protein · ${carbs}g carbs · ${fat}g fat';
  }

  @override
  String takipKcal(int kcal) {
    return '$kcal kcal';
  }

  @override
  String get takipActivityLabel => 'ACTIVITY';

  @override
  String get takipSteps => 'STEPS';

  @override
  String takipWaterGoal(int ml) {
    return 'goal: ${ml}ml';
  }

  @override
  String get takipHabitsLabel => 'HABITS';

  @override
  String get takipNoHabitsYet => 'no habits added yet';

  @override
  String get ilndServiceSessionError => 'Couldn\'t verify your session.';

  @override
  String get ilndServiceUnavailable => 'ILND can\'t respond right now.';

  @override
  String get ilndServiceDailyLimitReached =>
      'You\'ve reached today\'s chat limit with ILND, try again tomorrow.';

  @override
  String ilndServiceResponseFailed(int statusCode) {
    return 'ILND couldn\'t respond ($statusCode).';
  }

  @override
  String get ilndServiceNoInternet =>
      'No internet connection. Check your connection.';

  @override
  String get ilndServiceGenericError =>
      'Something went wrong. Want to try again in a bit?';

  @override
  String get ekleTitle => 'add.';

  @override
  String get ekleFoodTitle => 'food';

  @override
  String get ekleFoodSubtitle => 'snap a photo, analyze it';

  @override
  String get ekleJournalTitle => 'journal';

  @override
  String get ekleJournalSubtitle => 'write about today';

  @override
  String get ekleHabitTitle => 'habit';

  @override
  String get ekleHabitSubtitle => 'add a new goal';

  @override
  String get ekleWaterTitle => 'water';

  @override
  String get ekleWaterSubtitle => 'add a glass';

  @override
  String get ekleSheetSubtitle => 'what would you like to do?';

  @override
  String get ekleAskIlndTitle => 'ask ILND';

  @override
  String get ekleAskIlndSubtitle => 'talk it through';

  @override
  String get homeTrackingCardSubtitle => 'your steps, meals, habits';

  @override
  String get gorevEkleNameEmpty => 'Give the habit a name first.';

  @override
  String get gorevEkleSuccess => 'Habit added!';

  @override
  String get gorevEkleFailed => 'Couldn\'t add it. Try again.';

  @override
  String get gorevEkleTitle => 'new habit';

  @override
  String get gorevEkleHint => 'what\'s the habit?';

  @override
  String get gorevEkleDaysPerWeek => 'DAYS PER WEEK';

  @override
  String get gorevEkleSave => 'save';

  @override
  String get suEkleTitle => 'water tracking';

  @override
  String suEkleDailyGoal(int ml) {
    return 'daily goal: ${ml}ml';
  }

  @override
  String suEkleProgress(int current, int goal) {
    return '${current}ml / ${goal}ml';
  }

  @override
  String get suEkleReset => 'Reset.';

  @override
  String get suEkleResetButton => 'reset';

  @override
  String get suEkleHowMuch => 'HOW MUCH TO ADD';

  @override
  String suEkleAdded(int ml) {
    return '+${ml}ml added';
  }

  @override
  String get suEkleMl => 'ML';

  @override
  String get yemekEklePaywallReason => 'you\'ve used today\'s food scans 🌿';

  @override
  String get yemekEklePhotoAccessError =>
      'Couldn\'t access the photo. Try again.';

  @override
  String get yemekEkleAnalysisFailed => 'Analysis failed. Want to try again?';

  @override
  String get yemekEkleUnsupportedImage =>
      'This image format isn\'t supported. Try a JPEG or PNG photo?';

  @override
  String get yemekEklePhotoTooLarge =>
      'The photo is too large. Try a smaller one?';

  @override
  String yemekEkleAnalysisFailedStatus(int statusCode) {
    return 'Analysis failed ($statusCode).';
  }

  @override
  String get yemekEkleNoInternet =>
      'No internet connection. Check your connection.';

  @override
  String get yemekEkleTitle => 'add food';

  @override
  String get yemekEklePhotoPrompt => 'what are you eating?';

  @override
  String get yemekEklePhotoPromptBody =>
      'take a photo, ILND will estimate calories and macros';

  @override
  String get yemekEkleOpenCamera => 'open camera';

  @override
  String get yemekEkleChooseFromGallery => 'choose from gallery';

  @override
  String get yemekEkleAnalyzing => 'analyzing...';

  @override
  String get yemekEkleCalories => 'CALORIES';

  @override
  String get yemekEkleProtein => 'PROTEIN';

  @override
  String get yemekEkleCarbs => 'CARBS';

  @override
  String get yemekEkleFat => 'FAT';

  @override
  String get yemekEkleIngredients => 'INGREDIENTS';

  @override
  String get yemekEkleSaveButton => 'save';

  @override
  String get yemekEkleRetryButton => 'try again';

  @override
  String get yemekEkleErrorTitle => 'something went wrong';

  @override
  String get yemekEkleIlndThinking => 'ILND is thinking...';

  @override
  String get legalBackTooltip => 'Back';

  @override
  String get ilndFallbackChat1 => 'I\'m listening. want to tell me more?';

  @override
  String get ilndFallbackChat2 =>
      'thanks for sharing that. where do you feel it in your body right now?';

  @override
  String get ilndFallbackChat3 => 'I\'m here. what touched you most today?';

  @override
  String get ilndFallbackChat4 =>
      'I hear you. if we dig into that a bit more, what\'s underneath it?';

  @override
  String get ilndFallbackJournal1 =>
      'thank you for writing this. what\'s one small thing that felt good today?';

  @override
  String get ilndFallbackJournal2 =>
      'it matters that you put this down. what would you wish for yourself tomorrow?';

  @override
  String get ilndFallbackJournal3 =>
      'I hear you. what might this feeling be trying to tell you?';

  @override
  String get ilndFallbackFood1 =>
      'nice choice. add a bit of greens and it\'s perfectly balanced.';

  @override
  String get ilndFallbackFood2 =>
      'looks good. don\'t forget to drink plenty of water, it\'ll do you good.';

  @override
  String get ilndFallbackFood3 =>
      'a balanced meal. protein\'s solid — try adding some fiber next meal.';

  @override
  String get ilndFallbackFood4 =>
      'looks lovely. no guilt here — small touches are enough, no pressure.';

  @override
  String get ilndFallbackNeed1 => 'a short breathing break';

  @override
  String get ilndFallbackNeed2 => 'a recipe for today';

  @override
  String get ilndFallbackNeed3 => 'a skincare routine';

  @override
  String get ilndFallbackNeed4 => 'a small movement idea';

  @override
  String streakCopyLongStreak(int days) {
    return '$days days of showing up for yourself. that\'s a habit now.';
  }

  @override
  String streakCopyWeekStreak(int days) {
    return '$days days of making time for yourself.';
  }

  @override
  String streakCopyDayStreak(int days) {
    return 'day $days — you\'re keeping it up.';
  }

  @override
  String get streakCopyRestart =>
      'starting again is still a start. take one small step today.';

  @override
  String get vibeCardHeadlineWeekStreak =>
      'You\'ve shown up for yourself all week.';

  @override
  String get vibeCardHeadlineActiveWeek =>
      'You made time for yourself this week.';

  @override
  String get vibeCardHeadlineFirstStep =>
      'You\'ve already taken the first step.';

  @override
  String get vibeCardHeadlineQuietWeek =>
      'This week was quiet — ready for a new one?';

  @override
  String get vibeCardSublineEmpty =>
      'Everything starts with a small beginning.';

  @override
  String vibeCardSublineJournalCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'wrote $count journal entries',
      one: 'wrote 1 journal entry',
    );
    return '$_temp0';
  }

  @override
  String vibeCardSublineHabitCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'completed $count habits',
      one: 'completed 1 habit',
    );
    return '$_temp0';
  }

  @override
  String get a11yToggleTheme => 'Toggle light/dark theme';

  @override
  String get a11yOpenProfile => 'Open profile';

  @override
  String get a11yOpenIlnd => 'Open ILND';

  @override
  String get a11yBack => 'Back';

  @override
  String get a11yClose => 'Close';
}
