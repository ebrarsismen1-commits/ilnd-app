import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/plans/plan_model.dart';

/// `content/plans.json` sözleşmesi. functions/scripts/checkPlans.js aynı
/// dosyayı Node tarafından denetler; bu test **uygulamanın** o dosyayı
/// gerçekten okuyabildiğini kanıtlar — iki taraf ayrı ayrı doğru olabilir ama
/// aynı şekli okumuyorlarsa içerik sessizce görünmez kalır.
void main() {
  final plansFile = File('content/plans.json');
  final articlesFile = File('content/articles.json');

  late List<Plan> plans;
  late Set<String> articleIds;

  setUpAll(() {
    final raw = jsonDecode(plansFile.readAsStringSync()) as List;
    plans = [
      for (final entry in raw)
        Plan.fromMap(
          (entry as Map)['id'] as String,
          Map<String, dynamic>.from(entry),
        ),
    ];
    articleIds = {
      for (final a in jsonDecode(articlesFile.readAsStringSync()) as List)
        (a as Map)['id'] as String,
    };
  });

  test('plans.json uygulamanın okuyabileceği şekilde', () {
    expect(plansFile.existsSync(), isTrue);
    // Boş dosya geçerlidir (içerik yokken raf çizilmez); dolu olan her plan
    // ise eksiksiz olmak zorunda.
    for (final plan in plans) {
      expect(plan.id, isNotEmpty, reason: 'plan id boş olamaz');
      expect(plan.title, isNotEmpty, reason: '${plan.id}: başlık boş');
      expect(
        plan.isPublishable,
        isTrue,
        reason:
            '${plan.id}: uzunluk 7/14/21 olmalı ve her gün içerik taşımalı — '
            'aksi hâlde plan uygulamada HİÇ görünmez',
      );
    }
  });

  test('gün kimlikleri plan içinde tekil', () {
    for (final plan in plans) {
      final ids = plan.days.map((d) => d.id).toList();
      expect(
        ids.toSet().length,
        ids.length,
        reason: '${plan.id}: gün id tekrarı ilerleme kaydını bozar',
      );
      expect(ids.every((id) => id.isNotEmpty), isTrue);
    }
  });

  test('her günün makalesi articles.json içinde var', () {
    for (final plan in plans) {
      for (final day in plan.days) {
        if (day.articleId.isEmpty) continue;
        expect(
          articleIds,
          contains(day.articleId),
          reason:
              '${plan.id}/${day.id}: "${day.articleId}" makalesi yok — gün '
              'okumasız açılır',
        );
      }
    }
  });

  test('EN çevirisi var olan günlere bağlı', () {
    for (final plan in plans) {
      final en = plan.en;
      if (en == null) continue;
      final dayIds = plan.days.map((d) => d.id).toSet();
      for (final key in {...en.dayTitles.keys, ...en.dayNotes.keys}) {
        expect(
          dayIds,
          contains(key),
          reason: '${plan.id}: "$key" için çeviri var ama öyle bir gün yok',
        );
      }
      // EN kullanıcı boş ekran görmemeli: çevirisi olan plan tüm günlerini
      // çevirmeli, yarısı Türkçe kalmamalı.
      expect(
        en.dayTitles.length,
        plan.days.length,
        reason: '${plan.id}: EN çevirisi eksik gün bırakıyor',
      );
    }
  });

  test('ücretsiz giriş basamağı korunur: 7 günlük plan kilitli değil', () {
    for (final plan in plans) {
      if (plan.lengthDays == 7) {
        expect(
          plan.premium,
          isFalse,
          reason:
              '${plan.id}: 7 günlük basamak ADR-0005 gereği ücretsiz giriş '
              'noktasıdır',
        );
      }
    }
  });
}
