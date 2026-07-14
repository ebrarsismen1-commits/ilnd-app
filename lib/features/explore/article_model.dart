import 'package:cloud_firestore/cloud_firestore.dart';

enum ArticleCategory { wellness, tarif, yazi }

extension ArticleCategoryX on ArticleCategory {
  String get tag => switch (this) {
    ArticleCategory.wellness => 'wellness',
    ArticleCategory.tarif => 'tarif',
    ArticleCategory.yazi => 'yazı',
  };

  int get palette => switch (this) {
    ArticleCategory.wellness => 0,
    ArticleCategory.tarif => 1,
    ArticleCategory.yazi => 3,
  };

  String get firestoreValue => name;

  static ArticleCategory fromString(String s) => ArticleCategory.values
      .firstWhere((e) => e.name == s, orElse: () => ArticleCategory.wellness);
}

class Article {
  const Article({
    required this.id,
    required this.title,
    required this.category,
    required this.readTime,
    required this.excerpt,
    required this.body,
    this.imageUrl,
    this.order = 0,
  });

  final String id;
  final String title;
  final ArticleCategory category;
  final String readTime;
  final String excerpt;
  final List<String> body;
  final String? imageUrl;
  final int order;

  factory Article.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    return Article(
      id: doc.id,
      title: d['title'] as String? ?? '',
      category: ArticleCategoryX.fromString(d['category'] as String? ?? ''),
      readTime: d['readTime'] as String? ?? '',
      excerpt: d['excerpt'] as String? ?? '',
      body: List<String>.from(d['body'] as List? ?? []),
      imageUrl: d['imageUrl'] as String?,
      order: (d['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'category': category.firestoreValue,
    'readTime': readTime,
    'excerpt': excerpt,
    'body': body,
    'imageUrl': imageUrl,
    'order': order,
  };
}

const _u = 'https://images.unsplash.com/photo';

/// Offline-first fallback only — NOT the source of truth for content.
///
/// The real content pipeline lives in `content/articles.json` +
/// `functions/scripts/seedArticles.js` (run via `npm run seed:articles`),
/// which upserts into the `articles` Firestore collection that
/// [articlesProvider] streams from. This constant exists purely so the
/// Explore screen has something to show before the first Firestore
/// snapshot arrives, or if the device is offline on first launch — see its
/// usage in explore_screen.dart (`fetched.isEmpty ? kArticles : fetched`).
/// Editing this list does NOT change what users see once Firestore has
/// data; edit `content/articles.json` and re-run the seed script instead.
const kArticles = <Article>[
  Article(
    id: '',
    order: 0,
    title: 'bacaklar duvara',
    category: ArticleCategory.wellness,
    readTime: '4 dk',
    excerpt:
        'Sıfır efor, beş dakika. Sinir sistemini dinlenme moduna alan poz.',
    imageUrl: '$_u-1695764062553-032bb346f524?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Gün boyu ayaktasın, oturuyorsun, koşturuyorsun. Bedenin saatlerdir aynı modda: devam et. Bacakları duvara dayama pozu, bu modu kapatmanın en zahmetsiz yolu. Sırt üstü uzanıyorsun, bacaklarını duvara yaslıyorsun, kollarını yanına bırakıyorsun. Hepsi bu.',
      'Beş dakika böyle kalmak dolaşımı tersine çevirir. Gün boyu ayaklarda biriken sıvı yumuşakça geri döner. Asıl güzellik ise sinir sisteminde yaşanır: bu poz bedenine güvende olduğunu söyler. Kalp atışın yavaşlar, nefesin kendiliğinden derinleşir.',
      'Dene: akşam eve gelince ya da uyumadan önce telefonu uzağa koy, beş dakikalık bir zamanlayıcı kur ve bacaklarını duvara uzat. Gözlerini kapat. Hiçbir şey yapman gerekmiyor, çünkü bu pozun bütün amacı hiçbir şey yapmamak.',
      'Regl döneminde, uzun bir yolculuğun ardından ya da yoğun bir antrenman gününde özellikle iyi gelir. Araç istemez, beceri istemez. Sana bir duvar ve beş dakika yeter.',
    ],
  ),
  Article(
    id: '',
    order: 1,
    title: 'uykuyu şımart',
    category: ArticleCategory.wellness,
    readTime: '5 dk',
    excerpt:
        'Uyku bir lüks değil, bakımın ta kendisi. Küçük dokunuşlarla başla.',
    imageUrl: '$_u-1614045959735-6f9dc28cb994?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Uykunu iyileştirmek için hayatını değiştirmen gerekmiyor. Akşamına birkaç küçük dokunuş eklemen yeterli. Bu yaklaşımın yeni bir adı var, sleepmaxxing deniyor, ama özü çok eski: uykuya değerli bir misafire hazırlanır gibi hazırlanmak.',
      'En etkili üç adım şunlar. Yatmadan bir saat önce büyük ışıkları kapatıp sıcak ve loş bir ışığa geç. Ekranı erkenden bırak. Odanı serin tut, çünkü beden uykuya geçerken ısısını düşürür ve serin bir oda bu geçişi kolaylaştırır.',
      'Üzerine koymak istersen seçenekler hazır: karartma perdesi ya da yumuşak bir uyku bandı, bir fincan papatya veya melisa çayı, yatmadan önce hafif bir esneme. Magnezyum takviyesini de çok duyacaksın; denemeden önce doktoruna ya da eczacına sormak en doğrusu.',
      'Hepsini birden yapmak zorunda değilsin. Bu akşam sadece ışıkları kıs. Yarın bir fincan çay ekle. Uyku, şımartıldıkça güzelleşen bir alışkanlıktır.',
    ],
  ),
  Article(
    id: '',
    order: 2,
    title: 'yorgun mu uyandın?',
    category: ArticleCategory.wellness,
    readTime: '4 dk',
    excerpt: 'Sekiz saat uyuyup yine yorgunsan, cevap tabağında olabilir.',
    imageUrl: '$_u-1623588689947-d276f8821d6e?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Yeterince uyuduğun hâlde sabah kendini ağır hissediyorsan, tabağına bakmanın zamanı gelmiş olabilir. Kasların ve sinirlerin düzgün çalışmak için potasyuma ihtiyaç duyar. Eksikliği kendini en çok bitkinlik ve hâlsizlik olarak gösterir.',
      'İyi haber şu: potasyum takviye rafında değil, manavda. Muz en bilineni ama tek seçenek değil. Ispanak, brokoli ve tatlı patates en zengin kaynaklardan. Kivi ile portakal hem potasyum hem C vitamini taşır. Avokado ise bu listenin sessiz şampiyonudur.',
      'Dene: bu hafta her güne bir potasyum kaynağı serpiştir. Sabah yulafına muz dilimle. Öğlen salatana bir avuç ıspanak kat. Ara öğünde bir kivi ye. Takip etmesi kolay bir plan ve etkisi birkaç günde hissedilir.',
      'Küçük bir not: sürekli ve açıklayamadığın bir yorgunluk varsa bunu yalnızca beslenmeyle çözmeye çalışma. Basit bir kan tahlili çok şey anlatır, doktorunla konuşmaktan çekinme.',
    ],
  ),
  Article(
    id: '',
    order: 3,
    title: 'glow suyu',
    category: ArticleCategory.tarif,
    readTime: '3 dk',
    excerpt: 'Havuç, limon, zencefil. Cilt bakımı bardakta başlar.',
    imageUrl: '$_u-1593954952271-ce947ed893cb?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Cilt bakımı sadece krem kavanozlarında olmuyor, bardakta da başlıyor. Bu üç malzemeli içecek, panolarda glow skin juice adıyla dolaşan tarifin sade hâli. Havuç beta karoten getiriyor, limon C vitamini, zencefil ise canlandıran keskinliğini.',
      'Tarif: 3 orta boy havuç, yarım limonun suyu ve küçük bir parmak taze zencefil. Katı meyve sıkacağın varsa hepsini sırayla sık. Yoksa blender da iş görür: havucu ve zencefili az suyla çek, ince süzgeçten geçir, limonu en sonda ekle.',
      'En iyi zamanı sabah, kahvaltıdan hemen önce. Öğleden sonraki enerji düşüşünde de çok iyi gelir. Soğuk servis et; buzlu hâliyle neredeyse limonata kadar içimlik.',
      'Küçük bir gerçeklik notu: hiçbir içecek tek başına cildi değiştirmez. Ama düzenli sebze, yeterli su ve iyi uykudan oluşan tabloya eklenen bu bardak, toplamın parlayan parçası olur.',
    ],
  ),
  Article(
    id: '',
    order: 4,
    title: 'matcha ritüeli',
    category: ArticleCategory.tarif,
    readTime: '4 dk',
    excerpt: 'Bir içecekten fazlası: günün ortasında iki dakikalık yavaşlama.',
    imageUrl: '$_u-1624893578106-a98840591afc?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Matchayı özel yapan şey sadece içeriği değil, hazırlanışı. Kahve makinesi düğmeye basınca çalışır; matcha ise senden iki dakika ister. Toz ölçülür, su ısınır, çırpılır. Bu küçük tören, günün ortasında zorunlu ve tatlı bir yavaşlama anı yaratır.',
      'İçerik tarafı da güçlü. Matchadaki L-theanine, kafeinin etkisini yumuşatır. Kahvenin ani yükselişi ve çöküşü yerine saatlere yayılan sakin bir odak verir. Uyanık ama gergin olmama hissinin içeceği budur.',
      'Tarif: 1 çay kaşığı matcha ve 60 ml sıcak su. Su kaynar olmasın, 70 ila 80 derece idealdir; daha sıcağı tozu acılaştırır. Çırpıcıyla ya da küçük bir telle, W çizerek köpürene kadar çırp. Sade içebilir ya da üzerine köpürtülmüş yulaf sütü ekleyip latte yapabilirsin.',
      'İpucu: ilk denemede tadı otsu gelirse miktarı azalt, yarım kaşıkla başla. Matcha alışılan değil, zamanla sevilen bir tattır. Tıpkı yavaşlamak gibi.',
    ],
  ),
  Article(
    id: '',
    order: 5,
    title: 'dikkatle hareket',
    category: ArticleCategory.wellness,
    readTime: '4 dk',
    excerpt: 'Mesele çok hareket etmek değil, hareket ederken orada olmak.',
    imageUrl: '$_u-1747239069226-55382c570116?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Wellness dünyasında güzel bir fikir dolaşıyor: bedenini hızla yormak yerine, yaptığın harekete gerçekten dikkat vermek. Podcast dinleyerek yürümek de güzeldir elbette. Ama bazen sadece adımlarını hissederek yürümek bambaşka bir şey verir.',
      'Bilim de bunu destekliyor. Dikkatle yapılan hareket, aynı egzersizi dalgın yapmaktan daha fazla stres azaltıyor. Çünkü zihin geleceği kurcalamayı bırakıp bedene dönüyor. Buna meditasyonun hareketli hâli demek hiç abartı olmaz.',
      'Dene: bugün kendine on dakikalık bir hareket molası ver. Kulaklık yok, ekran yok. Omuzlarını geriye yuvarla, boynunu iki yana uzat, ellerini yukarı süzdür. Her esnemede nefesinin nereye gittiğini izle.',
      'Bu yaklaşımın en güzel yanı çıtayı düşürmesi. Spor salonuna gitmek zorunda değilsin; odadan odaya dikkatle yürümek bile sayılır. Bedenin taşınmak değil, fark edilmek istiyor.',
    ],
  ),
  Article(
    id: '',
    order: 6,
    title: 'regl günlerinde şefkat',
    category: ArticleCategory.wellness,
    readTime: '5 dk',
    excerpt: 'O günlerde bedenin farklı bir tempo ister. Ona kulak ver.',
    imageUrl: '$_u-1621850204256-a84f9acbc5e9?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Regl döneminde kendini yorgun, şişkin ya da hassas hissetmek zayıflık değil, biyoloji. O günlerde stres hormonu yükselmeye daha yatkındır ve beden yüksek tempolu antrenman yerine nazik hareket ister. Ona bunu vermek tembellik değil, akıllıca bir ayarlamadır.',
      'Peki ne iyi gelir? Onarıcı yoga ya da yumuşak esneme. Derin nefes eşliğinde yapılan çok hafif hareketler. Öne eğilip bırakma pozları. Kısa ve yavaş bir yürüyüş. Ve tabii bacakları duvara uzatmak; kramplara ve şişkinliğe birebirdir.',
      'Kuru fırçalama da bu dönemin sevilen bakımlarından. Duştan önce, ayaklardan kalbe doğru uzun ve hafif fırça darbeleri uygula. Dolaşımı canlandırır, o ağır hissi hafifletir. Sert bastırmana gerek yok, ipeksi bir dokunuş yeterli.',
      'En önemlisi ölçüyü kendinden alman. Bugün ne kaldırabiliyorsan o kadar. Döngünle savaşmak yerine ona uyum sağlamak, ayın tamamında daha dengeli hissettirir.',
    ],
  ),
  Article(
    id: '',
    order: 7,
    title: 'günün tonunu sinir sistemin belirler',
    category: ArticleCategory.yazi,
    readTime: '5 dk',
    excerpt:
        'Sabahın ilk yarım saatinde verdiğin sinyaller bütün güne yayılır.',
    imageUrl: '$_u-1545386673-7723f55e5490?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Gün aynı gün. Ama bazı günler her şey üstüne gelir, bazı günler aynı yük hafif gelir. Fark çoğu zaman olaylarda değil, sinir sisteminin hangi modda olduğundadır. Tetikte mi, güvende mi?',
      'Sinir sistemin gün boyu ortamdan sinyal toplar ve tonunu ona göre kurar. Sabah gözünü açar açmaz haberlere ve bildirimlere bakmak ona tehlike sinyali gönderir. Gün ışığına bakmak, yavaş bir nefes almak, sıcak bir duş ise güvende olduğunu söyler.',
      'Sana pratik bir sabah üçlüsü: uyanınca önce pencereye git ve iki dakika gün ışığına bak. Sonra üç yavaş nefes al; verişin, alışından uzun sürsün. Ardından bir bardak su iç. Telefon bunlardan sonra gelsin. Haberler kaçmaz, sen kazanırsın.',
      'Gün içinde tonu düzeltmek de mümkün. Omuzların kulaklarına yaklaştıysa uzun bir nefes ver, çeneni gevşet, ayaklarını yere bas. Sinir sistemin büyük jestler istemez; küçük ve tekrarlı güven sinyalleriyle yumuşar.',
    ],
  ),
  Article(
    id: '',
    order: 8,
    title: 'nöroestetik: güzellik iyi geliyor',
    category: ArticleCategory.yazi,
    readTime: '5 dk',
    excerpt: 'Beynin, baktığı şeyden etkilenir. Ortamını ona göre kur.',
    imageUrl: '$_u-1617214922084-5db8d3c3df5a?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Neden bazı mekânlarda içimiz açılır da bazılarında daralır? Nöroestetik tam olarak bunu araştırıyor: güzelliğin beyindeki karşılığını. Bulgular net. Baktığımız şey, hissettiğimizi değiştiriyor. Yumuşak ışık, doğal dokular ve düzen, stres tepkisini ölçülebilir biçimde azaltıyor.',
      'Bunun için evini yenilemene gerek yok. Beyin en çok üç şeye tepki veriyor: ışık, düzen ve doğa. Gün ışığı alan bir köşe, toplanmış bir masa ve bir saksı yeşillik bir araya geldiğinde küçük bir sığınak doğuyor.',
      'Dene: en çok vakit geçirdiğin köşeye bir bak. Gözüne ilk çarpan üç şey ne? Kablo yığını ve kâğıt kalabalığıysa, beş dakikalık bir toplama bile o köşenin sana verdiği hissi değiştirir. Sonra bir bitki ya da sevdiğin tek bir obje ekle. Fazlası gürültü olur.',
      'Güzellik lüks değil, düzenleyicidir. Kendine güzel bir köşe kurmak boş bir estetik merakı değil; sinir sistemine günde yüz kez iyi sinyal gönderen sessiz bir bakımdır.',
    ],
  ),
  Article(
    id: '',
    order: 9,
    title: 'rutin değil, ritüel',
    category: ArticleCategory.yazi,
    readTime: '4 dk',
    excerpt: 'Aynı hareket, iki farklı his. Farkı yaratan şey niyet.',
    imageUrl: '$_u-1697029749544-ffa7f15f9dd0?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Rutin ve ritüel dışarıdan aynı görünür: her gün tekrarlanan hareketler. Ama rutin bitirmek için yapılır, ritüel yaşamak için. Dişini fırçalarken aklın toplantıdaysa o bir rutindir. Suyun sesini duyuyorsan ve o an oradaysan, aynı hareket ritüele dönüşmüştür.',
      'Hayatını romantize et sözü de aslında bunu anlatıyor. Yeni şeyler eklemek değil, var olanları özenle yapmak. Kahveni sevdiğin fincana koymak, akşam çayını pencerenin önünde içmek, krem sürerken acele etmemek. Küçük özenler sıradan anı değerli kılar.',
      'Bunun pratik bir karşılığı da var: ritüeller kalıcıdır. Zorla sürdürülen alışkanlıklar irade tükenince biter. Keyif veren ritüeller ise kendi kendini taşır. Tutarlılığın sırrı disiplin değil, sevmektir.',
      'Dene: bugün zaten yaptığın tek bir şeyi seç ve onu ritüelleştir. Daha yavaş, daha güzel, daha senin olsun. Hayat büyük anlardan değil, özenle yaşanmış küçük anlardan dokunur.',
    ],
  ),
  Article(
    id: '',
    order: 10,
    title: 'haftalık sıfırlama',
    category: ArticleCategory.yazi,
    readTime: '5 dk',
    excerpt: 'Pazar akşamı bir saat: haftaya yorgun değil, hazır başla.',
    imageUrl: '$_u-1562878274-ad7a29ea8cdd?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Pazartesi sabahlarının ağırlığı çoğu zaman pazartesiden gelmez. Kapanmamış bir haftanın üzerine yenisini başlatmaktan gelir. Haftalık sıfırlama tam bu yüzden var: haftada bir saatlik küçük bir tören ile biteni kapatmak ve geleni hafifçe karşılamak.',
      'Basit bir akış şöyle olabilir. Önce ortamı topla; masa, çanta ve telefon galerisi dahil. Sonra zihni boşalt: yarım kalanları, aklında dönenleri ve ertelediklerini tek bir listeye dök. Kağıda inen düşünce, gece üçte seni uyandırmaz.',
      'Ardından haftaya nazikçe bak. Takvimden üç önemli şeyi seç ve yalnızca onlara söz ver. Yedi güne yirmi hedef sığdırmak sıfırlama değil, yeni bir yorgunluk hazırlığıdır. Az söz, tam tutmak: denge burada.',
      'Kapanışı güzelleştir. Bir duş, sevdiğin bir çay, erken bir uyku. Sıfırlamanın amacı mükemmel bir hafta planlamak değil, kendine düzenli bir yumuşak başlangıç hediye etmek.',
    ],
  ),
  Article(
    id: '',
    order: 11,
    title: 'şükranın bilimi',
    category: ArticleCategory.yazi,
    readTime: '4 dk',
    excerpt:
        'Teşekkür etmek duygusallık değil; beynini yeniden şekillendiren bir egzersiz.',
    imageUrl: '$_u-1681396059172-7532b1ef8b47?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Şükran pratiği kulağa fazla yumuşak gelebilir, ama nörobilim aynı fikirde değil. Düzenli olarak iyi şeyleri fark etmek, beynin ödül ve bağ kurma devrelerini güçlendiriyor. Araştırmalar bunu stres hormonlarında düşüş ve ruh hâlinde ölçülebilir bir iyileşme olarak görüyor.',
      'Mekanizması sade: beynin neye odaklanırsan onu büyütür. Gün boyu eksikleri tararsan eksik bulma konusunda ustalaşırsın. İyi olanı taramaya başladığında ise aynı yetenek bu kez senin lehine çalışır.',
      'Pratik de bir o kadar sade. Akşam, uyumadan önce günün içinden üç iyi şey seç ve yaz. Büyük olmaları gerekmiyor; sıcak bir duş, güzel bir mesaj, pencereden vuran ışık. Önemli olan hatırlarken o anı bir saniye yeniden hissetmen.',
      'İki hafta üst üste dene. Değişen şey hayatın değil, hayatına bakan gözün olacak. Ve o göz, günün tonunu sandığından çok belirliyor.',
    ],
  ),
  Article(
    id: '',
    order: 12,
    title: 'vücut saatinle barış',
    category: ArticleCategory.wellness,
    readTime: '5 dk',
    excerpt: 'Uykunun sırrı gecede değil, sabahın ilk ışığında saklı.',
    imageUrl: '$_u-1582220876602-9b12ee97659b?auto=format&fit=crop&w=1200&q=80',
    body: [
      'İçinde, sen hiç uğraşmadan çalışan bir saat var. Sirkadiyen ritim denen bu iç saat ne zaman uyanacağını, ne zaman acıkacağını ve ne zaman uykunun geleceğini ayarlıyor. Uyku sorunlarının birçoğu aslında saat ile hayatın birbirinden kopmasından doğuyor.',
      'Saati kuran en güçlü sinyal ışık. Sabah ilk saatte gördüğün gün ışığı, iç saatine güne başladığını söyler ve akşam melatoninin tam zamanında salgılanmasını kolaylaştırır. Yani gece iyi uyumak, aslında sabah pencereye gitmekle başlar.',
      'Dene: uyandıktan sonraki bir saat içinde en az beş dakika gün ışığı gör. Balkon, pencere önü ya da kısa bir yürüyüş fark etmez. Akşam ise tersini yap; ışıkları kıs ve parlak ekranı azalt. Saatine iki net sinyal: gündüz gündüz, gece gece.',
      'Bir de tutarlılık meselesi var. Her gün aşağı yukarı aynı saatte yatıp kalkmak, saatini hafta sonu dahil sabit tutar. Vücut saatiyle savaşan kaybeder; onunla barışan sabahları çalar saate küsmeden uyanır.',
    ],
  ),
  Article(
    id: '',
    order: 13,
    title: 'yemek ilaçtır',
    category: ArticleCategory.tarif,
    readTime: '5 dk',
    excerpt: 'Bütünsel beslenme karmaşık değil: tabağına bütün hâlinde bak.',
    imageUrl: '$_u-1772453609632-2f4aa857f56e?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Bütünsel beslenme, kalori saymanın ve yasak listelerinin tersidir. Soru şudur: bu yediğim şey bedenime, zihnime ve enerjime bütün olarak ne yapıyor? Yemek yalnızca yakıt değil; ruh hâlini, uykuyu ve odaklanmayı her gün yeniden yazan bir bilgi kaynağıdır.',
      'Pratikte üç ilkeye iner. Bir: mümkün olduğunca bütün gıda; paketin içindekiler listesi kısaldıkça beden mutlu olur. İki: renk çeşitliliği; tabaktaki her renk farklı bir besin ailesi demektir. Üç: yavaş yemek; sindirim çiğnemeyle başlar, ekran karşısında aceleyle değil.',
      'Kolay bir başlangıç tabağı: bir avuç yeşillik, bir tahıl (bulgur ya da kinoa), bir protein (nohut, yumurta ya da balık), bir sağlıklı yağ (zeytinyağı ya da avokado) ve üzerine limon. Beş bileşen, on dakika, tam bir öğün.',
      'Kendine şu soruyu sormayı alışkanlık yap: bu yemekten bir saat sonra nasıl hissediyorum? Cevaplar birikince, kimsenin listesine ihtiyaç duymadan kendi beslenme pusulan oluşur.',
    ],
  ),
  Article(
    id: '',
    order: 14,
    title: 'azı çokluk: minimalist bakım',
    category: ArticleCategory.yazi,
    readTime: '4 dk',
    excerpt: 'Wellness bir yapılacaklar listesi değil. Azalt, derinleş.',
    imageUrl: '$_u-1652517209166-f17a2742a5fe?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Bir yerden sonra kendine iyi bakmak bile yorucu bir listeye dönüşebiliyor: on adımlı cilt bakımı, beş takviye, üç uygulama, iki rutin. Minimalist wellness buna karşı sade bir soru soruyor: bunların hangisi gerçekten iyi geliyor?',
      'Kural basit. Az şey, tam yapılmış hâliyle, çok şeyin yarım hâlinden daha iyi hissettirir. Günde on dakikalık tek bir gerçek mola, aceleyle geçilen beş sözde ritüelden daha çok şey verir.',
      'Dene: bu hafta kendi bakım envanterini çıkar. Yaptığın her şeyi yaz ve her birine tek soru sor: bunu bitirince gerçekten daha iyi hissediyor muyum, yoksa sadece listeden mi siliyorum? İkinci gruba girenleri gönül rahatlığıyla bırak.',
      'Geriye kalan birkaç şeyi ise koru ve derinleştir. Sadelik bir eksiklik değil; neyin işe yaradığını bilecek kadar kendini tanımaktır.',
    ],
  ),
  Article(
    id: '',
    order: 15,
    title: 'küçük adımlar, büyük fark',
    category: ArticleCategory.yazi,
    readTime: '4 dk',
    excerpt: 'Hayat bir gecede değişmez. Her gün yüzde bir değişir.',
    imageUrl: '$_u-1677846092922-5b685ba0afb2?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Büyük değişim kararları heyecan verir: yarından itibaren her sabah koşacağım, şekeri tamamen bırakıyorum, her gün kitap bitireceğim. Ve çoğu, üçüncü günün akşamında sessizce rafa kalkar. Sorun sende değil, adımın boyutunda.',
      'Küçük adımların gücü matematikten gelir. Her gün yüzde bir iyileşme, yıl sonunda katlanarak büyür. Ama asıl sihri psikolojik: küçük adım irade istemez, bahane üretmez ve her tamamlandığında beynine küçük bir başarı sinyali gönderir.',
      'Ölçüyü gülünç derecede küçük tut. Kitap okumak istiyorsan hedef bir sayfa olsun. Hareket istiyorsan beş dakikalık yürüyüş. Su içmeyi unutuyorsan sabah tek bardak. Devamı çoğu gün kendiliğinden gelir; gelmediği gün de hedef zaten tutmuştur.',
      'Bir ay sonra dönüp baktığında görkemli bir dönüşüm görmeyeceksin. Sessizce yerleşmiş, artık düşünmeden yaptığın birkaç iyi alışkanlık göreceksin. Kalıcı değişim böyle görünür.',
    ],
  ),
];
