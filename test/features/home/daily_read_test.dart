import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/features/explore/article_model.dart';
import 'package:ilnd_app/features/home/daily_read.dart';

/// Ana ekranın "bugünün okuması" seçimi.
///
/// Önceki hâli `kArticles[DateTime.now().day % kArticles.length]` idi ve iki
/// şeyi birden kaçırıyordu: günde bir kez dönüyordu, ve yalnız 15 maddelik
/// çevrimdışı yedeğe bakıyordu, yani Firestore'daki asıl kütüphane ana
/// ekranda hiç görünmüyordu.

Article _a(String id, ArticleCategory category) => Article(
  id: id,
  title: id,
  category: category,
  readTime: '2 dk',
  excerpt: '',
  body: const [],
);

void main() {
  final library = [
    _a('b1', ArticleCategory.beslenme),
    _a('b2', ArticleCategory.beslenme),
    _a('h1', ArticleCategory.hareket),
    _a('m1', ArticleCategory.meditasyon),
    _a('o1', ArticleCategory.ozBakim),
    _a('g1', ArticleCategory.gelisim),
  ];

  DateTime at(int hour) => DateTime.utc(2026, 9, 1, hour);

  group('saat başı değişim', () {
    test('ardışık saatler farklı yazı verir', () {
      final seen = <String>{};
      for (var h = 0; h < 6; h++) {
        final pick = pickHourlyRead(
          library: library,
          goals: const [],
          now: at(h),
        );
        seen.add(pick!.id);
      }
      expect(
        seen.length,
        library.length,
        reason: 'altı saatte altı farklı yazı gelmeli',
      );
    });

    test('aynı saat içinde seçim değişmez', () {
      final a = pickHourlyRead(
        library: library,
        goals: const [],
        now: DateTime.utc(2026, 9, 1, 10, 0),
      );
      final b = pickHourlyRead(
        library: library,
        goals: const [],
        now: DateTime.utc(2026, 9, 1, 10, 59),
      );
      expect(a!.id, b!.id);
    });

    test('liste sırası değişse de aynı saatte aynı yazı çıkar', () {
      // Firestore sıra garantisi vermiyor; seçim id'ye göre sıralanmış
      // havuzdan yapılır.
      final shuffled = library.reversed.toList();
      expect(
        pickHourlyRead(library: shuffled, goals: const [], now: at(3))!.id,
        pickHourlyRead(library: library, goals: const [], now: at(3))!.id,
      );
    });
  });

  group('ilgi alanı', () {
    test('hedeflere uyan kategoriden seçer', () {
      for (var h = 0; h < 8; h++) {
        final pick = pickHourlyRead(
          library: library,
          goals: const ['daha_fazla_hareket'],
          now: at(h),
        );
        expect(pick!.category, ArticleCategory.hareket);
      }
    });

    test('birden fazla hedef birden fazla kategori açar', () {
      final cats = <ArticleCategory>{};
      for (var h = 0; h < 12; h++) {
        cats.add(
          pickHourlyRead(
            library: library,
            goals: const ['kalori_besin_takibi', 'ruh_hali_takibi'],
            now: at(h),
          )!.category,
        );
      }
      expect(cats, {ArticleCategory.beslenme, ArticleCategory.meditasyon});
    });

    test('iki beslenme hedefi aynı kategoriye çıkar', () {
      expect(
        categoriesForGoals(const ['kalori_besin_takibi', 'kilo_vermek_almak']),
        {ArticleCategory.beslenme},
      );
    });

    test('tanınmayan hedef sessizce yok sayılır', () {
      expect(categoriesForGoals(const ['bilinmeyen_hedef']), isEmpty);
      expect(categoryForGoal('bilinmeyen_hedef'), isNull);
    });
  });

  group('boş ekran asla', () {
    test('hedefe uyan yazı yoksa tüm kütüphaneye düşer', () {
      // Kullanıcı hareket hedefi seçmiş ama kütüphanede hareket yazısı yok.
      final onlyFood = [
        _a('b1', ArticleCategory.beslenme),
        _a('b2', ArticleCategory.beslenme),
      ];
      final pick = pickHourlyRead(
        library: onlyFood,
        goals: const ['daha_fazla_hareket'],
        now: at(5),
      );
      expect(
        pick,
        isNotNull,
        reason: 'eşleşme yoksa kişiselleştirme filtreye dönüşmemeli',
      );
      expect(pick!.category, ArticleCategory.beslenme);
    });

    test('kütüphane boşsa null döner, çağıran yedeğine düşer', () {
      expect(
        pickHourlyRead(library: const [], goals: const [], now: at(1)),
        isNull,
      );
    });

    test('hedef yoksa tüm kütüphane kullanılır', () {
      final cats = <ArticleCategory>{};
      for (var h = 0; h < 24; h++) {
        cats.add(
          pickHourlyRead(
            library: library,
            goals: const [],
            now: at(h),
          )!.category,
        );
      }
      expect(cats.length, greaterThan(1));
    });
  });

  test('hedef anahtarları onboarding ekranındakilerle aynı', () {
    // quick_setup_screen.dart'taki _goals listesi. Biri değişip burası
    // güncellenmezse hedef sessizce "ilgi alanı yok" sayılır ve
    // kişiselleştirme fark edilmeden ölür.
    const onboardingGoals = [
      'kalori_besin_takibi',
      'kilo_vermek_almak',
      'daha_fazla_hareket',
      'su_uyku_takibi',
      'aliskanlik_olusturma',
      'ruh_hali_takibi',
    ];
    for (final goal in onboardingGoals) {
      expect(
        categoryForGoal(goal),
        isNotNull,
        reason: '$goal hiçbir kategoriye eşlenmiyor',
      );
    }
  });
}
