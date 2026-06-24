import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ilnd_app/core/ilnd/ilnd_character.dart';
import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';

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

extension on IlndTier {
  String get model => switch (this) {
        IlndTier.quick => 'claude-haiku-4-5',
        IlndTier.deep => 'claude-sonnet-4-6',
      };

  int get maxTokens => switch (this) {
        IlndTier.quick => 512,
        IlndTier.deep => 1024,
      };
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

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  // TODO: ship öncesi güvenli depolamaya / backend proxy'ye taşı.
  static const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');

  /// Serbest metin yanıtı üretir (sohbet, günlük yorumu, proaktif mesaj).
  ///
  /// [history] varsa çok turlu bağlam sağlar; [memory] ILND'nin kullanıcı
  /// bağlamıdır; [task] özelliğe özel kısa talimattır.
  /// [fallback] verilirse — API anahtarı yoksa veya çağrı başarısız olursa —
  /// hata fırlatmak yerine bu karakter-içi cevabı döndürür. Demoyu kurşun
  /// geçirmez yapar: kullanıcı asla hata balonu görmez.
  Future<String> respond({
    required IlndMemory memory,
    required String userMessage,
    List<IlndTurn> history = const [],
    String? task,
    IlndTier tier = IlndTier.quick,
    String? fallback,
  }) async {
    // Anahtar yoksa canlı çağrıya hiç gitme; yedek varsa onu ver.
    if (_apiKey.isEmpty) {
      if (fallback != null) return fallback;
      throw const IlndServiceException('ILND şu an yanıt veremiyor.');
    }

    try {
      final messages = <Map<String, dynamic>>[
        for (final t in history)
          {'role': t.fromUser ? 'user' : 'assistant', 'content': t.text},
        {'role': 'user', 'content': userMessage},
      ];

      final body = jsonEncode({
        'model': tier.model,
        'max_tokens': tier.maxTokens,
        'system': IlndCharacter.systemPrompt(memory: memory, task: task),
        'messages': messages,
      });

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: const {
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        throw IlndServiceException(
          'ILND yanıt veremedi (${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
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
    IlndMemory known = const IlndMemory(),
  }) async {
    final knownCtx = [
      if (known.goals.isNotEmpty) 'Bilinen hedefler: ${known.goals.join(', ')}',
      if (known.facts.isNotEmpty) 'Bilinen gerçekler: ${known.facts.join('; ')}',
    ].join('\n');

    final body = jsonEncode({
      'model': IlndTier.quick.model,
      'max_tokens': 300,
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
          'content': '${knownCtx.isNotEmpty ? '$knownCtx\n\n' : ''}'
              'Metin:\n$text\n\n'
              'Yalnızca şu JSON yapısında yanıt ver, başka hiçbir şey yazma:\n'
              '{"hedefler": ["..."], "gercekler": ["..."]}',
        },
        {'role': 'assistant', 'content': '{'},
      ],
    });

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: const {
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      return (goals: const <String>[], facts: const <String>[]);
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      var raw = '{${(decoded['content'] as List).first['text'] as String}'.trim();
      final lastBrace = raw.lastIndexOf('}');
      if (lastBrace != -1) raw = raw.substring(0, lastBrace + 1);
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      return (
        goals: List<String>.from((parsed['hedefler'] as List?) ?? const []),
        facts: List<String>.from((parsed['gercekler'] as List?) ?? const []),
      );
    } catch (_) {
      return (goals: const <String>[], facts: const <String>[]);
    }
  }

  /// Hata mesajlarını kullanıcı dostu Türkçeye çevirir.
  static String friendlyError(Object error) {
    if (error is SocketException) {
      return 'İnternet bağlantısı yok. Bağlantını kontrol et.';
    }
    if (error is IlndServiceException) return error.message;
    return 'Bir şeyler ters gitti. Birazdan tekrar dener misin?';
  }
}

class IlndServiceException implements Exception {
  const IlndServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

final ilndServiceProvider = Provider<IlndService>((ref) => const IlndService());
