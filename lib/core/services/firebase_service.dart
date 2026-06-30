import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ilnd_app/core/services/app_config.dart';

/// Firebase'i initialize eder ve Firestore istemcisini sağlar.
/// Kullanım: `await FirebaseService.initialize();`
abstract final class FirebaseService {
  static FirebaseApp? _app;

  static FirebaseOptions get _options => FirebaseOptions(
    apiKey: AppConfig.firebaseApiKey,
    authDomain: AppConfig.firebaseAuthDomain,
    projectId: AppConfig.firebaseProjectId,
    storageBucket: AppConfig.firebaseStorageBucket,
    messagingSenderId: AppConfig.firebaseMessagingSenderId,
    appId: AppConfig.firebaseAppId,
  );

  static Future<void> initialize() async {
    if (_app != null) return;
    _app = await Firebase.initializeApp(options: _options);
  }

  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Bağlantıyı test eder — sadece geliştirme sırasında kullan.
  static Future<bool> checkConnection() async {
    try {
      await firestore.collection('_health').limit(1).get();
      return true;
    } catch (_) {
      return false;
    }
  }
}
