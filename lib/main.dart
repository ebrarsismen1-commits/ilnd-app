import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ilnd_app/core/router/app_router.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/features/onboarding/onboarding_provider.dart';
import 'package:ilnd_app/core/billing/revenue_cat_service.dart';
import 'package:ilnd_app/core/services/app_config.dart';
import 'package:ilnd_app/core/repositories/explore_repository.dart';
import 'package:ilnd_app/core/services/firebase_service.dart';
import 'package:ilnd_app/core/services/analytics_service.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        debugPrint('[PlatformDispatcher] $error\n$stack');
      } else {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
      return true;
    };
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );

    unawaited(
      ExploreRepository.seedIfEmpty().catchError(
        (e) => debugPrint('[main] seedIfEmpty failed: $e'),
      ),
    );
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'ilnd başlatılamadı',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'İnternet bağlantını kontrol edip tekrar dene.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => main(),
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
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

    return MaterialApp.router(
      title: 'ilnd',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
