/// Keşfet listesinin sırası.
///
/// Firestore içerikleri `order` alanına göre veriyor ve o alan EKLEME
/// sırası. İçerik kategori kategori girildiği için sonuç blok blok
/// diziliyordu: kırk altı beslenme içeriği arka arkaya, sonra yirmi beş
/// gelişim, sonra on sekiz öz bakım. Kaydıran kişi tek bir kategoride
/// sıkışıp kalıyordu.
///
/// Buradaki iki fonksiyon o sırayı düzeltiyor ve ikisi de DETERMİNİSTİK:
/// aynı gün aynı sırayı üretiyorlar. Rastgele karıştırma, her açılışta
/// listenin değişmesi demek olurdu ve kullanıcı dün gördüğü yazıyı bir
/// daha bulamazdı.
library;

import 'package:ilnd_app/features/explore/article_model.dart';

/// Kategoriler arasında dönüşümlü sıra: bir beslenme, bir meditasyon, bir
/// öz bakım, sonra başa dön.
///
/// Kategori içindeki göreli sıra korunur, yani editoryal öncelik kaybolmaz.
/// Bir kategori tükenince kalanlar aynı düzende dönmeye devam eder.
List<Article> interleaveByCategory(List<Article> articles) {
  if (articles.length < 2) return List.of(articles);

  // Kategori sırası, ilk görülme sırasına göre. Sabit bir enum sırası
  // kullanmıyoruz: listede olmayan bir kategori boş tur açardı.
  final groups = <ArticleCategory, List<Article>>{};
  for (final a in articles) {
    groups.putIfAbsent(a.category, () => <Article>[]).add(a);
  }

  final result = <Article>[];
  var added = true;
  var round = 0;
  while (added) {
    added = false;
    for (final group in groups.values) {
      if (round < group.length) {
        result.add(group[round]);
        added = true;
      }
    }
    round++;
  }
  return result;
}

/// Ekranın büyük anı için kapak seçer.
///
/// [pool] filtrelenmiş listedir: bir kategoriye dokunulduğunda kapak da o
/// kategoriden gelir. Önceden kapak filtreden bağımsızdı ve hangi etikete
/// basılırsa basılsın aynı içerik duruyordu.
///
/// Seçim güne göre döner, yani her gün başka bir kapak çıkar ama gün
/// içinde sabit kalır. Rastgele seçim, sayfayı her yenilediğinde kapağın
/// değişmesi demek olurdu.
Article? pickCover(List<Article> pool, {DateTime? now}) {
  if (pool.isEmpty) return null;
  final day = (now ?? DateTime.now()).day;
  return pool[day % pool.length];
}
