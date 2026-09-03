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
  String get navCommunity => 'Community';

  @override
  String get navYou => 'You';

  @override
  String get navRing => 'ilnd';

  @override
  String get topulukTitle => 'community.';

  @override
  String get topulukTagline => 'in your city, by your side';

  @override
  String get topulukComingTitle => 'the first meetup is on its way';

  @override
  String get topulukComingBody =>
      'We\'re starting with small, warm gatherings in Istanbul: morning walks, workshops, conversations. The first event announcement will land right here.';

  @override
  String get topulukInviteCta => 'invite a friend ahead of time';

  @override
  String get topulukUpcomingLabel => 'UPCOMING MEETUPS';

  @override
  String get topulukRsvpJoin => 'join';

  @override
  String get topulukRsvpGoing => 'going';

  @override
  String get topulukRsvpFull => 'event is full';

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
  String topulukGoingCountOfCapacity(int count, int capacity) {
    return '$count/$capacity going';
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
  String get authErrorUpdatePasswordFailed =>
      'Couldn\'t update the password. Try again?';

  @override
  String get newPasswordTitle => 'set your new password';

  @override
  String get newPasswordSubtitle =>
      'your reset link is verified. now pick a new password.';

  @override
  String get newPasswordHint => 'new password';

  @override
  String get newPasswordConfirmHint => 'new password (again)';

  @override
  String get newPasswordSubmit => 'update password';

  @override
  String get newPasswordSuccess => 'Your password is updated. Welcome back';

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
  String get authErrorResetLinkInvalid =>
      'This password reset link has expired or was already used. Request a new one.';

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
      'It sounds like you might be going through a hard moment, and sharing that matters. ILND is an AI. There are real people you can talk to right now:';

  @override
  String get crisisLine112 => '112 · Emergency (Türkiye)';

  @override
  String get crisisLine183 => '183 · Social Support Line (24/7, free)';

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
  String get registerSuccess => 'Your account has been created! Welcome';

  @override
  String get registerConfirmEmailSent =>
      'We sent a confirmation link to your email. Check your inbox (and spam folder), then sign in.';

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
  String get welcomeBeatMemory =>
      'ILND learns from what you write and remembers you';

  @override
  String get welcomeBeatCommunity =>
      'we meet face to face at gatherings in your city';

  @override
  String get adanLabel => 'ISLAND';

  @override
  String get adanTitle => 'island.';

  @override
  String get adanLead => 'your island grows from what you finish.';

  @override
  String get adanBody =>
      'every task earns a piece: a lantern, an oven, moonlight. pieces settle onto the island, and the island becomes a map of your memory. nothing is ever removed. quiet days only deepen the water, they do not punish.';

  @override
  String get adanItemsLabel => 'PIECES';

  @override
  String get adanStateOpen => 'OPEN';

  @override
  String get adanStateLocked => 'LOCKED';

  @override
  String get adanItemLantern => 'lantern';

  @override
  String get adanItemPine => 'pine';

  @override
  String get adanItemOven => 'oven';

  @override
  String get adanItemMoonlight => 'moonlight';

  @override
  String get adanItemWindrose => 'weather vane';

  @override
  String get adanItemMeetingStone => 'meetup stone';

  @override
  String get adanHowLantern => 'first journal';

  @override
  String get adanHowPine => '3-day streak';

  @override
  String get adanHowOven => '10 meals logged';

  @override
  String get adanHowMoonlight => 'first night ritual';

  @override
  String get adanHowWindrose => '7-day streak';

  @override
  String get adanHowMeetingStone => 'first community meetup';

  @override
  String get adanEarnedSuffix => 'earned';

  @override
  String get adanEmptyProgress => 'no pieces yet';

  @override
  String get profileStatIslandItems => 'PIECES';

  @override
  String get welcomeBeatIsland =>
      'three small things a day, finish them and your island grows';

  @override
  String adanProgress(int count, String next) {
    return '$count pieces · next: $next';
  }

  @override
  String adanCanvasSemantics(int count) {
    return 'island illustration, $count pieces settled';
  }

  @override
  String adanNextNote(String next, String how) {
    return '$next settles in once $how is done.';
  }

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
  String get homeTrackRowSubtitle => 'meals, water, habits';

  @override
  String get homeWeeklyCardRowTitle => 'your weekly card is ready';

  @override
  String get homeWeeklyCardRowSubtitle => 'share it, or keep it to yourself';

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
  String get profileWeekEmpty => 'no marks this week yet. no rush either.';

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
  String get profilePreferences => 'your details and preferences';

  @override
  String get preferencesTitle => 'preferences';

  @override
  String get preferencesNameLabel => 'NAME';

  @override
  String get preferencesGoalsLabel => 'GOALS';

  @override
  String get preferencesBodyLabel => 'BODY';

  @override
  String get preferencesActivityLabel => 'ACTIVITY';

  @override
  String get preferencesDietLabel => 'NUTRITION';

  @override
  String get preferencesAllergiesLabel => 'ALLERGIES';

  @override
  String get preferencesAllergiesHelp =>
      'ILND filters recipe suggestions by these.';

  @override
  String get preferencesGoalsHelp =>
      'Your daily read on Today is picked from these.';

  @override
  String get preferencesSave => 'save';

  @override
  String get preferencesSaved => 'Your preferences are updated.';

  @override
  String get preferencesSaveFailed => 'Couldn\'t save that. Try again?';

  @override
  String get profileSettingsLabel => 'SETTINGS';

  @override
  String get profileInviteFriend => 'invite a friend';

  @override
  String get profilePrivacyPolicy => 'privacy policy';

  @override
  String get profileTermsOfService => 'terms of service';

  @override
  String get profileSignedOut => 'Signed out. See you soon';

  @override
  String get profileSignOut => 'sign out';

  @override
  String get profileDeleteAccount => 'delete my account';

  @override
  String get journalDeleteTitle => 'Delete this entry';

  @override
  String get journalDeleteBody =>
      'This note will be gone for good. It does not change that you wrote that day, and your streak stays.';

  @override
  String get journalDeleted => 'Entry deleted.';

  @override
  String get journalDeleteFailed => 'Couldn\'t delete that. Try again?';

  @override
  String get habitDeleteTitle => 'Delete this habit';

  @override
  String get habitDeleteBody =>
      'The habit and its past check marks will leave the list.';

  @override
  String get habitDeleted => 'Habit deleted.';

  @override
  String get habitDeleteFailed => 'Couldn\'t delete that. Try again?';

  @override
  String get deleteAction => 'delete';

  @override
  String get cancelAction => 'cancel';

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
      'Your account has been deleted. Take care';

  @override
  String get exploreTitle => 'explore.';

  @override
  String get exploreSubtitle => 'small steps toward feeling good';

  @override
  String get exploreFilterMeditation => 'meditation';

  @override
  String get exploreFilterRecipes => 'recipes';

  @override
  String get exploreFilterNutrition => 'eating';

  @override
  String get exploreFilterMovement => 'movement';

  @override
  String get exploreFilterSelfCare => 'self-care';

  @override
  String get exploreFilterGrowth => 'growth';

  @override
  String get exploreFilterAll => 'all';

  @override
  String get exploreFilterEmpty => 'nothing under this tag yet';

  @override
  String get exploreMoreLabel => 'MORE';

  @override
  String get exploreRitualsLabel => 'RITUALS';

  @override
  String get exploreRitualBreathTitle => '2 min breath';

  @override
  String get exploreRitualSleepTitle => 'night ritual';

  @override
  String get exploreRitualMovementTitle => 'movement break';

  @override
  String get sleepRitualTitle => 'sleep ritual';

  @override
  String get sleepRitualPreparing => 'ilnd is shaping your night…';

  @override
  String get recipeNutritionLabel => 'PER SERVING';

  @override
  String get recipeNutritionApprox => 'approximate, varies with ingredients';

  @override
  String get recipeNutritionFiber => 'fibre';

  @override
  String get articleSourcesLabel => 'SOURCES';

  @override
  String get recipeIngredientsTitle => 'ingredients';

  @override
  String get recipeStartCooking => 'start cooking';

  @override
  String recipeStepProgress(int current, int total) {
    return 'step $current / $total';
  }

  @override
  String get recipeNextButton => 'next step';

  @override
  String get recipeFinishButton => 'enjoy';

  @override
  String get breathScreenTitle => 'breath';

  @override
  String breathMinutesChip(int minutes) {
    return '$minutes min';
  }

  @override
  String get breathPhaseInhale => 'in';

  @override
  String get breathPhaseHold => 'hold';

  @override
  String get breathPhaseExhale => 'out';

  @override
  String breathCycleProgress(int current, int total) {
    return 'breath $current / $total';
  }

  @override
  String get breathDoneTitle => 'that was a good breath.';

  @override
  String get breathAgainButton => 'one more round';

  @override
  String get breathCloseButton => 'close';

  @override
  String get sleepRitualContinueButton => 'continue';

  @override
  String get sleepRitualSkipButton => 'skip';

  @override
  String get sleepRitualFinishButton => 'goodnight';

  @override
  String sleepRitualStepProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get sleepRitualStepPrepTitle => 'getting ready';

  @override
  String get sleepRitualPrepItemLights => 'dim the lights';

  @override
  String get sleepRitualPrepItemPhone => 'silence your phone';

  @override
  String get sleepRitualPrepItemBed => 'get your bed ready';

  @override
  String get sleepRitualUnloadPrompt =>
      'leave tomorrow\'s lingering thought here';

  @override
  String get sleepRitualUnloadHint => 'one sentence is enough…';

  @override
  String get sleepRitualGratitudePrompt =>
      'a good moment that stayed with you today';

  @override
  String get sleepRitualGratitudeHint => 'something small counts…';

  @override
  String get sleepRitualClosing1 =>
      'you showed up today, and that is enough. sleep well.';

  @override
  String get sleepRitualClosing2 =>
      'the day is done, you set it down. now it is time to rest.';

  @override
  String get sleepRitualClosing3 =>
      'tomorrow is a fresh page. tonight, just sleep.';

  @override
  String get sleepRitualClosing4 =>
      'thank you for making this space for yourself. goodnight.';

  @override
  String get sleepRitualHomeCardTitle => 'ready for your night ritual?';

  @override
  String get sleepRitualHomeCardSubtitle => 'a few minutes, then sleep';

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
  String get referralTitle => 'invite a friend';

  @override
  String get referralSubtitle => 'share your code, you both get a reward';

  @override
  String get referralEnterCode => 'enter invite code';

  @override
  String get vibeCardShareText => 'sharing my mood on ilnd';

  @override
  String vibeCardShareTextWithCode(String code) {
    return 'sharing my mood on ilnd my invite code: $code';
  }

  @override
  String get streakCardHeadlineWeek =>
      'A week of showing up for yourself, every day.';

  @override
  String get streakCardHeadlineMonth =>
      'A month of being here, every day. Few people do this.';

  @override
  String get streakCardHeadlineHundred => '100 days. Quietly, steadily.';

  @override
  String get streakCardDaysLabel => 'days in a row';

  @override
  String streakCardShareText(int days) {
    return '$days days in a row on ilnd';
  }

  @override
  String streakCardShareTextWithCode(int days, String code) {
    return '$days days in a row on ilnd my invite code: $code';
  }

  @override
  String get chatQuoteCardButton => 'Make it a card';

  @override
  String get quoteCardShareText => 'ilnd told me this today';

  @override
  String quoteCardShareTextWithCode(String code) {
    return 'ilnd told me this today my invite code: $code';
  }

  @override
  String vibeCardInviteCode(String code) {
    return 'my invite code: $code';
  }

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
  String get chatPaywallReason => 'you\'ve talked to me a lot this week';

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
  String get chatSessionsTitle => 'chats';

  @override
  String get chatSessionsNew => 'new chat';

  @override
  String get chatSessionUntitled => 'untitled chat';

  @override
  String get chatSessionsEmpty => 'no saved chats yet';

  @override
  String get chatSessionToday => 'today';

  @override
  String get chatSessionYesterday => 'yesterday';

  @override
  String chatSessionDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get chatSessionDeleteTitle => 'Delete this chat';

  @override
  String get chatSessionDeleteBody =>
      'This conversation will be permanently deleted from your device. What ILND remembers about you stays.';

  @override
  String get chatSessionDeleted => 'Chat deleted.';

  @override
  String get chatSessionDeleteFailed =>
      'Couldn\'t delete it. Want to try again?';

  @override
  String get redeemCodeSuccess => 'Invite code redeemed!';

  @override
  String get redeemCodeInvalid => 'No such invite code. Double-check it.';

  @override
  String get redeemCodeSelfReferral =>
      'That\'s your own code Try a friend\'s code.';

  @override
  String get redeemCodeAlreadyUsed =>
      'You\'ve already redeemed an invite code.';

  @override
  String get redeemCodeNotReady =>
      'Your account is still getting ready. Try again in a few seconds.';

  @override
  String get redeemCodeNetworkError =>
      'Couldn\'t connect. Check your internet and try again.';

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
  String get takipHabitsDoneLabel => 'HABITS DONE';

  @override
  String takipWaterGoal(int ml) {
    return 'goal: ${ml}ml';
  }

  @override
  String get takipHabitsLabel => 'HABITS';

  @override
  String get takipNoHabitsYet => 'no habits added yet';

  @override
  String get takipRangeWeek => 'week';

  @override
  String get takipRangeMonth => 'month';

  @override
  String takipWaterAverage(String range, int ml) {
    return '$range avg. ${ml}ml';
  }

  @override
  String get takipDayToday => 'today';

  @override
  String get takipDayYesterday => 'yesterday';

  @override
  String get takipDayPrev => 'previous day';

  @override
  String get takipDayNext => 'next day';

  @override
  String get takipBackToToday => 'back to today';

  @override
  String get takipPastDayNotice =>
      'you\'re looking at a past day. checking off is closed, you can still correct a saved meal.';

  @override
  String get takipNoMealsThatDay => 'no meals logged that day';

  @override
  String get takipMealEditTitle => 'edit meal';

  @override
  String takipMealEditOpen(String name) {
    return 'edit $name';
  }

  @override
  String get takipMealEditFreeHint =>
      'correcting ingredients is free; the macros stay as they are.';

  @override
  String get takipMealEditSave => 'save changes';

  @override
  String get takipMealUpdated => 'meal updated';

  @override
  String get takipMealUpdateFailed => 'couldn\'t update the meal';

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
  String get ekleHabitSubtitle => 'add a new habit';

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
  String get yemekEklePaywallReason => 'you\'ve used today\'s food scans';

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
  String get yemekEkleProtein => 'PROTEIN';

  @override
  String get yemekEkleCarbs => 'CARBS';

  @override
  String get yemekEkleFat => 'FAT';

  @override
  String get yemekEkleIngredients => 'INGREDIENTS';

  @override
  String get yemekEklePortionQuestion => 'How much was on the plate?';

  @override
  String get yemekEklePortionHint =>
      'If the estimate is off, adjust here, the values update.';

  @override
  String get yemekEkleSaveButton => 'save';

  @override
  String get yemekEkleManualButton => 'add manually';

  @override
  String get yemekEkleManualTitle => 'what did you eat?';

  @override
  String get yemekEkleManualBody =>
      'you can add a meal without a photo. ingredients come in the next step.';

  @override
  String get yemekEkleManualNameLabel => 'food name';

  @override
  String get yemekEkleManualCalorieLabel => 'calories (kcal)';

  @override
  String get yemekEkleManualMacroHint =>
      'macros are optional, leave them blank if you don\'t know.';

  @override
  String get yemekEkleManualContinue => 'continue';

  @override
  String get yemekEkleManualNameError => 'food name is required';

  @override
  String get yemekEkleManualCalorieError => 'enter a valid calorie value';

  @override
  String get yemekEkleIngredientAdd => 'add ingredient';

  @override
  String get yemekEkleIngredientHint => 'e.g. olive oil';

  @override
  String yemekEkleIngredientRemove(String name) {
    return 'remove $name';
  }

  @override
  String get yemekEkleRecalculate => 'recalculate macros';

  @override
  String get yemekEkleRecalculateHint =>
      'you changed the ingredients. recalculating uses one of your weekly analyses.';

  @override
  String get yemekEkleRecalculating => 'recalculating';

  @override
  String get yemekEkleRecalculateFailed => 'couldn\'t recalculate the macros';

  @override
  String get yemekEkleRetryButton => 'try again';

  @override
  String get yemekEkleErrorTitle => 'something went wrong';

  @override
  String get yemekEkleIlndThinking => 'ILND is thinking...';

  @override
  String get legalBackTooltip => 'Back';

  @override
  String get ilndFallbackGreeting1 =>
      'glad you\'re here. how is your day going?';

  @override
  String get ilndFallbackGreeting2 =>
      'I\'m here. anything on your mind, or shall we just sit quietly for a bit?';

  @override
  String get ilndFallbackGreeting3 =>
      'hey. how are you treating yourself today?';

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
      'a balanced meal. protein\'s solid, try adding some fiber next meal.';

  @override
  String get ilndFallbackFood4 =>
      'looks lovely. no guilt here. small touches are enough, no pressure.';

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
    return 'day $days, you\'re keeping it up.';
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
      'This week was quiet. Ready for a new one?';

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

  @override
  String get reminderSettingLabel => 'Daily reminder';

  @override
  String get reminderSettingSubtitle =>
      'A gentle nudge before the day slips by';

  @override
  String reminderTimeLabel(String time) {
    return 'Time: $time';
  }

  @override
  String get reminderNotificationTitle => 'Make a little room for yourself';

  @override
  String get reminderNotificationBody =>
      'A small moment is enough today. One sentence, one breath. ILND is here.';

  @override
  String get reminderPermissionDenied =>
      'Notification permission was declined. Allow it in device settings and I can remind you.';

  @override
  String get planShelfLabel => 'PLANS';

  @override
  String planDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String planProgress(int done, int total) {
    return '$done/$total days';
  }

  @override
  String get planStart => 'start';

  @override
  String planContinue(int day) {
    return 'continue with day $day';
  }

  @override
  String get planAllDone => 'you finished the plan';

  @override
  String get planDayDone => 'done';

  @override
  String planDayLabel(int day) {
    return 'day $day';
  }

  @override
  String get planDayComplete => 'complete today';

  @override
  String get planDayRead => 'today\'s read';

  @override
  String get planDayAction => 'today\'s step';

  @override
  String get planActionBreath => 'take a breath';

  @override
  String get planActionMove => 'move';

  @override
  String get planActionWater => 'drink water';

  @override
  String get planActionJournal => 'write in your journal';

  @override
  String get planPaywallReason => 'this plan is for ILND+ members';

  @override
  String get planPremiumBadge => 'ILND+';

  @override
  String get planSwitchTitle => 'You have a plan in progress';

  @override
  String planSwitchBody(String title) {
    return '$title will pause, your progress stays. Switch to the new plan?';
  }

  @override
  String get planSwitchConfirm => 'switch';

  @override
  String get planSwitchCancel => 'never mind';

  @override
  String get homeActivePlanLabel => 'YOUR PLAN';

  @override
  String get movementShelfLabel => 'MOVEMENT PROGRAMS';

  @override
  String get movementLevelEasy => 'gentle';

  @override
  String get movementLevelMedium => 'medium';

  @override
  String get movementLevelStrong => 'strong';

  @override
  String movementSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String movementMinutes(int m) {
    return '$m min';
  }

  @override
  String movementProgress(int done, int total) {
    return '$done/$total sessions';
  }

  @override
  String get movementStart => 'start';

  @override
  String get movementContinue => 'continue';

  @override
  String get movementReplay => 'watch again';

  @override
  String get movementAllDone => 'you finished the program';

  @override
  String get movementSessionDone => 'done';

  @override
  String get movementPlayerError => 'couldn\'t open the video';

  @override
  String get movementPlayerRetry => 'try again';

  @override
  String get movementPaywallReason => 'this program is for ILND+ members';

  @override
  String get movementPremiumBadge => 'ILND+';

  @override
  String get a11yMovementPlay => 'Play the video';

  @override
  String get a11yMovementPause => 'Pause the video';
}
