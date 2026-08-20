import 'package:cloud_firestore/cloud_firestore.dart';

/// Editoryal kategoriler (owner kararı 2026-08-20). Beşi de içerik
/// planındaki adlandırmayı taşır; sıra da ondan gelir.
///
/// Önceki üçlü (`wellness` / `tarif` / `yazi`) kaldırıldı ama Firestore'da
/// o değerlerle yazılmış dokümanlar var — [fromString] onları yeni
/// karşılıklarına taşır (bkz. eski-değer eşlemesi). Yoksa yayındaki her
/// makale sessizce ilk kategoriye düşerdi.
enum ArticleCategory { meditasyon, beslenme, hareket, ozBakim, gelisim }

extension ArticleCategoryX on ArticleCategory {
  /// Kart üzerindeki kategori etiketi. Büyük harfe UI'da çevrilir.
  String get tag => switch (this) {
    ArticleCategory.meditasyon => 'meditasyon',
    ArticleCategory.beslenme => 'beslenme',
    ArticleCategory.hareket => 'hareket',
    ArticleCategory.ozBakim => 'öz bakım',
    ArticleCategory.gelisim => 'gelişim',
  };

  /// Görsel yoksa kapağa çizilen küratörlü degrade (EditorialGradient).
  /// Dört palet var; sakinlik yeşili meditasyona, sıcak terracotta
  /// beslenmeye, derinlik gelişime gider.
  int get palette => switch (this) {
    ArticleCategory.meditasyon => 0,
    ArticleCategory.beslenme => 1,
    ArticleCategory.hareket => 2,
    ArticleCategory.ozBakim => 0,
    ArticleCategory.gelisim => 3,
  };

  String get firestoreValue => name;

  /// Eski üçlüden gelen dokümanlar için geçiş eşlemesi:
  /// tarif → beslenme (hepsi yemek tarifiydi), wellness → öz bakım,
  /// yazı → gelişim.
  static const _legacy = <String, ArticleCategory>{
    'tarif': ArticleCategory.beslenme,
    'wellness': ArticleCategory.ozBakim,
    'yazi': ArticleCategory.gelisim,
  };

  static ArticleCategory fromString(String s) {
    final legacy = _legacy[s];
    if (legacy != null) return legacy;
    return ArticleCategory.values.firstWhere(
      (e) => e.name == s,
      orElse: () => ArticleCategory.gelisim,
    );
  }
}

/// Bir makalenin İngilizce karşılığı — boş alanlar Türkçesine düşer.
class ArticleTranslation {
  const ArticleTranslation({
    this.title = '',
    this.readTime = '',
    this.excerpt = '',
    this.body = const [],
    this.ingredients = const [],
    this.steps = const [],
  });

  final String title;
  final String readTime;
  final String excerpt;
  final List<String> body;
  final List<String> ingredients;
  final List<String> steps;

  factory ArticleTranslation.fromMap(Map<String, dynamic> m) =>
      ArticleTranslation(
        title: m['title'] as String? ?? '',
        readTime: m['readTime'] as String? ?? '',
        excerpt: m['excerpt'] as String? ?? '',
        body: List<String>.from(m['body'] as List? ?? []),
        ingredients: List<String>.from(m['ingredients'] as List? ?? []),
        steps: List<String>.from(m['steps'] as List? ?? []),
      );

  Map<String, dynamic> toMap() => {
    'title': title,
    'readTime': readTime,
    'excerpt': excerpt,
    'body': body,
    'ingredients': ingredients,
    'steps': steps,
  };
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
    this.ingredients = const [],
    this.steps = const [],
    this.videoUrl,
    this.allergens = const [],
    this.diets = const [],
    this.en,
  });

  final String id;
  final String title;
  final ArticleCategory category;
  final String readTime;
  final String excerpt;
  final List<String> body;
  final String? imageUrl;
  final int order;

  /// Tarif alanları — dolu olduklarında makale interaktif tarife dönüşür:
  /// tik'lenebilir malzeme listesi + adım adım pişirme modu.
  final List<String> ingredients;
  final List<String> steps;

  /// İleride tarif videosu için ayrılmış alan; şu an oynatıcı yok.
  final String? videoUrl;

  /// İçerdiği alerjenler — onboarding alerji anahtarlarıyla aynı sözlük
  /// (findik_kabuklu, sut_laktoz, gluten, deniz_urunu, yumurta). Kural:
  /// şüpheli/opsiyonel malzeme bile ETİKETLENİR (tutucu güvenlik).
  final List<String> allergens;

  /// Uygun olduğu beslenme tercihleri — onboarding diet anahtarları
  /// (vejetaryen, vegan, glutensiz, laktozsuz). Boş = yalnız 'yok' tercihine.
  final List<String> diets;

  /// İngilizce çeviri — yoksa EN kullanıcı Türkçesini görür (asla boş ekran).
  final ArticleTranslation? en;

  bool get isRecipe => ingredients.isNotEmpty && steps.isNotEmpty;

  /// Uygulama diline göre gösterilecek sürümü döndürür. Alan bazında düşer:
  /// çeviride eksik kalan alan Türkçesiyle tamamlanır.
  Article forLocale(String localeCode) {
    final t = en;
    if (!localeCode.startsWith('en') || t == null) return this;
    return Article(
      id: id,
      title: t.title.isNotEmpty ? t.title : title,
      category: category,
      readTime: t.readTime.isNotEmpty ? t.readTime : readTime,
      excerpt: t.excerpt.isNotEmpty ? t.excerpt : excerpt,
      body: t.body.isNotEmpty ? t.body : body,
      imageUrl: imageUrl,
      order: order,
      ingredients: t.ingredients.isNotEmpty ? t.ingredients : ingredients,
      steps: t.steps.isNotEmpty ? t.steps : steps,
      videoUrl: videoUrl,
      allergens: allergens,
      diets: diets,
      en: t,
    );
  }

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
      ingredients: List<String>.from(d['ingredients'] as List? ?? []),
      steps: List<String>.from(d['steps'] as List? ?? []),
      videoUrl: d['videoUrl'] as String?,
      allergens: List<String>.from(d['allergens'] as List? ?? []),
      diets: List<String>.from(d['diets'] as List? ?? []),
      en: d['en'] is Map
          ? ArticleTranslation.fromMap(
              Map<String, dynamic>.from(d['en'] as Map),
            )
          : null,
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
    'ingredients': ingredients,
    'steps': steps,
    'videoUrl': videoUrl,
    'allergens': allergens,
    'diets': diets,
    if (en != null) 'en': en!.toMap(),
  };
}

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
    id: 'klasik-sporcu-icecegi',
    order: 0,
    title: 'uzun kardiyolar için klasik sporcu içeceği',
    category: ArticleCategory.beslenme,
    readTime: '2 dk',
    excerpt:
        'Su, şeker, tuz ve bir tutam turunçgil. Rafta aradığın şey mutfağında.',
    body: [
      'Bütün sporcu içeceklerinin atası bu. Şeker burada tat için değil: sodyumla birlikte çalışıp suyu bağırsaktan kana çeken şey o. Turunçgil suyu ise içeceği içilebilir kılıyor — tuzlu şekerli su tek başına kimsenin boğazından geçmez.',
      'Bir saati aşan kardiyoda, sıcakta ve çok terlediğin günlerde işini görür. Tek seferde bitirme; on beş dakikada bir birkaç yudum mideyi zorlamaz ve daha iyi emilir.',
    ],
    ingredients: [
      '1 litre su',
      '50 g şeker (yaklaşık çeyrek su bardağı)',
      'çeyrek çay kaşığı tuz',
      '60 ml portakal suyu',
      '30 ml limon suyu',
    ],
    steps: [
      'Şekeri az miktarda ılık suda çözdür — soğuk suda dibe çöker ve orada kalır.',
      'Tuzu ekleyip karıştır.',
      'Portakal ve limon suyunu ekle, kalan suyla bir litreye tamamla.',
      'Buzdolabında soğut. Antrenman boyunca on beş dakikada bir birkaç yudum iç.',
    ],
    diets: ['vegan', 'vejetaryen', 'glutensiz', 'laktozsuz'],
    en: ArticleTranslation(
      title: 'the classic sports drink for long cardio',
      readTime: '2 min',
      excerpt:
          'Water, sugar, salt and a hint of citrus. What you look for on the shelf is in your kitchen.',
      body: [
        'This is the ancestor of every sports drink. The sugar is not there for taste: together with sodium it is what pulls water from your gut into your blood. The citrus makes it drinkable — salty sugar water alone goes down nobody\'s throat.',
        'It earns its place in cardio past an hour, in the heat, and on days you sweat hard. Do not down it in one go; a few sips every fifteen minutes sit easier and absorb better.',
      ],
      ingredients: [
        '1 litre of water',
        '50 g sugar (about a quarter cup)',
        'a quarter teaspoon of salt',
        '60 ml orange juice',
        '30 ml lemon juice',
      ],
      steps: [
        'Dissolve the sugar in a little warm water — in cold water it sinks and stays there.',
        'Add the salt and stir.',
        'Add the orange and lemon juice, top up to a litre with the rest of the water.',
        'Chill it. Sip a few mouthfuls every fifteen minutes through your session.',
      ],
    ),
  ),
  Article(
    id: 'akcaagacli-elektrolit',
    order: 1,
    title: 'hassas mideler için akçaağaçlı içecek',
    category: ArticleCategory.beslenme,
    readTime: '2 dk',
    excerpt:
        'Rafine şeker yerine akçaağaç: daha yavaş, daha yumuşak bir enerji.',
    body: [
      'Akçaağaç şurubu buraya yalnız şeker olarak değil, yanında getirdiği manganez ve çinkoyla giriyor. Rafine şekere göre daha yavaş, daha yumuşak bir eğri çiziyor — hassas mideler için fark yaratan şey bu.',
      'Uzun ve düşük tempolu antrenmanlar bunu sever. Sabah yapılan hafif kardiyoda da iyi gider: az ama sürekli enerji.',
    ],
    ingredients: [
      '750 ml su',
      '1 yemek kaşığı akçaağaç şurubu',
      '1 tutam deniz tuzu',
      '2 yemek kaşığı limon suyu',
    ],
    steps: [
      'Akçaağaç şurubunu az suyla karıştırıp iyice çözdür.',
      'Deniz tuzunu ekle.',
      'Limon suyunu ve kalan suyu ekleyip çalkala.',
      'Soğuk servis et, antrenman boyunca azar azar iç.',
    ],
    diets: ['vegan', 'vejetaryen', 'glutensiz', 'laktozsuz'],
    en: ArticleTranslation(
      title: 'a maple drink for sensitive stomachs',
      readTime: '2 min',
      excerpt: 'Maple instead of refined sugar: a slower, softer energy.',
      body: [
        'Maple syrup comes in here not just as sugar but with the manganese and zinc it carries. Against refined sugar it draws a slower, gentler curve — which is what makes the difference for a sensitive stomach.',
        'Long, low-tempo sessions like this one. It also works for easy morning cardio: a little energy, continuously.',
      ],
      ingredients: [
        '750 ml water',
        '1 tablespoon maple syrup',
        'a pinch of sea salt',
        '2 tablespoons lemon juice',
      ],
      steps: [
        'Stir the maple syrup into a little water until fully dissolved.',
        'Add the sea salt.',
        'Add the lemon juice and the rest of the water, then shake.',
        'Serve cold and sip through your session.',
      ],
    ),
  ),
  Article(
    id: 'hizli-hidrasyon',
    order: 2,
    title: 'kısa ve sert seanslar için ballı hidrasyon içeceği',
    category: ArticleCategory.beslenme,
    readTime: '2 dk',
    excerpt:
        'Az karbonhidrat, yeterli sodyum. Terle gideni en kısa yoldan geri koyar.',
    body: [
      'Bu tarif enerji için değil, sıvı için. Az karbonhidrat kasten: içeceğin yoğunluğu düştükçe mideden çıkışı hızlanır, yani su sana daha çabuk ulaşır. Tuz da o suyu bedende tutar.',
      'Kısa ve sert seanslardan sonra, terlediğin ama enerjiye ihtiyacın olmadığı günlerde. Sıcakta antrenmandan önce içmek de işe yarar — susamadan başlamak, susadıktan sonra yetişmeye çalışmaktan iyidir.',
    ],
    ingredients: [
      '500 ml su',
      '1 yemek kaşığı bal',
      '1 tutam tuz',
      '1 yemek kaşığı limon suyu',
    ],
    steps: [
      'Balı bir miktar ılık suda çözdür; kaynar suya koyma, aroması kaybolur.',
      'Tuzu ekleyip karıştır.',
      'Limon suyunu ve kalan suyu ekle.',
      'Oda sıcaklığında ya da hafif soğuk iç.',
    ],
    diets: ['vejetaryen', 'glutensiz', 'laktozsuz'],
    en: ArticleTranslation(
      title: 'a honey hydration drink for short hard sessions',
      readTime: '2 min',
      excerpt:
          'Low carbohydrate, enough sodium. The shortest route back to what you sweated out.',
      body: [
        'This one is for fluid, not fuel. The low carbohydrate is deliberate: the thinner the drink, the faster it leaves your stomach, so the water reaches you sooner. The salt then keeps it in you.',
        'For short hard sessions, on days you sweat but do not need energy. Drinking it before training in the heat works too — starting before you are thirsty beats chasing thirst afterwards.',
      ],
      ingredients: [
        '500 ml water',
        '1 tablespoon honey',
        'a pinch of salt',
        '1 tablespoon lemon juice',
      ],
      steps: [
        'Dissolve the honey in a little warm water; never boiling, the aroma is lost.',
        'Add the salt and stir.',
        'Add the lemon juice and the rest of the water.',
        'Drink at room temperature or lightly chilled.',
      ],
    ),
  ),
  Article(
    id: 'hindistan-cevizi-turuncgil',
    order: 3,
    title: 'antrenman sonrası için hindistan cevizli içecek',
    category: ArticleCategory.beslenme,
    readTime: '2 dk',
    excerpt:
        'Potasyumu yüksek, serinletici. Bitişten sonraki ilk saatin içeceği.',
    body: [
      'Hindistan cevizi suyu doğal olarak potasyum taşır; terle kaybettiğin ikinci önemli mineral odur. Tek başına içildiğinde sodyumu yetersiz kalır, o yüzden buraya küçük bir tutam tuz girer — ikisi birlikte daha iyi çalışır.',
      'Bitişten sonraki ilk saat bunun zamanı. Yaz sıcağında yapılan her seansın ardından serinletici bir toparlanma.',
    ],
    ingredients: [
      '250 ml hindistan cevizi suyu',
      '250 ml su',
      '100 ml ananas-portakal suyu',
      '1/8 çay kaşığı tuz',
    ],
    steps: [
      'Hindistan cevizi suyunu ve suyu bir sürahide birleştir.',
      'Meyve suyunu ekle.',
      'Tuzu ekleyip iyice karıştır.',
      'Buzla soğuk servis et.',
    ],
    diets: ['vegan', 'vejetaryen', 'glutensiz', 'laktozsuz'],
    en: ArticleTranslation(
      title: 'a coconut drink for after training',
      readTime: '2 min',
      excerpt:
          'High in potassium, cooling. The drink for the first hour after you stop.',
      body: [
        'Coconut water carries potassium naturally; that is the second mineral you lose in sweat. On its own its sodium falls short, so a small pinch of salt joins in — the two work better together.',
        'The first hour after you stop is its moment. A cooling recovery after any session done in summer heat.',
      ],
      ingredients: [
        '250 ml coconut water',
        '250 ml water',
        '100 ml pineapple-orange juice',
        '1/8 teaspoon salt',
      ],
      steps: [
        'Combine the coconut water and water in a jug.',
        'Add the fruit juice.',
        'Add the salt and stir well.',
        'Serve cold over ice.',
      ],
    ),
  ),
  Article(
    id: 'salatalik-lime',
    order: 4,
    title: 'sıcak günler için salatalıklı lime içeceği',
    category: ArticleCategory.beslenme,
    readTime: '2 dk',
    excerpt:
        'Salatalık, lime, nane. Enerji değil, sıcakta kaybettiğini geri koymak için.',
    body: [
      'Salatalık neredeyse tamamen sudan oluşur ve yanında potasyum getirir; nane ise serinlik hissini yalnız ağızda değil bedende yaratır. Bu içeceğin işi enerji vermek değil, sıcakta kaybettiğini geri koymak.',
      'Bekletmek şart: yarım saatte tat suya geçer. Hemen içersen yalnızca tuzlu su içmiş olursun.',
    ],
    ingredients: [
      '500 ml su',
      '4 ince salatalık dilimi',
      '1 yemek kaşığı lime suyu',
      '1 tatlı kaşığı bal',
      '1 tutam tuz',
      'birkaç nane yaprağı',
    ],
    steps: [
      'Salatalık dilimlerini ve naneyi sürahiye koy, hafifçe ez.',
      'Balı az ılık suda çözdürüp ekle.',
      'Lime suyunu ve tuzu ekle.',
      'Kalan suyu doldur, buzdolabında en az yarım saat beklet.',
    ],
    diets: ['vejetaryen', 'glutensiz', 'laktozsuz'],
    en: ArticleTranslation(
      title: 'a cucumber lime cooler for hot days',
      readTime: '2 min',
      excerpt:
          'Cucumber, lime, mint. Not for fuel — for replacing what the heat took.',
      body: [
        'Cucumber is almost entirely water and brings potassium with it; the mint creates its coolness in your body, not just your mouth. This drink is not here to fuel you but to replace what the heat took.',
        'The waiting matters: half an hour is how long the flavour needs to move into the water. Drink it straight away and you have only had salty water.',
      ],
      ingredients: [
        '500 ml water',
        '4 thin cucumber slices',
        '1 tablespoon lime juice',
        '1 teaspoon honey',
        'a pinch of salt',
        'a few mint leaves',
      ],
      steps: [
        'Put the cucumber slices and mint in a jug and press them lightly.',
        'Dissolve the honey in a little warm water and add it.',
        'Add the lime juice and salt.',
        'Top up with the rest of the water and rest it in the fridge for at least half an hour.',
      ],
    ),
  ),
  Article(
    id: 'portakal-zencefil',
    order: 5,
    title: 'uzun mesafe koşuları için portakallı zencefil içeceği',
    category: ArticleCategory.beslenme,
    readTime: '2 dk',
    excerpt:
        'Portakal suyu enerjiyi, zencefil mideyi taşır. Saatler süren tempolarda.',
    body: [
      'Portakal suyu buraya hem karbonhidrat hem potasyum getiriyor; zencefil ise mide bulantısını yatıştırdığı için uzun eforlarda kendine yer buluyor. Saatler süren koşularda mide, bacaklardan önce pes eder — zencefil o riski düşürür.',
      'Antrenman boyunca on beş dakikada bir birkaç yudum. Sıcak günlerde buzlu, serin havada oda sıcaklığında iç; soğuk sıvı yorgun bir midede daha zor durur.',
    ],
    ingredients: [
      '300 ml portakal suyu',
      '300 ml su',
      '1 çay kaşığı rendelenmiş zencefil',
      '1 tutam tuz',
    ],
    steps: [
      'Zencefili rendele, üzerine az miktarda sıcak su dök ve beş dakika demlensin.',
      'Süzerek portakal suyuna ekle.',
      'Tuzu ve kalan suyu ekleyip karıştır.',
      'Soğutup şişeye al, antrenman boyunca azar azar iç.',
    ],
    diets: ['vegan', 'vejetaryen', 'glutensiz', 'laktozsuz'],
    en: ArticleTranslation(
      title: 'an orange ginger drink for long runs',
      readTime: '2 min',
      excerpt:
          'Orange juice carries the energy, ginger carries your stomach. For the hours-long efforts.',
      body: [
        'Orange juice brings both carbohydrate and potassium; ginger earns its place in long efforts because it settles nausea. On runs that last hours the stomach gives out before the legs do — ginger lowers that risk.',
        'A few sips every fifteen minutes. Iced on hot days, room temperature in cool weather; cold liquid is harder for a tired stomach to hold.',
      ],
      ingredients: [
        '300 ml orange juice',
        '300 ml water',
        '1 teaspoon grated ginger',
        'a pinch of salt',
      ],
      steps: [
        'Grate the ginger, pour a little hot water over it and let it steep for five minutes.',
        'Strain it into the orange juice.',
        'Add the salt and the rest of the water, then stir.',
        'Chill, bottle it, and sip through your session.',
      ],
    ),
  ),
  Article(
    id: 'karpuzlu-potasyum',
    order: 6,
    title: 'yaz antrenmanları için karpuzlu potasyum içeceği',
    category: ArticleCategory.beslenme,
    readTime: '2 dk',
    excerpt:
        'Karpuz, bal, bir tutam tuz. Sıcakta terleyerek kaybettiğinin karşılığı.',
    body: [
      'Karpuz neredeyse tamamen sudan oluşuyor ve yanında potasyumla sitrülin getiriyor — sitrülin kan akışını destekleyen bir amino asit, bu yüzden yaz antrenmanlarının sevilen meyvesi. Bal hızlı karbonhidratı, tuz ise terle giden sodyumu tamamlıyor.',
      'Antrenman sırasında da sonrasında da içilir. Sıcakta yapılan her seansta bu üçlü, sade sudan daha iyi iş görür.',
    ],
    ingredients: [
      '1 su bardağı karpuz',
      '300 ml soğuk su',
      '1 çay kaşığı bal',
      '1 tutam tuz',
    ],
    steps: [
      'Karpuzu blenderdan geçir.',
      'İnce süzgeçten süzerek posasını ayır.',
      'Balı, tuzu ve soğuk suyu ekleyip karıştır.',
      'Buzla servis et; en iyi ilk yarım saatte içilir.',
    ],
    diets: ['vejetaryen', 'glutensiz', 'laktozsuz'],
    en: ArticleTranslation(
      title: 'a watermelon potassium drink for summer training',
      readTime: '2 min',
      excerpt:
          'Watermelon, honey, a pinch of salt. The answer to what the heat takes.',
      body: [
        'Watermelon is almost entirely water and brings potassium and citrulline with it — citrulline is an amino acid that supports blood flow, which is why it is the beloved fruit of summer training. Honey covers the fast carbohydrate, salt the sodium you sweat out.',
        'Drink it during or after. In any session done in the heat, these three do better than plain water.',
      ],
      ingredients: [
        '1 cup watermelon',
        '300 ml cold water',
        '1 teaspoon honey',
        'a pinch of salt',
      ],
      steps: [
        'Blend the watermelon.',
        'Strain it through a fine sieve to remove the pulp.',
        'Add the honey, salt and cold water, then stir.',
        'Serve over ice; it is best within the first half hour.',
      ],
    ),
  ),
  Article(
    id: 'uzum-limon',
    order: 7,
    title: 'hızlı enerji için üzüm limon içeceği',
    category: ArticleCategory.beslenme,
    readTime: '2 dk',
    excerpt: 'Üzüm suyu, limon, tuz. Kana en çabuk karışan karbonhidrat.',
    body: [
      'Üzüm suyundaki glikoz, bedenin ek bir işlem yapmadan doğrudan kullanabildiği şeker türü — yani en hızlı ulaşan enerji. Limon hem tadı dengeliyor hem C vitamini taşıyor, tuz da suyu yerinde tutuyor.',
      'Tempo koşusu, bisiklet, uzun antrenmanların ortası. Enerjinin düştüğünü hissettiğin anda birkaç yudum; hepsini birden içmek kan şekerini önce yukarı, sonra sert biçimde aşağı taşır.',
    ],
    ingredients: [
      '200 ml üzüm suyu',
      '400 ml su',
      '1 yemek kaşığı limon suyu',
      '1 tutam tuz',
    ],
    steps: [
      'Üzüm suyunu ve suyu bir şişede birleştir.',
      'Limon suyunu ekle.',
      'Tuzu ekleyip iyice çalkala.',
      'Serin sakla, antrenmanın ortasında birkaç yudum al.',
    ],
    diets: ['vegan', 'vejetaryen', 'glutensiz', 'laktozsuz'],
    en: ArticleTranslation(
      title: 'a grape lemon drink for fast energy',
      readTime: '2 min',
      excerpt:
          'Grape juice, lemon, salt. The carbohydrate that reaches your blood soonest.',
      body: [
        'The glucose in grape juice is the kind of sugar your body can use without an extra step — the fastest energy there is. Lemon balances the taste and carries vitamin C; the salt keeps the water where it belongs.',
        'Tempo runs, cycling, the middle of long sessions. A few sips the moment you feel energy dip; drinking it all at once takes your blood sugar up and then sharply down.',
      ],
      ingredients: [
        '200 ml grape juice',
        '400 ml water',
        '1 tablespoon lemon juice',
        'a pinch of salt',
      ],
      steps: [
        'Combine the grape juice and water in a bottle.',
        'Add the lemon juice.',
        'Add the salt and shake well.',
        'Keep it cool and take a few sips mid-session.',
      ],
    ),
  ),
  Article(
    id: 'hurmali-kakao',
    order: 8,
    title: 'dayanıklılık için hurmalı kakao içeceği',
    category: ArticleCategory.beslenme,
    readTime: '2 dk',
    excerpt:
        'İki hurma, bir kaşık kakao, tuz. Doğal şeker ve magnezyum bir arada.',
    body: [
      'Hurma doğal şekerini lifle birlikte taşıdığı için enerjiyi daha dengeli bırakıyor; kakao ise magnezyum getiriyor, kaslarda kramp eşiğini yukarı çeken mineral o. İkisi bir arada, uzun seanslarda hem yakıt hem mineral demek.',
      'Antrenmandan yarım saat önce ya da uzun bir seansın ortasında. Kıvamı diğerlerinden yoğun — mide hassassa suyunu artır.',
    ],
    ingredients: [
      '2 çekirdeksiz hurma',
      '400 ml su',
      '1 çay kaşığı kakao',
      '1 tutam tuz',
    ],
    steps: [
      'Hurmaları on dakika sıcak suda beklet, yumuşasınlar.',
      'Suyuyla birlikte blenderdan geçir.',
      'Kakaoyu ve tuzu ekleyip tekrar çek.',
      'İstersen süzerek iç; soğuk servis daha iyi gider.',
    ],
    diets: ['vegan', 'vejetaryen', 'glutensiz', 'laktozsuz'],
    en: ArticleTranslation(
      title: 'a date and cocoa drink for endurance',
      readTime: '2 min',
      excerpt:
          'Two dates, a spoon of cocoa, salt. Natural sugar and magnesium together.',
      body: [
        'Dates carry their natural sugar alongside fibre, so the energy lands more evenly; cocoa brings magnesium, the mineral that raises your cramp threshold. Together they mean fuel and minerals in one glass for long sessions.',
        'Half an hour before training, or in the middle of a long session. It is thicker than the others — add water if your stomach is sensitive.',
      ],
      ingredients: [
        '2 pitted dates',
        '400 ml water',
        '1 teaspoon cocoa',
        'a pinch of salt',
      ],
      steps: [
        'Soak the dates in hot water for ten minutes until soft.',
        'Blend them together with their water.',
        'Add the cocoa and salt and blend again.',
        'Strain it if you like; it goes down better cold.',
      ],
    ),
  ),
  Article(
    id: 'yesil-cay-sporcu',
    order: 9,
    title: 'hafif kafein için yeşil çay içeceği',
    category: ArticleCategory.beslenme,
    readTime: '2 dk',
    excerpt:
        'Soğuk demlenmiş yeşil çay, bal, limon. Sert bir kafein değil, yumuşak bir uyanış.',
    body: [
      'Yeşil çayın kafeini kahveninkinden daha yumuşak iniyor; yanındaki L-teanin, kafeinin getirdiği tetikte olma hâlini gerginliğe çevirmeden dengeliyor. Katekinler ise antioksidan tarafı — egzersizin ürettiği serbest radikallere karşı çalışıyorlar.',
      'Sabah antrenmanlarından önce ya da öğleden sonraki seanslarda. Akşam saatlerinde içme; kafein uykuya kadar tam olarak çıkmaz.',
    ],
    ingredients: [
      '250 ml demlenmiş soğuk yeşil çay',
      '250 ml su',
      '1 tatlı kaşığı bal',
      '1 limon dilimi',
    ],
    steps: [
      'Yeşil çayı normalden kısa demle — uzun demleme acılık verir.',
      'Soğuduktan sonra suyla seyrelt.',
      'Balı az ılık suda çözdürüp ekle.',
      'Limon dilimini son anda at, buzla iç.',
    ],
    diets: ['vejetaryen', 'glutensiz', 'laktozsuz'],
    en: ArticleTranslation(
      title: 'a green tea drink for a light lift of caffeine',
      readTime: '2 min',
      excerpt:
          'Cold-brewed green tea, honey, lemon. Not a hard caffeine hit — a softer waking up.',
      body: [
        'Green tea\'s caffeine lands more gently than coffee\'s; the L-theanine alongside it balances the alertness without tipping it into jitters. The catechins are the antioxidant side, working against the free radicals exercise produces.',
        'Before morning sessions or for afternoon training. Not in the evening; caffeine does not fully clear before sleep.',
      ],
      ingredients: [
        '250 ml cold-brewed green tea',
        '250 ml water',
        '1 teaspoon honey',
        '1 lemon slice',
      ],
      steps: [
        'Brew the tea shorter than usual — long steeping turns it bitter.',
        'Once cool, dilute it with the water.',
        'Dissolve the honey in a little warm water and add it.',
        'Drop in the lemon slice at the last moment and drink over ice.',
      ],
    ),
  ),
  Article(
    id: 'cilekli-kefir',
    order: 10,
    title: 'ağırlık antrenmanı sonrası çilekli kefir içeceği',
    category: ArticleCategory.beslenme,
    readTime: '2 dk',
    excerpt: 'Çilek, kefir, bal. Protein ve karbonhidrat aynı bardakta.',
    body: [
      'Ağırlık çalışmasından sonra kasların iki şeye ihtiyacı olur: onarım için protein, boşalan depoyu doldurmak için karbonhidrat. Kefir proteini ve probiyotikleri, çilek karbonhidratı ve C vitaminini getiriyor — C vitamini bağ dokusunun onarımında doğrudan rol oynuyor.',
      'Bitişten sonraki ilk saat en verimli pencere. Kefiri çalkalamadan kullan, köpürünce kıvamı bozulur.',
    ],
    ingredients: ['150 g çilek', '200 ml kefir', '1 tatlı kaşığı bal'],
    steps: [
      'Çilekleri yıka ve saplarını ayır.',
      'Kefirle birlikte blenderdan kısa süre geçir — uzun çekmek kefiri sulandırır.',
      'Balı ekleyip bir kez daha karıştır.',
      'Hemen iç; beklerse ayrışır.',
    ],
    diets: ['vejetaryen', 'glutensiz'],
    allergens: ['sut_laktoz'],
    en: ArticleTranslation(
      title: 'a strawberry kefir drink for after lifting',
      readTime: '2 min',
      excerpt:
          'Strawberry, kefir, honey. Protein and carbohydrate in the same glass.',
      body: [
        'After lifting, muscles need two things: protein to repair, carbohydrate to refill what they emptied. Kefir brings the protein and the probiotics, strawberry the carbohydrate and vitamin C — and vitamin C plays a direct part in repairing connective tissue.',
        'The first hour after you stop is the most useful window. Use the kefir unshaken; frothed up, the texture goes.',
      ],
      ingredients: ['150 g strawberries', '200 ml kefir', '1 teaspoon honey'],
      steps: [
        'Wash the strawberries and remove the stems.',
        'Blend briefly with the kefir — long blending thins the kefir out.',
        'Add the honey and blend once more.',
        'Drink straight away; it separates if it waits.',
      ],
    ),
  ),
  Article(
    id: 'yaban-mersinli-antioksidan',
    order: 11,
    title: 'yoğun günler sonrası yaban mersinli içecek',
    category: ArticleCategory.beslenme,
    readTime: '2 dk',
    excerpt: 'Yaban mersini, su, bal. Sert seansın ardından gelen onarım.',
    body: [
      'Yaban mersininin koyu rengini veren antosiyaninler, yoğun egzersizin ürettiği oksidatif stresle savaşan bileşikler. Sert bir seansın ardından kaslarda biriken hasarın toparlanmasına destek olurlar — sporcuların vişne suyuna yönelmesinin sebebi de aynı aile.',
      'Antrenmandan sonra ya da ertesi gün kas ağrısıyla uyandığında. Donmuş yaban mersini de olur, hatta antosiyanin içeriği taze olandan düşük değildir.',
    ],
    ingredients: [
      'yarım su bardağı yaban mersini',
      '250 ml su',
      '1 tatlı kaşığı bal',
    ],
    steps: [
      'Yaban mersinini suyla blenderdan geçir.',
      'İstersen kabuklarını süzgeçle ayır — süzmezsen lifi de almış olursun.',
      'Balı ekleyip karıştır.',
      'Soğuk servis et.',
    ],
    diets: ['vejetaryen', 'glutensiz', 'laktozsuz'],
    en: ArticleTranslation(
      title: 'a blueberry drink for after the hard days',
      readTime: '2 min',
      excerpt:
          'Blueberries, water, honey. The repair that comes after a hard session.',
      body: [
        'The anthocyanins that give blueberries their deep colour are the compounds that fight the oxidative stress heavy exercise produces. After a hard session they support the recovery of the damage built up in your muscles — the same family of compounds is why athletes reach for tart cherry juice.',
        'After training, or the next morning when you wake up sore. Frozen blueberries work too; their anthocyanin content is no lower than fresh.',
      ],
      ingredients: [
        'half a cup of blueberries',
        '250 ml water',
        '1 teaspoon honey',
      ],
      steps: [
        'Blend the blueberries with the water.',
        'Strain out the skins if you like — leaving them in keeps the fibre.',
        'Add the honey and stir.',
        'Serve cold.',
      ],
    ),
  ),
  Article(
    id: 'muzlu-tarcinli-smoothie',
    order: 12,
    title: 'kas toparlanması için muzlu tarçınlı smoothie',
    category: ArticleCategory.beslenme,
    readTime: '2 dk',
    excerpt:
        'Muz, süt, tarçın. Boşalan glikojen deposunu dolduran en sade karışım.',
    body: [
      'Muz potasyumuyla tanınıyor ama buradaki asıl işi karbonhidrat: antrenmanda tükettiğin glikojeni yerine koyuyor. Süt proteini getiriyor, tarçın ise kan şekerinin daha dengeli seyretmesine yardım ediyor — tatlandırıcı değil, işlevsel bir ekleme.',
      'Bitişten sonraki ilk saatte iç. Muz ne kadar olgunsa şekeri o kadar erişilebilir; benekli olanları bunun için sakla.',
    ],
    ingredients: [
      '1 küçük muz',
      '200 ml süt ya da badem sütü',
      '1 çay kaşığı tarçın',
    ],
    steps: [
      'Muzu parçalara ayır.',
      'Sütle birlikte blenderdan geçir.',
      'Tarçını ekleyip bir kez daha çek.',
      'Hemen iç; beklerse koyulaşır.',
    ],
    diets: ['vejetaryen', 'glutensiz'],
    allergens: ['sut_laktoz', 'findik_kabuklu'],
    en: ArticleTranslation(
      title: 'a banana cinnamon smoothie for muscle recovery',
      readTime: '2 min',
      excerpt:
          'Banana, milk, cinnamon. The simplest mix for refilling an empty glycogen store.',
      body: [
        'Bananas are known for potassium, but their real job here is carbohydrate: replacing the glycogen you burned. Milk brings the protein, and cinnamon helps blood sugar run more evenly — a functional addition, not a sweetener.',
        'Drink it in the first hour after you stop. The riper the banana the more available its sugar; save the speckled ones for this.',
      ],
      ingredients: [
        '1 small banana',
        '200 ml milk or almond milk',
        '1 teaspoon cinnamon',
      ],
      steps: [
        'Break the banana into pieces.',
        'Blend it with the milk.',
        'Add the cinnamon and blend once more.',
        'Drink straight away; it thickens if it waits.',
      ],
    ),
  ),
  Article(
    id: 'espresso-tarcin',
    order: 13,
    title: 'antrenman öncesi için tarçınlı espresso',
    category: ArticleCategory.beslenme,
    readTime: '2 dk',
    excerpt: 'Tek shot espresso, su, tarçın. Başlamadan yirmi dakika önce.',
    body: [
      'Kafein, algılanan eforu düşürüyor: aynı ağırlık daha hafif, aynı tempo daha kolay hissettiriyor. Etkisi içtikten yaklaşık yirmi dakika sonra başlıyor, o yüzden zamanlaması tarifin kendisi kadar önemli. Tarçın ise keskin tadı yumuşatıyor.',
      'Sabah ve öğle seansları için. Akşam antrenmanlarında kullanma — kafein bedenden çıkana kadar uyku saatin gelir ve toparlanmanın en büyük parçasını kaybedersin.',
    ],
    ingredients: ['1 shot espresso', '100 ml su', '1 tutam tarçın'],
    steps: [
      'Espressoyu tazeleyin, sıcakken bardağa al.',
      'Tarçını ekleyip karıştır.',
      'Suyla seyrelt — sade espresso aç mideyi yorar.',
      'Antrenmandan yirmi dakika önce iç.',
    ],
    diets: ['vegan', 'vejetaryen', 'glutensiz', 'laktozsuz'],
    en: ArticleTranslation(
      title: 'a cinnamon espresso for before training',
      readTime: '2 min',
      excerpt:
          'One shot of espresso, water, cinnamon. Twenty minutes before you start.',
      body: [
        'Caffeine lowers perceived effort: the same weight feels lighter, the same pace easier. It starts working about twenty minutes after you drink it, which makes the timing as important as the recipe. The cinnamon softens the sharpness.',
        'For morning and midday sessions. Not for evening training — caffeine is still in you when bedtime arrives, and you lose the biggest part of recovery.',
      ],
      ingredients: [
        '1 shot of espresso',
        '100 ml water',
        'a pinch of cinnamon',
      ],
      steps: [
        'Pull the espresso fresh and pour it into a glass while hot.',
        'Add the cinnamon and stir.',
        'Dilute with the water — neat espresso is hard on an empty stomach.',
        'Drink it twenty minutes before training.',
      ],
    ),
  ),
  Article(
    id: 'kakaolu-enerji-shotu',
    order: 14,
    title: 'hafif enerji için kakaolu enerji shotu',
    category: ArticleCategory.beslenme,
    readTime: '2 dk',
    excerpt:
        'Kakao, süt, bal, bir tutam deniz tuzu. Küçük bardak, yeterli itki.',
    body: [
      'Kakaonun teobromini kafeine benzer ama daha yumuşak ve daha uzun süreli bir uyanıklık veriyor — kalp atışını hızlandırmadan. Yanında getirdiği magnezyum kas kasılmasında rol oynuyor, deniz tuzu da antrenman başlamadan sodyum deposunu dolduruyor.',
      'Küçük hacim kasten: antrenmandan hemen önce dolu bir mide istemezsin. Kahveye hassassan bu, espresso tarifinin yerine geçer.',
    ],
    ingredients: [
      '150 ml süt ya da yulaf sütü',
      '1 tatlı kaşığı şekersiz kakao',
      '1 çay kaşığı bal',
      'çok küçük bir tutam deniz tuzu',
    ],
    steps: [
      'Sütü hafifçe ısıt; kaynatma.',
      'Kakaoyu telle çırparak ekle, topaklanmasın.',
      'Ocaktan al, bal ve deniz tuzunu ekle.',
      'Küçük bir bardakta, antrenmandan on beş dakika önce iç.',
    ],
    diets: ['vejetaryen'],
    allergens: ['sut_laktoz', 'gluten'],
    en: ArticleTranslation(
      title: 'a cocoa energy shot for a light lift',
      readTime: '2 min',
      excerpt:
          'Cocoa, milk, honey, a pinch of sea salt. Small glass, enough push.',
      body: [
        'The theobromine in cocoa is caffeine\'s cousin, but it gives a softer and longer alertness — without pushing your heart rate. The magnesium it carries plays a part in muscle contraction, and the sea salt tops up sodium before you even start.',
        'The small volume is deliberate: you do not want a full stomach right before training. If you are sensitive to coffee, this replaces the espresso recipe.',
      ],
      ingredients: [
        '150 ml milk or oat milk',
        '1 teaspoon unsweetened cocoa',
        '1 teaspoon honey',
        'a very small pinch of sea salt',
      ],
      steps: [
        'Warm the milk gently; do not boil it.',
        'Whisk in the cocoa so it does not clump.',
        'Take it off the heat, add the honey and sea salt.',
        'Drink from a small glass fifteen minutes before training.',
      ],
    ),
  ),
];
