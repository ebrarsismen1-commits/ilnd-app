/// Adan — ada öğeleri (ADR-0006).
///
/// Bu tablo **yalnız gösterim** içindir: kilitli bir öğenin "nasıl kazanılır"
/// satırını ve sıradaki öğeyi yazmak için. Kazanım kararını ASLA burası
/// vermez — onu `functions/index.js` içindeki `ISLAND_ITEMS` verir ve sonucu
/// `island/{uid}` dokümanına sunucu yazar (Sert Kural #13: kullanıcının
/// yazabildiği yerde ödül yoktur).
///
/// İki tablonun aynı kaldığı `test/features/adan/adan_items_test.dart` ile
/// kilitlenir; yeni öğe iki dosyaya birden eklenir.
library;

/// Bir öğenin hangi ölçüte bağlı olduğunu söyler — metin üretmek için.
enum IslandMetric { journalCount, streakDays, mealCount, nightRituals, meetups }

class IslandItem {
  const IslandItem({
    required this.id,
    required this.metric,
    required this.threshold,
    required this.serverVerifiable,
  });

  final String id;
  final IslandMetric metric;
  final int threshold;

  /// false ise öğe listede görünür ama şu an hiç kazanılamaz: kaynağı
  /// sunucudan okunamıyor (gece ritüeli cihaz-yerel, RSVP indeks istiyor).
  /// Tasarımın kendi sözlüğünde "KİLİTLİ" bunun karşılığı.
  final bool serverVerifiable;
}

/// Sıra tasarımdaki listeyle aynı (handoff §7).
const kIslandItems = <IslandItem>[
  IslandItem(
    id: 'lantern',
    metric: IslandMetric.journalCount,
    threshold: 1,
    serverVerifiable: true,
  ),
  IslandItem(
    id: 'pine',
    metric: IslandMetric.streakDays,
    threshold: 3,
    serverVerifiable: true,
  ),
  IslandItem(
    id: 'oven',
    metric: IslandMetric.mealCount,
    threshold: 10,
    serverVerifiable: true,
  ),
  IslandItem(
    id: 'windrose',
    metric: IslandMetric.streakDays,
    threshold: 7,
    serverVerifiable: true,
  ),
  IslandItem(
    id: 'moonlight',
    metric: IslandMetric.nightRituals,
    threshold: 1,
    serverVerifiable: true,
  ),
  IslandItem(
    id: 'meetingStone',
    metric: IslandMetric.meetups,
    threshold: 1,
    serverVerifiable: true,
  ),
];

/// Kazanılmış öğeler + türetilen "sıradaki öğe".
class IslandState {
  const IslandState({this.earned = const {}});

  final Set<String> earned;

  int get earnedCount => earned.length;

  bool has(String id) => earned.contains(id);

  /// Henüz kazanılmamış, kazanılabilir ilk öğe. Hepsi kazanıldıysa null.
  IslandItem? get nextItem {
    for (final item in kIslandItems) {
      if (!item.serverVerifiable) continue;
      if (!earned.contains(item.id)) return item;
    }
    return null;
  }
}
