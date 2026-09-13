import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/services/crash_reporting.dart';
import 'package:ilnd_app/core/services/local_data_guard.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/core/billing/revenue_cat_service.dart';
import 'package:ilnd_app/core/services/app_config.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Yayın derlemesinde cihaz loguna hiçbir şey yazılmasın (denetim L-1).
  silenceDebugPrintInRelease(isRelease: kReleaseMode);

  // Lora OFL ile geliyor: lisans metni fontla birlikte dağıtılmak zorunda.
  // Uygulamanın lisans ekranında (showLicensePage) görünür.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Lora',
    ], await rootBundle.loadString('assets/fonts/Lora-OFL.txt'));
  });

  // Her dış servis kendi try/catch'inde başlatılır: biri başarısız olsa da
  // (ağ yok, yanlış key, ilk açılışta kota) diğerleri ve runApp() devam eder.
  // Firebase tamamen başarısız olursa auth/Firestore çalışmaz — bu durumda
  // kullanıcıya beyaz ekran/crash yerine yeniden deneme ekranı gösterilir.
  var firebaseReady = false;
  try {
    await FirebaseService.initialize();
    firebaseReady = true;
  } catch (e, st) {
    debugPrint('[main] FirebaseService.initialize failed: $e\n$st');
  }

  if (firebaseReady) {
    // App Check, Cloud Functions'a (anthropicProxy, redeemReferralCode,
    // deleteAccount) sadece bu uygulamadan gelen istekleri kabul ettirir —
    // geçerli bir Firebase ID token'a sahip olsa bile scriptlenmiş istekleri
    // engeller. Play Integrity/App Attest sağlayıcıları gerçek cihaz
    // doğrulaması yapar; debug build'lerde otomatik olarak debug provider'a
    // düşer (bkz. Firebase konsolunda debug token kaydı).
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.appAttest,
        // Web'de sağlayıcı YOKSA geçerli token üretilemez. Anahtar .env'e
        // eklenene kadar null kalır; fonksiyonlarda enforcement bu yüzden
        // hâlâ kapalı (açılırsa web kilitlenir — bkz. AppConfig).
        webProvider: AppConfig.isWebAppCheckConfigured
            ? ReCaptchaV3Provider(AppConfig.recaptchaSiteKey)
            : null,
      );
    } catch (e, st) {
      debugPrint('[main] FirebaseAppCheck.activate failed: $e\n$st');
    }

    // Crashlytics: Flutter framework hataları + yakalanmamış zone hataları.
    // Debug modda Crashlytics'e gönderim kapalı (gürültü yapmasın) — yine de
    // konsola basılır.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kDebugMode) {
        debugPrint('[FlutterError] ${details.exceptionAsString()}');
      } else {
        // Çerçeve hatası (çizim/yerleşim) ölümcül kalır, ama mesajı
        // kişisel içerikten arındırılır (denetim L-2).
        FirebaseCrashlytics.instance.recordFlutterFatalError(
          details.copyWith(exception: scrubForCrashReport(details.exception)),
        );
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        debugPrint('[PlatformDispatcher] $error\n$stack');
      } else {
        // Yakalanmayan asenkron hataların çoğu ağ kaynaklı ve uygulamayı
        // kapatmıyor: ölümcül sayılınca çökme oranı gerçeği yansıtmıyordu
        // (denetim L-2).
        FirebaseCrashlytics.instance.recordError(
          scrubForCrashReport(error),
          stack,
          fatal: false,
        );
      }
      return true;
    };
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        !kDebugMode,
      );
    } catch (e, st) {
      // Crashlytics web'de desteklenmiyor — bu satır kontrolsüz fırlarsa
      // main() burada durur ve runApp() hiç çağrılmaz (kalıcı boş ekran).
      debugPrint(
        '[main] Crashlytics.setCrashlyticsCollectionEnabled failed: $e\n$st',
      );
    }
  } else {
    // Firebase hiç başlamadıysa Crashlytics de yok — en azından konsola yaz.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('[FlutterError] ${details.exceptionAsString()}');
    };
  }

  try {
    await AnalyticsService.initialize();
    unawaited(AnalyticsService.logAppOpen());
  } catch (e, st) {
    debugPrint('[main] AnalyticsService.initialize failed: $e\n$st');
  }

  var supabaseReady = false;
  try {
    // Supabase — key'ler --dart-define-from-file=.env ile gelir
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
    supabaseReady = true;
  } catch (e, st) {
    debugPrint('[main] Supabase.initialize failed: $e\n$st');
  }

  try {
    await RevenueCatService.initialize(AppConfig.revenueCatApiKey);
  } catch (e, st) {
    debugPrint('[main] RevenueCatService.initialize failed: $e\n$st');
  }

  final prefs = await SharedPreferences.getInstance();

  // Supabase olmadan auth çalışamaz — kullanıcıya çözülebilir bir hata
  // ekranı göster (yeniden dene), uygulamayı çökertme.
  if (!supabaseReady) {
    runApp(const _StartupFailureApp());
    return;
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const IlndApp(),
    ),
  );
}

/// Supabase (auth için zorunlu) başlatılamadığında gösterilen, yeniden
/// deneme imkanı veren ekran. Beyaz ekran/crash yerine kullanıcıya ne
/// olduğunu anlatır ve `main()`'i tekrar çalıştırma şansı verir.
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _StartupFailureBody(),
    );
  }
}

class _StartupFailureBody extends StatelessWidget {
  const _StartupFailureBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 16),
              Text(
                l10n.startupFailedTitle,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.startupFailedBody, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => main(),
                child: Text(l10n.startupRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IlndApp extends ConsumerStatefulWidget {
  const IlndApp({super.key});

  @override
  ConsumerState<IlndApp> createState() => _IlndAppState();
}

class _IlndAppState extends ConsumerState<IlndApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }
    final step = ref.read(currentOnboardingStepProvider);
    if (step != null) {
      unawaited(
        AnalyticsService.logOnboardingAbandonedAtStep(step.$1, step.$2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // Çıkışta / hesap değişiminde önceki kişinin yerel verisini siler (H-2).
    ref.watch(localDataGuardProvider);
    // Tema geçişi hem özel paleti hem Material bileşenlerini (dialog,
    // bottom sheet, picker) birlikte karartsın — bkz. AppTheme.dark notu.
    final brightness = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'ilnd',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      // Debug derleme canlı veriye yazıyorsa bunu herkes görsün (denetim C-2).
      builder: (context, child) =>
          AppConfig.isDebugBuildOnProd(
            isDebug: kDebugMode,
            projectId: AppConfig.firebaseProjectId,
          )
          ? Banner(
              message: 'PROD',
              location: BannerLocation.topStart,
              child: child ?? const SizedBox.shrink(),
            )
          : child ?? const SizedBox.shrink(),
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
