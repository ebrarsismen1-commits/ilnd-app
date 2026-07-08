import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ilnd_app/core/ilnd/ai_json.dart';
import 'package:ilnd_app/core/ilnd/ilnd_character.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';
import 'package:ilnd_app/core/services/app_check_headers.dart';
import 'package:ilnd_app/core/services/app_config.dart';
import 'package:ilnd_app/l10n/app_localizations.dart';

/// ILND'nin maliyet kademesi.
///
/// Freemium birim ekonomisinin kalbi: basit/sık etkileşimler ucuz modele,
/// derin koçluk güçlü modele gider.
enum IlndTier {
  /// Kısa sohbet, günlük yorumu, hızlı tepki → ucuz, düşük gecikme.
  quick,

  /// Derin koçluk, plan, çok adımlı muhakeme → güçlü model.
  deep,
}

/// Tek bir konuşma turu.
class IlndTurn {
  const IlndTurn({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}

/// ILND'nin tüm AI etkileşimlerinin tek kapısı.
///
/// Karakter + hafıza + kademeli model burada birleşir; uygulamadaki her özellik
/// (sohbet, yemek yorumu, proaktif mesaj) bunu çağırır.
class IlndService {
  const IlndService();

  /// functions/index.js'teki anthropicProxy: Anthropic API anahtarı sunucuda
  /// tutulur, çağıran Firebase ID token ile doğrulanır, günlük kademe başı
  /// kullanım sınırı sunucu tarafında uygulanır. Anahtar artık client
  /// binary'sinde hiç bulunmaz.
  Future<http.Response> _callProxy(
    Map<String, dynamic> body,
    AppLocalizations l10n,
  ) async {
    final idToken = await fb_auth.FirebaseAuth.instance.currentUser
        ?.getIdToken();
    if (idToken == null) {
      throw IlndServiceException(l10n.ilndServiceSessionError);
    }
    return http
        .post(
          Uri.parse(AppConfig.anthropicProxyUrl),
          headers: {
            'Authorization': 'Bearer $idToken',
            'content-type': 'application/json',
            ...await appCheckHeaders(),
          },
          body: jsonEncode(body),
        )
        // LLM yanıtı yavaş olabilir ama sınırsız değil — timeout olmadan
        // asılı kalan tek istek, sohbeti kalıcı 'sending' kilidinde bırakır.
        .timeout(const Duration(seconds: 60));
  }

  /// Serbest metin yanıtı üretir (sohbet, günlük yorumu, proaktif mesaj).
  ///
  /// [history] varsa çok turlu bağlam sağlar; [memory] ILND'nin kullanıcı
  /// bağlamıdır; [task] özelliğe özel kısa talimattır.
  /// [fallback] verilirse — proxy yapılandırılmamışsa, günlük limit dolduysa
  /// veya çağrı başarısız olursa — hata fırlatmak yerine bu karakter-içi
  /// cevabı döndürür. Demoyu kurşun geçirmez yapar: kullanıcı asla hata
  /// balonu görmez.
  Future<String> respond({
    required IlndMemory memory,
    required String userMessage,
    required AppLocalizations l10n,
    List<IlndTurn> history = const [],
    String? task,
    IlndTier tier = IlndTier.quick,
    String? fallback,
  }) async {
    if (!AppConfig.isAnthropicProxyConfigured) {
      if (fallback != null) return fallback;
      throw IlndServiceException(l10n.ilndServiceUnavailable);
    }

    try {
      final messages = <Map<String, dynamic>>[
        for (final t in history)
          {'role': t.fromUser ? 'user' : 'assistant', 'content': t.text},
        {'role': 'user', 'content': userMessage},
      ];

      final response = await _callProxy({
        'tier': tier.name,
        'system': IlndCharacter.systemPrompt(
          memory: memory,
          task: task,
          languageCode: l10n.localeName.split('_').first,
        ),
        'messages': messages,
      }, l10n);

      if (response.statusCode == 429) {
        throw IlndServiceException(l10n.ilndServiceDailyLimitReached);
      }
      if (response.statusCode != 200) {
        throw IlndServiceException(
          l10n.ilndServiceResponseFailed(response.statusCode),
        );
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = decoded['content'] as List;
      return (content.first['text'] as String).trim();
    } catch (e) {
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  /// Bir metinden ILND'nin kalıcı olarak hatırlaması gereken hedef ve
  /// gerçekleri çıkarır. Ucuz modelle çalışır; "beni gerçekten tanıyor"
  /// hissinin temelidir.
  ///
  /// Zaten bilinenleri [known] ile verirsen tekrarları elemeye çalışır.
  /// Çıkaracak kalıcı bir şey yoksa boş listeler döner.
  Future<({List<String> goals, List<String> facts})> extractMemory({
    required String text,
    required AppLocalizations l10n,
    IlndMemory known = const IlndMemory(),
  }) async {
    final knownCtx = [
      if (known.goals.isNotEmpty) 'Bilinen hedefler: ${known.goals.join(', ')}',
      if (known.facts.isNotEmpty)
        'Bilinen gerçekler: ${known.facts.join('; ')}',
    ].join('\n');

    if (!AppConfig.isAnthropicProxyConfigured) {
      return (goals: const <String>[], facts: const <String>[]);
    }

    http.Response response;
    try {
      response = await _callProxy({
        'tier': IlndTier.quick.name,
        'system':
            'Bir metinden, bir kullanıcı hakkında UZUN VADELİ hatırlanmaya değer '
            'kalıcı bilgileri çıkaran bir ayıklayıcısın. Sadece istikrarlı '
            'gerçekleri (ör. beslenme tercihi, alerji, yaşam düzeni) ve gerçek '
            'hedefleri al. Geçici ruh halini veya tek seferlik olayları ALMA. '
            'Zaten bilinenleri tekrar etme. Türkçe, kısa maddeler. Emin değilsen '
            'boş bırak.',
        'messages': [
          {
            'role': 'user',
            'content':
                '${knownCtx.isNotEmpty ? '$knownCtx\n\n' : ''}'
                'Metin:\n$text\n\n'
                'Yalnızca şu JSON yapısında yanıt ver, başka hiçbir şey yazma:\n'
                '{"hedefler": ["..."], "gercekler": ["..."]}',
          },
          // Not: assistant-prefill ('{' ile başlatma) Claude 4.6+ modellerde
          // 400 döndürür — JSON, yanıt metninden extractJsonObject ile ayıklanır.
        ],
      }, l10n);
    } catch (_) {
      return (goals: const <String>[], facts: const <String>[]);
    }

    if (response.statusCode != 200) {
      return (goals: const <String>[], facts: const <String>[]);
    }

    try {
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final raw = extractJsonObject(
        (decoded['content'] as List).first['text'] as String,
      );
      if (raw == null) {
        return (goals: const <String>[], facts: const <String>[]);
      }
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      return (
        goals: List<String>.from((parsed['hedefler'] as List?) ?? const []),
        facts: List<String>.from((parsed['gercekler'] as List?) ?? const []),
      );
    } catch (_) {
      return (goals: const <String>[], facts: const <String>[]);
    }
  }

  /// İlk-giriş ekranı için: kullanıcının profiline göre ŞU AN ihtiyaç
  /// duyabileceği 3-4 kısa, tıklanabilir öneri (ör. "yeni tarif",
  /// "cilt bakım rutini"). Ucuz kademe + minik çıktı (düşük token). Çağrı
  /// yapılandırılmamışsa/başarısızsa boş liste döner — UI fallback şıklara düşer.
  Future<List<String>> suggestNeeds({
    required IlndMemory memory,
    required AppLocalizations l10n,
  }) async {
    if (!AppConfig.isAnthropicProxyConfigured) return const [];

    http.Response response;
    try {
      response = await _callProxy({
        'tier': IlndTier.quick.name,
        'system':
            'Bir wellness & lifestyle uygulamasında ILND karakterisin. '
            'Kullanıcının profiline göre ŞU AN ihtiyaç duyabileceği 3 kısa, '
            'somut öneri üret — her biri 2-4 kelimelik, tıklanabilir bir şık '
            'gibi (ör. "yeni tarif", "cilt bakım rutini", "kısa nefes molası"). '
            'Genel geçer değil, profile özel ol. '
            'Kullanıcının dili: ${l10n.localeName.split('_').first} — '
            'şıkları bu dilde yaz.',
        'messages': [
          {
            'role': 'user',
            'content':
                '${memory.toPromptContext()}\n\n'
                'Yalnızca şu JSON yapısında yanıt ver, başka hiçbir şey yazma:\n'
                '{"secenekler": ["...", "...", "..."]}',
          },
          // Not: assistant-prefill ('{' ile başlatma) Claude 4.6+ modellerde
          // 400 döndürür — JSON, yanıt metninden extractJsonObject ile ayıklanır.
        ],
      }, l10n);
    } catch (_) {
      return const [];
    }

    if (response.statusCode != 200) return const [];

    try {
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final raw = extractJsonObject(
        (decoded['content'] as List).first['text'] as String,
      );
      if (raw == null) return const [];
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final list = List<String>.from(
        (parsed['secenekler'] as List?) ?? const [],
      );
      return list
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .take(4)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Hata mesajlarını kullanıcı dostu, yerelleştirilmiş bir mesaja çevirir.
  static String friendlyError(Object error, AppLocalizations l10n) {
    if (error is SocketException) {
      return l10n.ilndServiceNoInternet;
    }
    if (error is IlndServiceException) return error.message;
    return l10n.ilndServiceGenericError;
  }
}

class IlndServiceException implements Exception {
  const IlndServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

final ilndServiceProvider = Provider<IlndService>((ref) => const IlndService());
