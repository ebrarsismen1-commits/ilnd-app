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

  static ArticleCategory fromString(String s) =>
      ArticleCategory.values.firstWhere((e) => e.name == s,
          orElse: () => ArticleCategory.wellness);
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
    final d = doc.data()! as Map<String, dynamic>;
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

const kArticles = <Article>[
  // ── HERO ────────────────────────────────────────────────────────────────────
  Article(
    id: '',
    order: 0,
    title: 'sabah altin saatini cal',
    category: ArticleCategory.wellness,
    readTime: '5 dk',
    excerpt:
        'Ilk 30 dakikan — telefon yok, bildirim yok. Sadece sen ve sessizlik.',
    imageUrl:
        '$_u-1491555103944-7c647fd857e6?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Sabah alarmin caldığında beynin "varsayılan mod ağı" hala aktif — yani sezgisel, yaratıcı, sessiz. Bu pencere yaklasık 30 dakika suruyor. Telefonuna uzandığında o pencereyi kapatıyorsun.',
      'Dene: Gozlerin acılır acılmaz telefona bakma. Once bir bardak su. Sonra uc derin nefes. Bugün ne hissettirmesini istiyorsun? Bir kelime bile yeterli: sakin, odaklı, hafif.',
      'Bu alıskanlıgı uc gun ust uste yaptığında fark edeceksin: gun daha senin gibi hissettiriyor. Cunku ilk dusuncen bir bildirim değil, kendi sesin oldu.',
      'Mukemmel olmak zorunda değil. Sadece bir sabah. Sonra bir tane daha.',
    ],
  ),

  // ── FEATURED ────────────────────────────────────────────────────────────────
  Article(
    id: '',
    order: 1,
    title: 'matcha latte',
    category: ArticleCategory.tarif,
    readTime: '3 dk',
    excerpt: 'Kafein olmadan enerji. Anksiyete olmadan odaklanma.',
    imageUrl:
        '$_u-1536256263959-49fc93bb0d7e?auto=format&fit=crop&w=900&q=75',
    body: [
      'Matcha icindeki L-theanine, kafeini yavaslatar. Kahve gibi ani bir yukselis ve dusus yerine, 4-6 saat boyunca duz ve sakin bir enerji hissi verir.',
      'Malzemeler: 1 cay kasigi ceremony grade matcha, 60 ml sicak su (70 derece), 200 ml yulaf sutu. Once matcha ve suyu cirpin. Kopurtulmus yulaf sutunu ustune ekleyin.',
      'Ipucu: Icine bir tutam tarcin ve bir damla vanilya ekle. Sonuca surüp yapilmis gibi bakacaksın.',
    ],
  ),
  Article(
    id: '',
    order: 2,
    title: 'dopamin menusu',
    category: ArticleCategory.yazi,
    readTime: '6 dk',
    excerpt: 'Scrolling degil — gercekten iyi hissettiren seylerin listesi.',
    imageUrl:
        '$_u-1499750310107-5fef28a66643?auto=format&fit=crop&w=900&q=75',
    body: [
      'Beynin her zaman dopamin arar. Mesele kotu dopamine, iyi dopamine demek degil — her ikisi de odul hissettiriyor. Mesele hangisinin ardindan daha iyi hissettirdigini bilmek.',
      '"Dopamin menusu" basit bir fikir: iyi hissettiren, ama sonrasinda da iyi hissettiren seylerin kisa listesi. Scroll, yiyecek, alisveris gibi anlik tatmin degil — hareket, baglanti, yaratma gibi kalici tatmin.',
      'Ornek bir menu: sabah gunesi (5 dk, balkon ya da pencere), favori sarki ile dans (1 sarki yeterli), bir arkadasa sesli mesaj, elle bir seyler pisirmek, 20 dakika yuruyu.',
      'Kendi menunu cikar. Kagida yaz. Duvara as. Bir dahaki sikildim aninda telefona uzanmadan once o listeye bak.',
    ],
  ),
  Article(
    id: '',
    order: 3,
    title: 'smoothie kasesi',
    category: ArticleCategory.tarif,
    readTime: '4 dk',
    excerpt: 'Gercekten lezzetli. Hazırlanması 5 dakika.',
    imageUrl:
        '$_u-1546069901-ba9599a7e63c?auto=format&fit=crop&w=900&q=75',
    body: [
      'Smoothie kasesi sadece guzel gorunduğu icin değil, doyurucu oldugu icin isliyor. Icindeki lif ve protein, kan sekerinizi saatlerce dengede tutuyor.',
      'Kase tabani: 1 dondurulmus muz, yarim bardak dondurulmus bogurtlen, 3 yemek kasigi yogurt, cok az sut (cok sivi olmasın). Blenderdan koyu kıvamda gecir.',
      'Uzeri: granola, taze cilek, muz dilimleri, bir tutam keten tohumu, biraz fistik ezmesi. Simetrik mi dizersen daha lezzetli mi oluyor? Hayir. Ama daha iyi hissettiriyor.',
    ],
  ),

  // ── FEED ────────────────────────────────────────────────────────────────────
  Article(
    id: '',
    order: 4,
    title: 'nefes & sakinlik',
    category: ArticleCategory.wellness,
    readTime: '4 dk',
    excerpt: 'Zihnini yavaslatamanin en hizli yolu, en yavas seyden gecer.',
    imageUrl:
        '$_u-1506126613408-eca07ce68773?auto=format&fit=crop&w=900&q=70',
    body: [
      'Gun icerisinde fark etmeden tuttuğumuz nefes, zihnimizin en sadik aynasıdır. Stresliyken sig ve hizli, sakinken derin ve yavas nefes aliriz. Bu iliski cift yonlu — nefesi bilinçli yavaslatirsak, zihin de onu takip eder.',
      'Bugün denemen icin bir ritueli: 4 saniye burnundan al, 4 saniye tut, 6 saniye agzindan ver. Sadece uc kez. Vermeyi almaktan uzun tutmak, bedenine guvendesin mesaji gonderir.',
      'Sabah uyaninca, bir toplanti oncesi ya da gece yatmadan. Gunde bir dakika bile yeterli. Mukemmel olmak zorunda degilsin — sadece bir nefes, sonra bir tane daha.',
    ],
  ),
  Article(
    id: '',
    order: 5,
    title: 'uyku ritueli',
    category: ArticleCategory.wellness,
    readTime: '5 dk',
    excerpt: 'Uyumadan onceki 1 saat, ertesi gunu baslatir.',
    imageUrl:
        '$_u-1631049307264-da0d7539e0b7?auto=format&fit=crop&w=900&q=75',
    body: [
      'Uyku kaliteni belirleyen, kac saat uyudugundan cok nasil uyuduğundur. Ve nasil kismi buyuk olcude yatmadan onceki 60 dakikada sekilleniyor.',
      'Basit bir wind-down rutini: yatmadan 1 saat once buyuk ekranlar kapanir. Isiklar kisılır. Bir seyler yaz — yarin ne yapacagin, bugün iyi gecen bir sey. Yazarak kafandan cikar.',
      'Bonus: magnezyum (glisinatlı form) uyku kalitesini ciddi artirdiği icin en cok arastırılan takviyelerden biri. Bir bardak papatya cayiyla da ayni etki.',
    ],
  ),
  Article(
    id: '',
    order: 6,
    title: 'avokadolu yumurta',
    category: ArticleCategory.tarif,
    readTime: '2 dk',
    excerpt: '10 dakikada, 4 malzemeyle haftanın en iyi kahvaltısı.',
    imageUrl:
        '$_u-1482049016688-2d3e1b311543?auto=format&fit=crop&w=900&q=75',
    body: [
      'Sabah protein ve saglikli yag ile baslamak, kahve olmadan da odaklanmanı saglar. Bu tarif gercekten bes dakika.',
      'Malzemeler: 2 yumurta (pose ya da cilbir), yarim avokado, bir dilim tam tahilli ekmek, kirmizi pul biber, tuz, limon suyu.',
      'Firinda da pisirebiirsin: dort bolunmus avokadolarin icine birer yumurta kir, 180 derecede 12 dakika. Bagimsiz hissettiriyor, kolay temizleniyor.',
    ],
  ),
  Article(
    id: '',
    order: 7,
    title: 'sinir koymak',
    category: ArticleCategory.yazi,
    readTime: '7 dk',
    excerpt: '"Hayir" demek, iliskilerini degil; enerjini korur.',
    imageUrl:
        '$_u-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=900&q=75',
    body: [
      'Cogumuz hayir demeyi ogrenemedik. Onaylanmak, sevilmek, catismadan kacınmak isteriz. Ama her evet, aslinda baska bir seye soylenmus sessiz bir hayir dir — cogu zaman kendine.',
      'Sinir koymak bencillik degil. Tam tersine, iliskilerini daha donust kilar. Insanlar gercekten ne istedigini bildiklerinde, seninle daha net bir bag kurar.',
      'Kucuk basla. Bu hafta sadece bir kez, normalde otomatik evet diyecegin bir seye su an musait degilim de. Suculluk hissetmen normal — bu, eski bir aliskanligin direnci. Gecer.',
    ],
  ),
  Article(
    id: '',
    order: 8,
    title: 'hareket = ilac',
    category: ArticleCategory.wellness,
    readTime: '4 dk',
    excerpt: 'Gym degil. Bedenini gunde bir kez tasimak yeterli.',
    imageUrl:
        '$_u-1571019613454-1cb2f99b2d8b?auto=format&fit=crop&w=900&q=75',
    body: [
      'Egzersiz deyince akla spor salonu ve ter geliyor. Ama arastirmalar farkli bir sey soyluyor: gunde 20 dakika orta yogunlukta hareket, depresyon uzerinde ilacla kiyaslanabilir etki birakiryor.',
      'Yogun bir antrenman degil. Hizli bir yuruyu, muzikle dans, merdiven tirmanma, esneme. Beyin icin onemli olan hareketin kendisi — kalp atisinin biraz hızlanması yetiyor.',
      'Bugun icin gorev: ev icinde 10 dakika yuru. Gercekten. Sadece 10 dakika, kulaklikla, odadan odaya. Gulunc geliyor mu? Evet. Ise yariyor mu? Kesinlikle.',
    ],
  ),
  Article(
    id: '',
    order: 9,
    title: 'dijital detoks',
    category: ArticleCategory.yazi,
    readTime: '6 dk',
    excerpt: 'Telefonu birakmak degil mesele — dikkatini geri almak.',
    imageUrl:
        '$_u-1544367571-8b0a8c9eb5a9?auto=format&fit=crop&w=900&q=75',
    body: [
      'Dijital detoks denince akla telefonu bir kenara firlatmak gelir. Ama mesele cihazi suclamamak; dikkatinin nereye aktığini fark etmek. Ekran kotu degil — dikkatin daginik olmasi yorucu.',
      'Kucuk bir deney yap: uyandindan sonraki ilk 30 dakika telefona bakma. Onun yerine pencereden disari bak, su ic, bir esneme yap. Gunun ilk dusuncesi bir bildirim degil, kendi dusuncen olsun.',
      'Aksam da benzer bir sinir koy: yatmadan bir saat once ekranlar kapanir. Ilk birkac gun zor gelebilir — beynin o kucuk dopamin durtusu ne alisıms. Ama bir hafta sonra uykunun derinlestigini fark edeceksin.',
    ],
  ),
];
