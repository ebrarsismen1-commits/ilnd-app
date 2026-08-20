import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/repositories/plans_repository.dart';
import 'package:ilnd_app/features/auth/auth_provider.dart';
import 'package:ilnd_app/features/plans/plan_model.dart';

/// Plan sağlayıcılarının iki sözleşmesi var ve ikisi de sessizce kırılır:
///
/// 1. **Sert Kural #2** — kullanıcıya bağlı her provider köprü oturumunu
///    (firebaseAuthUid) izlemeli. İzlemezse köprü kurulmadan açılan stream
///    permission-denied ile ölür ve Firestore stream'i kendini YENİLEMEZ:
///    kullanıcı tüm oturum boyunca boş bir raf görür.
/// 2. **Yayınlanabilirlik** — günü eksik ya da uzunluğu tanımsız plan hiçbir
///    yüzeyde görünmemeli; aktif plan bile olsa.
PlanDay _day(int i) => PlanDay(
  id: 'd$i',
  title: 'gün $i',
  articleId: 'a$i',
  action: PlanAction.breath,
);

Plan _plan(String id, {int days = 7, int order = 0}) => Plan(
  id: id,
  title: id,
  days: [for (var i = 1; i <= days; i++) _day(i)],
  order: order,
);

ProviderContainer _c(List<Override> overrides) {
  final c = ProviderContainer(overrides: overrides);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('Kural #2 — köprü oturumu izlenir', () {
    test('firebase uid yokken katalog akışı açılmaz', () async {
      final c = _c([
        firebaseAuthUidProvider.overrideWith((ref) => Stream.value(null)),
      ]);
      // Boş stream: hiç veri gelmez, ama HATA da vermez. Kritik olan
      // Firestore'a hiç bağlanmamış olması — bağlansaydı permission-denied
      // alır ve bir daha kendini toparlamazdı.
      expect(c.read(plansProvider), isA<AsyncLoading<List<Plan>>>());
      expect(c.read(publishablePlansProvider), isEmpty);
    });

    test('firebase uid yokken ilerleme deposu kurulmaz — üstelik oturuma '
        'hiç bakmadan', () {
      final c = _c([
        firebaseAuthUidProvider.overrideWith((ref) => Stream.value(null)),
      ]);

      // Bu test aynı anda kontrol SIRASINI da kilitler: provider önce köprü
      // uid'ine bakıp erken dönmeseydi, authNotifierProvider'ı okur ve gerçek
      // AuthNotifier'ı kurardı — o da Supabase.instance istediği için burada
      // assertion ile patlardı. Yani testin sessizce geçmesi, sıranın doğru
      // olduğunun kanıtı.
      expect(c.read(planProgressRepositoryProvider), isNull);
    });
  });

  group('publishablePlansProvider', () {
    test('yalnız yayınlanabilir planları geçirir', () async {
      final ok = _plan('7-gun', order: 0);
      final short = _plan('5-gun', days: 5, order: 1);
      final emptyDay = Plan(
        id: 'bos-gun',
        title: 'bos',
        order: 2,
        days: [
          for (var i = 1; i <= 7; i++)
            i == 3
                ? const PlanDay(id: 'd3', title: 'gün 3') // içeriksiz
                : _day(i),
        ],
      );

      final c = _c([
        plansProvider.overrideWith(
          (ref) => Stream.value([ok, short, emptyDay]),
        ),
      ]);
      await c.read(plansProvider.future);

      expect(c.read(publishablePlansProvider).map((p) => p.id), ['7-gun']);
    });

    test('katalog hatasında boş liste döner, patlamaz', () {
      final c = _c([
        plansProvider.overrideWith(
          (ref) => Stream<List<Plan>>.error(Exception('permission-denied')),
        ),
      ]);
      expect(c.read(publishablePlansProvider), isEmpty);
    });
  });

  group('activePlanProvider', () {
    test('aktif kimlik kataloğdaki planla eşleşir', () async {
      final c = _c([
        plansProvider.overrideWith(
          (ref) => Stream.value([_plan('a'), _plan('b', order: 1)]),
        ),
        activePlanIdProvider.overrideWith((ref) => Stream.value('b')),
      ]);
      await c.read(plansProvider.future);
      await c.read(activePlanIdProvider.future);

      expect(c.read(activePlanProvider)?.id, 'b');
    });

    test('aktif plan yayınlanabilir değilse null döner', () async {
      // İçerik geri çekilmiş olabilir (gün silindi, uzunluk bozuldu). Kullanıcı
      // yarım bir plana devam ettirilmez.
      final c = _c([
        plansProvider.overrideWith(
          (ref) => Stream.value([_plan('a', days: 5)]),
        ),
        activePlanIdProvider.overrideWith((ref) => Stream.value('a')),
      ]);
      await c.read(plansProvider.future);
      await c.read(activePlanIdProvider.future);

      expect(c.read(activePlanProvider), isNull);
    });

    test('aktif kimlik yoksa null döner', () async {
      final c = _c([
        plansProvider.overrideWith((ref) => Stream.value([_plan('a')])),
        activePlanIdProvider.overrideWith((ref) => Stream.value(null)),
      ]);
      await c.read(plansProvider.future);
      await c.read(activePlanIdProvider.future);

      expect(c.read(activePlanProvider), isNull);
    });

    test('kimlik kataloğda yoksa null döner', () async {
      // Plan silinmiş ama kullanıcının _state dokümanı hâlâ onu işaret ediyor.
      final c = _c([
        plansProvider.overrideWith((ref) => Stream.value([_plan('a')])),
        activePlanIdProvider.overrideWith((ref) => Stream.value('silinmis')),
      ]);
      await c.read(plansProvider.future);
      await c.read(activePlanIdProvider.future);

      expect(c.read(activePlanProvider), isNull);
    });
  });
}
