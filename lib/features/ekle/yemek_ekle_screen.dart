import 'dart:convert';
// SocketException web'de hiç fırlatılmaz ama mobilde ağ hatasını yakalamak
// için gerekli. `File` bilerek import edilmiyor: dart:io File web'de çalışmaz,
// fotoğraf XFile.readAsBytes ile platformdan bağımsız okunur (bkz. avatar_edit).
import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:ilnd_app/core/billing/usage_meter.dart';
import 'package:ilnd_app/core/ilnd/ai_json.dart';
import 'package:ilnd_app/core/ilnd/ilnd_fallbacks.dart';
import 'package:ilnd_app/core/ilnd/image_media_type.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/ilnd/ilnd_service.dart';
import 'package:ilnd_app/core/services/app_check_headers.dart';
import 'package:ilnd_app/core/services/app_config.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/theme/app_theme.dart';
import 'package:ilnd_app/core/widgets/animated_background.dart';
import 'package:ilnd_app/core/widgets/pressable.dart';
import 'package:ilnd_app/core/repositories/food_repository.dart';
import 'package:ilnd_app/features/premium/paywall_screen.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class _FoodResult {
  const _FoodResult({
    required this.yemekAdi,
    required this.kalori,
    required this.protein,
    required this.karbonhidrat,
    required this.yag,
    required this.malzemeler,
  });

  final String yemekAdi;
  final int kalori;
  final double protein;
  final double karbonhidrat;
  final double yag;
  final List<String> malzemeler;

  factory _FoodResult.fromJson(Map<String, dynamic> j) => _FoodResult(
    yemekAdi: j['yemek_adi'] as String,
    kalori: (j['kalori'] as num).toInt(),
    protein: (j['protein'] as num).toDouble(),
    karbonhidrat: (j['karbonhidrat'] as num).toDouble(),
    yag: (j['yag'] as num).toDouble(),
    malzemeler: List<String>.from(j['malzemeler'] as List),
  );
}

// ─── Screen state ─────────────────────────────────────────────────────────────

enum _Phase { picker, loading, result, error }

// ─── Screen ──────────────────────────────────────────────────────────────────

class YemekEkleScreen extends ConsumerStatefulWidget {
  const YemekEkleScreen({super.key});

  @override
  ConsumerState<YemekEkleScreen> createState() => _YemekEkleScreenState();
}

class _YemekEkleScreenState extends ConsumerState<YemekEkleScreen> {
  final _picker = ImagePicker();

  _Phase _phase = _Phase.picker;
  Uint8List? _photoBytes;
  _FoodResult? _result;
  String _errorMsg = '';
  String? _comment;

  /// Kullanıcının porsiyon düzeltmesi. Görsel analiz miktarı kesin bilemez;
  /// kullanıcı ½/1/1½/2 ile AI tahminini ölçekler, kaydedilen değerler buna
  /// göre çarpılır. Her yeni analizde 1.0'a döner.
  double _portion = 1.0;

  // ── Image selection ────────────────────────────────────────────────────────

  Future<void> _pick(ImageSource source, AppLocalizations l10n) async {
    // Ücretsiz katman limiti — dolduysa paywall göster, analiz başlatma.
    if (!ref.read(usageGateProvider).isAllowed(UsageKind.food)) {
      await PaywallScreen.show(context, reason: l10n.yemekEklePaywallReason);
      return;
    }

    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1280,
      );
      if (xFile == null) return;
      // XFile.readAsBytes her platformda çalışır (web dahil); dart:io File
      // web'de UnsupportedError fırlatır.
      final bytes = await xFile.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _phase = _Phase.loading;
      });
      await _analyse(l10n);
    } catch (_) {
      _setError(l10n.yemekEklePhotoAccessError);
    }
  }

  // ── Claude API call ────────────────────────────────────────────────────────

  Future<void> _analyse(AppLocalizations l10n) async {
    // Demo güvencesi: proxy yapılandırılmamışsa (yerel/ön izleme build)
    // canlı çağrıya gitmeden inandırıcı bir sonuç göster. Demoda asla hata
    // ekranı çıkmaz.
    if (!AppConfig.isAnthropicProxyConfigured) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      final demo = _demoFoodResult();
      if (!mounted) return;
      setState(() {
        _result = demo;
        _portion = 1.0;
        _phase = _Phase.result;
      });
      ref.read(usageGateProvider).record(UsageKind.food);
      await _addIlndComment(demo, l10n);
      return;
    }

    // media_type görüntünün GERÇEK biçiminden gelmek zorunda: picker web'de
    // PNG/WebP döndürebilir ve yanlış bildirim Anthropic'ten 400 döndürür
    // ("media type mismatch" — 2026-07-08'de üretimde yaşandı).
    final mediaType = detectImageMediaType(_photoBytes!);
    if (mediaType == null) {
      _setError(l10n.yemekEkleUnsupportedImage);
      return;
    }
    // Anthropic görsel sınırı 5MB; web'de picker'ın maxWidth küçültmesi
    // garanti değil, bu yüzden istemci tarafında da koru.
    if (_photoBytes!.length > 4 * 1024 * 1024) {
      _setError(l10n.yemekEklePhotoTooLarge);
      return;
    }

    try {
      final base64Image = base64Encode(_photoBytes!);

      final idToken = await fb_auth.FirebaseAuth.instance.currentUser
          ?.getIdToken();
      if (idToken == null) {
        _setError(l10n.yemekEkleAnalysisFailed);
        return;
      }

      // Prompt structured per Anthropic's enterprise prompt-engineering guide:
      // (1) task + role in the system prompt, (2) background/image, (3) detailed
      // rules, (4) a few-shot example, (5) output format. Assistant-prefill
      // bilerek YOK: Claude 4.6+ modeller prefill'i 400 ile reddeder — JSON,
      // yanıt metninden extractJsonObject ile ayıklanır.
      // Tier 'deep' (Sonnet) balances vision quality, cost and low latency
      // for this high-throughput, user-facing scan (guide, Stage 2). The
      // request goes through functions/index.js's anthropicProxy, which
      // holds the Anthropic API key server-side and never ships it in the
      // client binary.
      final body = jsonEncode({
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
            'Yalnızca istenen JSON formatında yanıt ver.',
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
                    '${l10n.localeName.startsWith('tr') ? 'Türkçe' : 'İngilizce (English)'} '
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
                    'katma; miktarda kararsızsan düşük-orta tahmin yap.\n\n'
                    'Örnek (mercimek çorbası için):\n'
                    '{"yemek_adi": "Mercimek Çorbası", "kalori": 180, '
                    '"protein": 9.0, "karbonhidrat": 27.0, "yag": 4.5, '
                    '"malzemeler": ["kırmızı mercimek", "soğan", "havuç", '
                    '"tereyağı"]}\n\n'
                    'Şimdi fotoğraftaki yemek için yalnızca aynı yapıda bir JSON '
                    'nesnesi döndür. Başka hiçbir metin, açıklama veya markdown '
                    'ekleme.',
              },
            ],
          },
        ],
      });

      final response = await http
          .post(
            Uri.parse(AppConfig.anthropicProxyUrl),
            headers: {
              'Authorization': 'Bearer $idToken',
              'content-type': 'application/json',
              ...await appCheckHeaders(),
            },
            body: body,
          )
          // Görsel analizi yavaş olabilir ama sınırsız değil — timeout yoksa
          // ekran sonsuza dek "analiz ediliyor"da kalır.
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 429) {
        // Haftalık ücretsiz hak dolduysa bu bir hata değil, paywall anıdır —
        // hak başka bir cihazda harcanmış olabileceği için yerel sayaç bunu
        // önceden bilemez.
        if (isFreeWeeklyLimit(response)) {
          ref.read(usageGateProvider).markExhausted(UsageKind.food);
          if (!mounted) return;
          setState(() {
            _photoBytes = null;
            _phase = _Phase.picker;
          });
          await PaywallScreen.show(
            context,
            reason: l10n.yemekEklePaywallReason,
          );
          return;
        }
        _setError(l10n.yemekEkleAnalysisFailed);
        return;
      }
      if (response.statusCode != 200) {
        _setError(l10n.yemekEkleAnalysisFailedStatus(response.statusCode));
        return;
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final text = (decoded['content'] as List).first['text'] as String;

      final jsonStr = extractJsonObject(text);
      if (jsonStr == null) {
        _setError(l10n.yemekEkleAnalysisFailed);
        return;
      }

      final foodJson = jsonDecode(jsonStr) as Map<String, dynamic>;
      final result = _FoodResult.fromJson(foodJson);

      if (mounted) {
        setState(() {
          _result = result;
          _portion = 1.0;
          _phase = _Phase.result;
        });
      }

      // Başarılı analizi say (premium'da sayılmaz).
      ref.read(usageGateProvider).record(UsageKind.food);

      // ILND'nin diyetisyen-dost yorumu (sayaç değil, karşılık).
      await _addIlndComment(result, l10n);
    } on SocketException {
      _setError(l10n.yemekEkleNoInternet);
    } catch (_) {
      _setError(l10n.yemekEkleAnalysisFailed);
    }
  }

  // ── Demo sonucu ──────────────────────────────────────────────────────────────

  _FoodResult _demoFoodResult() {
    const samples = [
      _FoodResult(
        yemekAdi: 'Avokadolu Tost',
        kalori: 320,
        protein: 12,
        karbonhidrat: 30,
        yag: 18,
        malzemeler: ['tam buğday ekmek', 'avokado', 'yumurta', 'kiraz domates'],
      ),
      _FoodResult(
        yemekAdi: 'Izgara Tavuk Salata',
        kalori: 380,
        protein: 34,
        karbonhidrat: 18,
        yag: 16,
        malzemeler: ['tavuk göğsü', 'marul', 'zeytinyağı', 'roka', 'mısır'],
      ),
      _FoodResult(
        yemekAdi: 'Yoğurtlu Granola',
        kalori: 290,
        protein: 14,
        karbonhidrat: 38,
        yag: 9,
        malzemeler: ['yoğurt', 'yulaf', 'bal', 'yaban mersini'],
      ),
    ];
    return samples[DateTime.now().second % samples.length];
  }

  // ── ILND'nin yemek yorumu ────────────────────────────────────────────────────

  Future<void> _addIlndComment(_FoodResult food, AppLocalizations l10n) async {
    try {
      final memory = ref.read(ilndMemoryProvider);
      final service = ref.read(ilndServiceProvider);
      final comment = await service.respond(
        memory: memory,
        userMessage:
            'Az önce şunu yedim: ${food.yemekAdi} '
            '(${food.kalori} kcal, ${food.protein.toStringAsFixed(0)}g protein, '
            '${food.karbonhidrat.toStringAsFixed(0)}g karbonhidrat, '
            '${food.yag.toStringAsFixed(0)}g yağ).',
        task:
            'Bu öğüne kısa, sıcak ve yargısız tek bir cümlelik diyetisyen-dost '
            'yorumu yap. Gerekirse küçük bir öneri ekle. Liste yapma, samimi ol.',
        fallback: IlndFallbacks.food(l10n),
        l10n: l10n,
      );
      if (mounted) setState(() => _comment = comment);
      await ref
          .read(ilndMemoryProvider.notifier)
          .addNote('Yemek: ${food.yemekAdi} (${food.kalori} kcal)');
    } catch (_) {
      // Yorum opsiyoneldir; başarısız olursa sessizce geç.
    }
  }

  void _setError(String msg) {
    if (mounted) {
      setState(() {
        _errorMsg = msg;
        _phase = _Phase.error;
      });
    }
  }

  void _saveAndPop(BuildContext ctx) {
    final result = _result;
    if (result != null) {
      final repo = ref.read(foodRepositoryProvider);
      if (repo != null) {
        // Kaydedilen değerler kullanıcının porsiyon düzeltmesiyle ölçeklenir.
        repo.add(
          FoodEntry(
            id: '',
            yemekAdi: result.yemekAdi,
            kalori: (result.kalori * _portion).round(),
            protein: (result.protein * _portion).round(),
            karbonhidrat: (result.karbonhidrat * _portion).round(),
            yag: (result.yag * _portion).round(),
            createdAt: DateTime.now(),
          ),
        );
      }
    }
    if (ctx.mounted) Navigator.of(ctx).pop();
  }

  void _retry() {
    setState(() {
      _photoBytes = null;
      _result = null;
      _portion = 1.0;
      _comment = null;
      _errorMsg = '';
      _phase = _Phase.picker;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = ref.watch(paletteProvider);
    return Scaffold(
      backgroundColor: p.base,
      body: AnimatedBackground(
        palette: p,
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 16, 4),
                child: Row(
                  children: [
                    Pressable(
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.arrow_back_ios_rounded,
                          size: 18,
                          color: p.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.yemekEkleTitle,
                      style: AppTextStyles.display(fontSize: 19, color: p.text),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: switch (_phase) {
                  _Phase.picker => _PickerView(
                    onPick: (s) => _pick(s, l10n),
                    p: p,
                    l10n: l10n,
                  ),
                  _Phase.loading => _LoadingView(
                    photo: _photoBytes!,
                    p: p,
                    l10n: l10n,
                  ),
                  _Phase.result => _ResultView(
                    photo: _photoBytes!,
                    result: _result!,
                    comment: _comment,
                    portion: _portion,
                    onPortion: (v) => setState(() => _portion = v),
                    onRetry: _retry,
                    onSave: () => _saveAndPop(context),
                    p: p,
                    l10n: l10n,
                  ),
                  _Phase.error => _ErrorView(
                    message: _errorMsg,
                    onRetry: _retry,
                    p: p,
                    l10n: l10n,
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Phase 1: Picker ─────────────────────────────────────────────────────────

class _PickerView extends StatelessWidget {
  const _PickerView({
    required this.onPick,
    required this.p,
    required this.l10n,
  });
  final void Function(ImageSource) onPick;
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: p.amber.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.camera_alt_outlined, size: 56, color: p.amber),
          ),
          const SizedBox(height: 28),
          Text(
            l10n.yemekEklePhotoPrompt,
            style: AppTextStyles.display(fontSize: 24, color: p.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.yemekEklePhotoPromptBody,
            style: AppTextStyles.body(
              fontSize: 13,
              color: p.textMuted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 2),
          _PrimaryButton(
            icon: Icons.camera_alt_rounded,
            label: l10n.yemekEkleOpenCamera,
            onTap: () => onPick(ImageSource.camera),
            p: p,
          ),
          const SizedBox(height: 12),
          _SecondaryButton(
            icon: Icons.photo_library_outlined,
            label: l10n.yemekEkleChooseFromGallery,
            onTap: () => onPick(ImageSource.gallery),
            p: p,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Phase 2: Loading ────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({
    required this.photo,
    required this.p,
    required this.l10n,
  });
  final Uint8List photo;
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        children: [
          const Spacer(flex: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              photo,
              width: double.infinity,
              height: 280,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: p.amber),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.yemekEkleAnalyzing,
            style: AppTextStyles.body(
              fontSize: 15,
              color: p.textMuted,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

// ─── Phase 3: Result ─────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.photo,
    required this.result,
    required this.comment,
    required this.portion,
    required this.onPortion,
    required this.onRetry,
    required this.onSave,
    required this.p,
    required this.l10n,
  });

  final Uint8List photo;
  final _FoodResult result;
  final String? comment;
  final double portion;
  final ValueChanged<double> onPortion;
  final VoidCallback onRetry;
  final VoidCallback onSave;
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        8,
        AppSpacing.screenPadding,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              photo,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 20),

          // Food name
          Text(
            result.yemekAdi,
            style: AppTextStyles.display(fontSize: 24, color: p.text),
          ),

          // ILND's dietitian-friend comment
          _IlndComment(comment: comment, p: p, l10n: l10n),

          const SizedBox(height: 20),

          // Porsiyon düzeltici — AI miktarı kesin bilemez, kullanıcı ayarlar.
          _PortionSelector(
            portion: portion,
            onPortion: onPortion,
            p: p,
            l10n: l10n,
          ),
          const SizedBox(height: 16),

          // Kalori ekranin kahramani, makrolar onun altinda sessiz satirlar
          // (handoff §10). Onceki 2x2 kart izgarasi dort sayiyi esit agirlikta
          // gosteriyordu; hangisine bakacagini soylemiyordu.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${(result.kalori * portion).round()}',
                style: AppTextStyles.mono(
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'kcal',
                style: AppTextStyles.mono(fontSize: 13, color: p.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _MacroLine(
            label: l10n.yemekEkleProtein,
            value: '${(result.protein * portion).toStringAsFixed(1)}g',
            p: p,
          ),
          _MacroLine(
            label: l10n.yemekEkleCarbs,
            value: '${(result.karbonhidrat * portion).toStringAsFixed(1)}g',
            p: p,
          ),
          _MacroLine(
            label: l10n.yemekEkleFat,
            value: '${(result.yag * portion).toStringAsFixed(1)}g',
            p: p,
          ),
          const SizedBox(height: AppSpacing.sectionGap),

          // Ingredients
          Text(
            l10n.yemekEkleIngredients,
            style: AppTextStyles.sectionLabel(color: p.accent),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.malzemeler
                  .map(
                    (m) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: p.amber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        m,
                        style: AppTextStyles.label(
                          fontSize: 11.5,
                          color: p.amber,
                        ).copyWith(letterSpacing: 0),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 28),

          // Buttons
          _PrimaryButton(
            icon: Icons.check_rounded,
            label: l10n.yemekEkleSaveButton,
            onTap: onSave,
            p: p,
          ),
          const SizedBox(height: 12),
          _SecondaryButton(
            icon: Icons.refresh_rounded,
            label: l10n.yemekEkleRetryButton,
            onTap: onRetry,
            p: p,
          ),
        ],
      ),
    );
  }
}

// ─── Porsiyon düzeltici ──────────────────────────────────────────────────────

/// AI'nın miktar tahminini kullanıcının düzeltmesi için ½/1/1½/2 çarpanları.
class _PortionSelector extends StatelessWidget {
  const _PortionSelector({
    required this.portion,
    required this.onPortion,
    required this.p,
    required this.l10n,
  });

  final double portion;
  final ValueChanged<double> onPortion;
  final AppPalette p;
  final AppLocalizations l10n;

  static const _options = <(double, String)>[
    (0.5, '½×'),
    (1.0, '1×'),
    (1.5, '1½×'),
    (2.0, '2×'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.yemekEklePortionQuestion,
          style: AppTextStyles.sectionLabel(color: p.accent),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.yemekEklePortionHint,
          style: AppTextStyles.body(fontSize: 11.5, color: p.textMuted),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (value, label) in _options) ...[
              Expanded(
                child: Pressable(
                  onTap: () => onPortion(value),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: portion == value ? p.accent : p.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: portion == value ? p.accent : p.border,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      label,
                      style: AppTextStyles.body(
                        fontSize: 15,
                        color: portion == value ? p.onAccent : p.text,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              if (value != _options.last.$1) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

// ─── Phase 4: Error ──────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.p,
    required this.l10n,
  });
  final String message;
  final VoidCallback onRetry;
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFB3554A).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: Color(0xFFB3554A),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.yemekEkleErrorTitle,
            style: AppTextStyles.display(fontSize: 24, color: p.text),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.body(
              fontSize: 13,
              color: p.textMuted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 2),
          _PrimaryButton(
            icon: Icons.refresh_rounded,
            label: l10n.yemekEkleRetryButton,
            onTap: onRetry,
            p: p,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Shared button widgets ────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.p,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: p.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: p.onAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.body(
                fontSize: 15,
                color: p.onAccent,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.p,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.accent, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: p.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.body(
                fontSize: 15,
                color: p.accent,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ILND comment ─────────────────────────────────────────────────────────────

class _IlndComment extends StatelessWidget {
  const _IlndComment({
    required this.comment,
    required this.p,
    required this.l10n,
  });
  final String? comment;
  final AppPalette p;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.accentSoft.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: p.accent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                'i',
                style: AppTextStyles.display(fontSize: 15, color: p.onAccent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: comment == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        l10n.yemekEkleIlndThinking,
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: p.accent,
                        ),
                      ),
                    )
                  : Text(
                      comment!,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        height: 1.5,
                        color: p.text,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Makro satırı ─────────────────────────────────────────────────────────────

/// Etiket solda, değer sağda, altında hairline. Kart değil: kalori zaten
/// ekranın büyük anı, makrolar onun detayı.
class _MacroLine extends StatelessWidget {
  const _MacroLine({required this.label, required this.value, required this.p});
  final String label;
  final String value;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body(fontSize: 12.5, color: p.textMuted),
                ),
              ),
              Text(
                value,
                style: AppTextStyles.mono(fontSize: 12.5, color: p.text),
              ),
            ],
          ),
        ),
        Container(height: 0.5, color: p.border),
      ],
    );
  }
}
