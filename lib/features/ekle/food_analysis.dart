import 'dart:convert';
// SocketException web'de hiç fırlatılmaz ama mobilde ağ hatasını yakalamak
// için gerekli. `File` bilerek import edilmiyor: dart:io File web'de çalışmaz,
// fotoğraf çağıran tarafta XFile.readAsBytes ile okunur.
import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ilnd_app/core/ilnd/ai_json.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/core/ilnd/image_media_type.dart';
import 'package:ilnd_app/core/services/app_check_headers.dart';
import 'package:ilnd_app/core/services/app_config.dart';

/// Yemek fotoğrafı analizi — ağ çağrısı, prompt ve yanıt ayıklama.
///
/// Ekrandan ayrı durur çünkü buradaki her dal para veya sessiz veri kaybı
/// demek: 429'un iki farklı anlamı (paywall / kötüye kullanım), bozuk JSON,
/// zaman aşımı, bağlantısızlık. Widget'ın içindeyken bunların hiçbiri test
/// edilemiyordu.

// ─── Sonuç modeli ────────────────────────────────────────────────────────────

class FoodResult {
  const FoodResult({
    required this.yemekAdi,
    required this.kalori,
    required this.protein,
    required this.karbonhidrat,
    required this.yag,
    required this.malzemeler,
    this.yorum = '',
  });

  final String yemekAdi;
  final int kalori;
  final double protein;
  final double karbonhidrat;
  final double yag;
  final List<String> malzemeler;

  /// ILND'nin bu öğüne tek cümlelik yorumu.
  ///
  /// Analizle AYNI yanıtta gelir. Eskiden ayrı bir çağrıydı: her fotoğraftan
  /// sonra kişilik prompt'u baştan gönderilip karşılığında bir cümle
  /// alınıyordu, yani her öğün iki tam çağrı ediyordu. Model tabağa zaten
  /// bakıyor; yorumu da orada yazıyor (maliyet kararı, ADR-0007).
  final String yorum;

  FoodResult copyWith({
    String? yemekAdi,
    int? kalori,
    double? protein,
    double? karbonhidrat,
    double? yag,
    List<String>? malzemeler,
    String? yorum,
  }) => FoodResult(
    yemekAdi: yemekAdi ?? this.yemekAdi,
    kalori: kalori ?? this.kalori,
    protein: protein ?? this.protein,
    karbonhidrat: karbonhidrat ?? this.karbonhidrat,
    yag: yag ?? this.yag,
    malzemeler: malzemeler ?? this.malzemeler,
    yorum: yorum ?? this.yorum,
  );

  /// Güvenlik denetimi L-5 / M-6: model çıktısı yapı olarak güvenilir sayılmaz.
  /// Negatif, sonsuz ya da akıl dışı bir değer eskiden ekrana ve Firestore'a
  /// olduğu gibi gidiyordu; artık Firestore kuralları da sınır koyduğu için
  /// sınırın dışındaki bir değer kaydı sessizce reddettirirdi. Tavanlar,
  /// porsiyon çarpanı (en fazla 2) uygulandıktan sonra da kural sınırının
  /// (20000 kcal / 2000 g) altında kalacak şekilde seçildi.
  static const maxKcal = 10000;
  static const maxMacroGrams = 1000.0;
  static const maxNameLength = 150;
  static const maxIngredients = 50;
  static const maxIngredientLength = 100;

  factory FoodResult.fromJson(Map<String, dynamic> j) => FoodResult(
    yemekAdi: _bounded((j['yemek_adi'] as String).trim(), maxNameLength),
    kalori: _finiteOrZero(j['kalori'] as num).round().clamp(0, maxKcal),
    protein: _finiteOrZero(j['protein'] as num).clamp(0, maxMacroGrams),
    karbonhidrat: _finiteOrZero(
      j['karbonhidrat'] as num,
    ).clamp(0, maxMacroGrams),
    yag: _finiteOrZero(j['yag'] as num).clamp(0, maxMacroGrams),
    malzemeler: [
      for (final m in (j['malzemeler'] as List).take(maxIngredients))
        if (m is String && m.trim().isNotEmpty)
          _bounded(m.trim(), maxIngredientLength),
    ],
    // Yeniden hesaplama yanıtında yorum istenmez: alan yoksa boş kalır.
    yorum: (j['yorum'] as String?)?.trim() ?? '',
  );

  static double _finiteOrZero(num v) => v.isFinite ? v.toDouble() : 0.0;

  static String _bounded(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);
}

// ─── Sonuç türleri ───────────────────────────────────────────────────────────

/// Kullanıcıya görünen metin burada YOK (CLAUDE.md kural #1): kod döner,
/// çeviriyi UI katmanı yapar (bkz. food_analysis_l10n.dart).
enum FoodAnalysisErrorCode {
  unsupportedImage,
  photoTooLarge,
  failed,
  failedStatus,
  noInternet,
}

sealed class FoodAnalysis {
  const FoodAnalysis();
}

final class FoodAnalysisSuccess extends FoodAnalysis {
  const FoodAnalysisSuccess(this.result);
  final FoodResult result;
}

/// Haftalık ücretsiz hak sunucuda dolmuş. Bu bir hata DEĞİL, paywall anıdır —
/// hak başka bir cihazda harcanmış olabileceği için yerel sayaç önceden bilemez.
final class FoodAnalysisFreeLimit extends FoodAnalysis {
  const FoodAnalysisFreeLimit();
}

final class FoodAnalysisFailure extends FoodAnalysis {
  const FoodAnalysisFailure(this.code, {this.statusCode});
  final FoodAnalysisErrorCode code;

  /// Yalnız [FoodAnalysisErrorCode.failedStatus] için dolu.
  final int? statusCode;
}

/// Anthropic görsel sınırı 5MB; web'de picker'ın küçültmesi garanti değil,
/// bu yüzden istemci tarafında da korunuyor.
const int kMaxFoodPhotoBytes = 4 * 1024 * 1024;

/// Görsel analizi yavaş olabilir ama sınırsız değil — timeout yoksa ekran
/// sonsuza dek "analiz ediliyor"da kalır.
const Duration kFoodAnalysisTimeout = Duration(seconds: 60);

// ─── Analiz ──────────────────────────────────────────────────────────────────

class FoodAnalyzer {
  FoodAnalyzer({
    required this.proxyUrl,
    http.Client? client,
    Future<Map<String, String>> Function()? appCheck,
  }) : _client = client ?? http.Client(),
       _appCheck = appCheck ?? appCheckHeaders;

  final String proxyUrl;
  final http.Client _client;
  final Future<Map<String, String>> Function() _appCheck;

  /// [idToken] bir geri çağırım: token alma da ağ hatası üretebilir ve aynı
  /// hata dalına düşmesi gerekir.
  Future<FoodAnalysis> analyse({
    required Uint8List photoBytes,
    required Future<String?> Function() idToken,
    required bool turkish,
  }) async {
    // media_type görüntünün GERÇEK biçiminden gelmek zorunda: picker web'de
    // PNG/WebP döndürebilir ve yanlış bildirim Anthropic'ten 400 döndürür
    // ("media type mismatch" — 2026-07-08'de üretimde yaşandı).
    final mediaType = detectImageMediaType(photoBytes);
    if (mediaType == null) {
      return const FoodAnalysisFailure(FoodAnalysisErrorCode.unsupportedImage);
    }
    if (photoBytes.length > kMaxFoodPhotoBytes) {
      return const FoodAnalysisFailure(FoodAnalysisErrorCode.photoTooLarge);
    }

    try {
      final base64Image = base64Encode(photoBytes);

      final token = await idToken();
      if (token == null) {
        return const FoodAnalysisFailure(FoodAnalysisErrorCode.failed);
      }

      final response = await _client
          .post(
            Uri.parse(proxyUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'content-type': 'application/json',
              ...await _appCheck(),
            },
            body: _requestBody(
              base64Image: base64Image,
              mediaType: mediaType,
              turkish: turkish,
            ),
          )
          .timeout(kFoodAnalysisTimeout);

      if (response.statusCode == 429) {
        if (isFreeWeeklyLimit(response)) return const FoodAnalysisFreeLimit();
        return const FoodAnalysisFailure(FoodAnalysisErrorCode.failed);
      }
      if (response.statusCode != 200) {
        return FoodAnalysisFailure(
          FoodAnalysisErrorCode.failedStatus,
          statusCode: response.statusCode,
        );
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final text = (decoded['content'] as List).first['text'] as String;

      final jsonStr = extractJsonObject(text);
      if (jsonStr == null) {
        return const FoodAnalysisFailure(FoodAnalysisErrorCode.failed);
      }

      final foodJson = jsonDecode(jsonStr) as Map<String, dynamic>;
      return FoodAnalysisSuccess(FoodResult.fromJson(foodJson));
    } on SocketException {
      return const FoodAnalysisFailure(FoodAnalysisErrorCode.noInternet);
    } catch (_) {
      // Zaman aşımı, bozuk gövde, eksik alan — hepsi aynı nazik mesaja düşer.
      return const FoodAnalysisFailure(FoodAnalysisErrorCode.failed);
    }
  }

  /// Kullanıcının düzelttiği malzeme listesine göre makroları yeniden tahmin
  /// eder. Fotoğraf yok: metin tabanlı tahmin için 'quick' katmanı yeterli.
  ///
  /// Bu da bir analizdir ve owner kararıyla haftalık ücretsiz haktan düşer
  /// (gövdedeki `kind: food`, ADR-0007). Çağıran taraf yerel sayacı da
  /// ilerletir; her çip değişiminde değil, kullanıcı bilerek bastığında
  /// çalışır, yoksa tek bir düzeltme turu kotayı bitirirdi.
  ///
  /// Dönen sonuçtaki malzeme listesi kullanılmaz: liste kullanıcınındır,
  /// çağıran taraf kendi listesini korur.
  Future<FoodAnalysis> recalculate({
    required String yemekAdi,
    required List<String> malzemeler,
    required Future<String?> Function() idToken,
  }) async {
    if (malzemeler.isEmpty) {
      return const FoodAnalysisFailure(FoodAnalysisErrorCode.failed);
    }
    try {
      final token = await idToken();
      if (token == null) {
        return const FoodAnalysisFailure(FoodAnalysisErrorCode.failed);
      }

      final response = await _client
          .post(
            Uri.parse(proxyUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'content-type': 'application/json',
              ...await _appCheck(),
            },
            body: _recalculateBody(yemekAdi: yemekAdi, malzemeler: malzemeler),
          )
          .timeout(kFoodAnalysisTimeout);

      if (response.statusCode == 429) {
        if (isFreeWeeklyLimit(response)) return const FoodAnalysisFreeLimit();
        return const FoodAnalysisFailure(FoodAnalysisErrorCode.failed);
      }
      if (response.statusCode != 200) {
        return FoodAnalysisFailure(
          FoodAnalysisErrorCode.failedStatus,
          statusCode: response.statusCode,
        );
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final text = (decoded['content'] as List).first['text'] as String;
      final jsonStr = extractJsonObject(text);
      if (jsonStr == null) {
        return const FoodAnalysisFailure(FoodAnalysisErrorCode.failed);
      }
      return FoodAnalysisSuccess(
        FoodResult.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>),
      );
    } on SocketException {
      return const FoodAnalysisFailure(FoodAnalysisErrorCode.noInternet);
    } catch (_) {
      return const FoodAnalysisFailure(FoodAnalysisErrorCode.failed);
    }
  }

  String _recalculateBody({
    required String yemekAdi,
    required List<String> malzemeler,
  }) => jsonEncode({
    'tier': 'quick',
    'kind': 'food',
    'system':
        'Sen dikkatli, dürüst bir beslenme analiz uzmanısın. Verilen malzeme '
        'listesine göre tek porsiyonluk makroları tahmin eder ve yalnızca '
        'istenen JSON formatında yanıt verirsin. Listede olmayan bir '
        'malzemeyi hesaba KATMAZSIN.',
    'messages': [
      {
        'role': 'user',
        'content': [
          {
            'type': 'text',
            'text':
                'Kullanıcı kaydettiği öğünün malzeme listesini kendisi '
                'düzeltti.\n\n'
                'Yemek: $yemekAdi\n'
                'Güncel malzemeler: ${malzemeler.join(', ')}\n\n'
                'Kurallar:\n'
                '- Makroları YALNIZCA bu listeye göre, tek porsiyon için '
                'tahmin et.\n'
                '- "kalori" tam sayı (kcal); "protein", "karbonhidrat" ve '
                '"yag" gram cinsinden ondalıklı sayı olsun.\n'
                '- "yemek_adi" aynı kalsın: $yemekAdi\n'
                '- "malzemeler" kullanıcının verdiği listeyi aynen içersin.\n'
                '- Emin değilsen abartma, düşük-orta tahmin yap.\n\n'
                'Örnek:\n'
                '{"yemek_adi": "Mercimek Çorbası", "kalori": 180, '
                '"protein": 9.0, "karbonhidrat": 27.0, "yag": 4.5, '
                '"malzemeler": ["kırmızı mercimek", "soğan"]}\n\n'
                'Yalnızca aynı yapıda bir JSON nesnesi döndür. Başka hiçbir '
                'metin, açıklama veya markdown ekleme.',
          },
        ],
      },
    ],
  });

  /// Prompt, Anthropic'in kurumsal prompt-mühendisliği rehberine göre dizilir:
  /// (1) görev + rol system'de, (2) arka plan/görsel, (3) ayrıntılı kurallar,
  /// (4) few-shot örnek, (5) çıktı biçimi. Assistant-prefill bilerek YOK:
  /// Claude 4.6+ modeller prefill'i 400 ile reddeder — JSON, yanıt metninden
  /// extractJsonObject ile ayıklanır (CLAUDE.md kural #8).
  ///
  /// Tier 'deep' (Sonnet) bu yüksek hacimli, kullanıcıya dönük taramada görsel
  /// kalitesi, maliyet ve düşük gecikmeyi dengeler. İstek functions/index.js'in
  /// anthropicProxy'sinden geçer; Anthropic anahtarı sunucuda kalır, istemci
  /// ikilisine hiç girmez.
  String _requestBody({
    required String base64Image,
    required String mediaType,
    required bool turkish,
  }) => jsonEncode({
    'tier': 'deep',
    // Hesabın haftalık ücretsiz katman kotasından düşsün (sunucuda).
    'kind': 'food',
    // 1 — Task + role
    'system':
        'Sen dikkatli, dürüst bir beslenme analiz uzmanısın. Bir yemek '
        'fotoğrafına bakarak yemeği tanımlar ve makroları FOTOĞRAFTA '
        'GÖRÜNEN GERÇEK MİKTAR için tahmin edersin — standart bir porsiyon '
        'DEĞİL. Tabağın ne kadar dolu olduğuna, yarım/az kalmış olup '
        'olmadığına, çatal-kaşık-tabak gibi ölçek ipuçlarına bak. Yalnızca '
        'gözünle GÖRDÜĞÜN malzemeleri yaz; görmediğin bir eti/tavuğu/'
        'malzemeyi VARSAYMA. Emin değilsen abartma, düşük-orta tahmin yap. '
        'Aynı yanıtta kullanıcıya sıcak, yargısız, tek cümlelik bir '
        'diyetisyen-dost yorumu da yazarsın: nutuk çekmez, suçluluk '
        'yüklemez, tire kullanmazsın. Yalnızca istenen JSON formatında '
        'yanıt ver.',
    'messages': [
      {
        'role': 'user',
        'content': [
          // 2 — Background data / image
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': mediaType,
              'data': base64Image,
            },
          },
          // 3 — Detailed task description & rules
          // 4 — Few-shot example
          // 5 — Output formatting
          {
            'type': 'text',
            'text':
                'Yukarıdaki fotoğraftaki yemeği analiz et.\n\n'
                'Kurallar:\n'
                '- "yemek_adi" yemeğin yaygın '
                '${turkish ? 'Türkçe' : 'İngilizce (English)'} '
                'adı olsun.\n'
                '- "kalori" FOTOĞRAFTA GÖRÜNEN miktar için tam sayı (kcal) '
                'olsun — standart porsiyon değil. Tabak yarımsa yarım '
                'miktarı hesapla.\n'
                '- "protein", "karbonhidrat" ve "yag" gram cinsinden, '
                'ondalıklı sayı olsun ve yine GÖRÜNEN miktara göre.\n'
                '- "malzemeler" yalnızca fotoğrafta GERÇEKTEN GÖRDÜĞÜN ana '
                'malzemeleri içersin (2-6 adet). Görmediğin bir '
                'et/tavuk/malzeme EKLEME.\n'
                '- Emin olamadığın bir malzemeyi uydurmaktansa listeye '
                'katma; miktarda kararsızsan düşük-orta tahmin yap.\n'
                '- "yorum" bu öğüne sıcak, yargısız, TEK cümlelik bir '
                'diyetisyen-dost yorumu olsun. Suçluluk yükleme, liste '
                'yapma, gerekirse küçük bir öneri ekle.\n\n'
                'Örnek (mercimek çorbası için):\n'
                '{"yemek_adi": "Mercimek Çorbası", "kalori": 180, '
                '"protein": 9.0, "karbonhidrat": 27.0, "yag": 4.5, '
                '"malzemeler": ["kırmızı mercimek", "soğan", "havuç", '
                '"tereyağı"], "yorum": "sıcacık ve doyurucu bir başlangıç, '
                'yanına biraz protein eklersen akşama kadar tok tutar"}\n\n'
                'Şimdi fotoğraftaki yemek için yalnızca aynı yapıda bir JSON '
                'nesnesi döndür. Başka hiçbir metin, açıklama veya markdown '
                'ekleme.',
          },
        ],
      },
    ],
  });
}

final foodAnalyzerProvider = Provider<FoodAnalyzer>(
  (ref) => FoodAnalyzer(proxyUrl: AppConfig.anthropicProxyUrl),
);
