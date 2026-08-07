import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/plans/plan_model.dart';

PlanDay _day(
  String id, {
  String articleId = 'makale',
  PlanAction action = PlanAction.none,
}) => PlanDay(
  id: id,
  title: 'gün $id',
  articleId: articleId,
  action: action,
  note: '$id notu',
);

List<PlanDay> _days(int n) => [for (var i = 1; i <= n; i++) _day('d$i')];

Plan _plan({List<PlanDay>? days, PlanTranslation? en, bool premium = false}) =>
    Plan(
      id: '7-gun-hareket',
      title: '7 gün hareket',
      description: 'Bir haftada bedeni yeniden hatırlamak.',
      days: days ?? _days(7),
      premium: premium,
      en: en,
    );

void main() {
  group('Plan yayınlanabilirliği', () {
    test('7/14/21 dışındaki uzunluk gösterilmez', () {
      expect(_plan(days: _days(7)).isPublishable, isTrue);
      expect(_plan(days: _days(14)).isPublishable, isTrue);
      expect(_plan(days: _days(21)).isPublishable, isTrue);
      // Yarım yüklenmiş içerik boş vaattir (ADR-0005).
      expect(_plan(days: _days(5)).isPublishable, isFalse);
      expect(_plan(days: const []).isPublishable, isFalse);
    });

    test('içi boş günü olan plan hiç gösterilmez', () {
      final days = _days(7);
      days[3] = _day('d4', articleId: '');
      expect(_plan(days: days).isPublishable, isFalse);
    });

    test('makalesi olmayan ama eylemi olan gün içerik sayılır', () {
      final days = _days(7);
      days[0] = _day('d1', articleId: '', action: PlanAction.breath);
      expect(_plan(days: days).isPublishable, isTrue);
    });
  });

  group('Plan çevirisi', () {
    test('forLocale alan bazında uygular, eksikleri TR bırakır', () {
      final plan = _plan(
        en: const PlanTranslation(
          title: '7 days of movement',
          // description bilerek boş: EN kullanıcı boş metin değil Türkçesini
          // görmeli (asla boş ekran).
          dayTitles: {'d1': 'the beginning'},
          dayNotes: {'d1': 'five minutes, that is all.'},
        ),
      );

      final en = plan.forLocale('en');
      expect(en.title, '7 days of movement');
      expect(en.description, 'Bir haftada bedeni yeniden hatırlamak.');
      expect(en.days[0].title, 'the beginning');
      expect(en.days[0].note, 'five minutes, that is all.');
      // Çevirisi olmayan gün Türkçesiyle kalır.
      expect(en.days[1].title, 'gün d2');
    });

    test('TR dilinde plan olduğu gibi döner', () {
      final plan = _plan(en: const PlanTranslation(title: 'ignored'));
      expect(plan.forLocale('tr').title, '7 gün hareket');
    });
  });

  group('PlanProgress', () {
    test('sıradaki gün tamamlanmamış ilk gündür', () {
      final plan = _plan();
      const progress = PlanProgress(completedDayIds: {'d1', 'd2'});
      expect(progress.nextDay(plan)?.id, 'd3');
      expect(progress.doneCountIn(plan), 2);
      expect(progress.ratioIn(plan), closeTo(2 / 7, 0.001));
      expect(progress.isComplete(plan), isFalse);
    });

    test('hepsi bitince sıradaki gün yoktur — plan baştan başlamaz', () {
      final plan = _plan();
      final progress = PlanProgress(
        completedDayIds: {for (final d in plan.days) d.id},
      );
      expect(progress.nextDay(plan), isNull);
      expect(progress.isComplete(plan), isTrue);
      expect(progress.ratioIn(plan), 1.0);
    });

    test('plan yayınlanabilir değilse tamamlanmış sayılmaz', () {
      final plan = _plan(days: _days(5));
      final progress = PlanProgress(
        completedDayIds: {for (final d in plan.days) d.id},
      );
      expect(progress.isComplete(plan), isFalse);
    });

    test('boş planda oran sıfırdır — sıfıra bölme yok', () {
      expect(const PlanProgress().ratioIn(_plan(days: const [])), 0);
    });

    test('başlangıç kaydı olmayan ilerleme başlatılmamış sayılır', () {
      expect(const PlanProgress().isStarted, isFalse);
      // Gün işaretlenmişse startedAt gelmemiş olsa bile başlamıştır.
      expect(const PlanProgress(completedDayIds: {'d1'}).isStarted, isTrue);
    });
  });

  group('PlanDay serileştirme', () {
    test('bilinmeyen eylem none\'a düşer, alanlar korunur', () {
      final day = PlanDay.fromMap(const {
        'id': 'd1',
        'title': 'başlangıç',
        'articleId': 'bacaklar-duvara',
        'action': 'teleport',
        'note': 'beş dakika.',
      });
      expect(day.action, PlanAction.none);
      expect(day.articleId, 'bacaklar-duvara');
      expect(day.hasContent, isTrue);
    });

    test('eksik alanlar varsayılana düşer, patlamaz', () {
      final day = PlanDay.fromMap(const {});
      expect(day.id, '');
      expect(day.title, '');
      expect(day.action, PlanAction.none);
      expect(day.hasContent, isFalse);
    });

    test('toMap/fromMap gidiş dönüşü alanları korur', () {
      const original = PlanDay(
        id: 'd1',
        title: 'başlangıç',
        articleId: 'a1',
        action: PlanAction.breath,
        note: 'nefes al.',
      );
      final round = PlanDay.fromMap(original.toMap());
      expect(round.id, original.id);
      expect(round.title, original.title);
      expect(round.articleId, original.articleId);
      expect(round.action, original.action);
      expect(round.note, original.note);
    });
  });
}
