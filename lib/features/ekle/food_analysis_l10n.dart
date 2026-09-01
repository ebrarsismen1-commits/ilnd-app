import 'package:ilnd_app/features/ekle/food_analysis.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// Dil-bağımsız [FoodAnalysisErrorCode]'ları kullanıcının diline çevirir.
/// Bilerek UI katmanında: analiz servisi metin taşımaz (CLAUDE.md kural #1,
/// auth_error_l10n.dart deseni).
extension FoodAnalysisFailureL10n on FoodAnalysisFailure {
  String localized(AppLocalizations l10n) => switch (code) {
    FoodAnalysisErrorCode.unsupportedImage => l10n.yemekEkleUnsupportedImage,
    FoodAnalysisErrorCode.photoTooLarge => l10n.yemekEklePhotoTooLarge,
    FoodAnalysisErrorCode.failed => l10n.yemekEkleAnalysisFailed,
    FoodAnalysisErrorCode.failedStatus => l10n.yemekEkleAnalysisFailedStatus(
      statusCode ?? 0,
    ),
    FoodAnalysisErrorCode.noInternet => l10n.yemekEkleNoInternet,
  };
}
