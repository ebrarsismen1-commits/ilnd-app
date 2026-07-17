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
    if (en != null) 'en': en!.toMap(),
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
    en: ArticleTranslation(
      title: 'legs up the wall',
      readTime: '4 min',
      excerpt:
          'Zero effort, five minutes. The pose that switches your nervous system into rest mode.',
      body: [
        'You have been on your feet, sitting, rushing all day. Your body has been stuck in the same mode for hours: keep going. Legs up the wall is the most effortless way to switch that mode off. You lie on your back, rest your legs against the wall, and let your arms fall to your sides. That is all.',
        'Staying like this for five minutes reverses circulation, and the fluid that gathered in your feet all day gently flows back. The real magic happens in your nervous system: this pose tells your body it is safe. Your heart rate slows and your breath deepens on its own.',
        'Try it: when you get home in the evening or before bed, put your phone far away, set a five minute timer and put your legs up the wall. Close your eyes. You do not have to do anything, because the whole point of this pose is doing nothing.',
        'It feels especially good during your period, after a long trip or on a heavy workout day. No tools, no skill required. All you need is a wall and five minutes.',
      ],
    ),
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
    en: ArticleTranslation(
      title: 'spoil your sleep',
      readTime: '5 min',
      excerpt:
          'Sleep is not a luxury, it is care itself. Start with small touches.',
      body: [
        'You do not need to change your life to improve your sleep. Adding a few small touches to your evening is enough. This approach has a new name, sleepmaxxing, but its essence is ancient: preparing for sleep the way you would prepare for a treasured guest.',
        'The three most effective steps are these. An hour before bed, turn off the big lights and switch to warm, dim lighting. Put the screen away early. Keep your room cool, because your body lowers its temperature as it drifts off, and a cool room makes that transition easier.',
        'If you want to go further, the options are ready: blackout curtains or a soft sleep mask, a cup of chamomile or lemon balm tea, a gentle stretch before bed. You will hear a lot about magnesium supplements too; asking your doctor or pharmacist first is the wise move.',
        'You do not have to do everything at once. Tonight, just dim the lights. Tomorrow, add a cup of tea. Sleep is a habit that gets lovelier the more you spoil it.',
      ],
    ),
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
    en: ArticleTranslation(
      title: 'woke up tired?',
      readTime: '4 min',
      excerpt:
          'If eight hours of sleep still leaves you tired, the answer may be on your plate.',
      body: [
        'If you feel heavy in the morning despite sleeping enough, it may be time to look at your plate. Your muscles and nerves need potassium to work properly, and a shortage shows up mostly as fatigue and sluggishness.',
        'The good news: potassium is not on the supplement shelf, it is at the market. Bananas are the famous one but far from the only option. Spinach, broccoli and sweet potatoes are among the richest sources. Kiwi and oranges carry both potassium and vitamin C. Avocado is the quiet champion of this list.',
        'Try it: sprinkle one potassium source into every day this week. Slice a banana into your morning oats. Add a handful of spinach to your lunch salad. Have a kiwi as a snack. It is an easy plan to follow, and you can feel the difference within days.',
        'One small note: if your tiredness is constant and unexplained, do not try to fix it with food alone. A simple blood test says a lot, so do not hesitate to talk to your doctor.',
      ],
    ),
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
    ingredients: [
      '3 orta boy havuç',
      'yarım limonun suyu',
      'küçük bir parmak taze zencefil',
    ],
    steps: [
      'Havuçları yıka ve uçlarını kes. Zencefilin kabuğunu bir kaşıkla sıyır.',
      'Katı meyve sıkacağın varsa havuç ve zencefili sırayla sık. Blender kullanıyorsan az suyla pürüzsüz olana kadar çek.',
      'Blender kullandıysan karışımı ince bir süzgeçten geçir.',
      'Limon suyunu ekle, karıştır ve buzla soğuk servis et.',
    ],
    en: ArticleTranslation(
      title: 'glow juice',
      readTime: '3 min',
      excerpt: 'Carrot, lemon, ginger. Skincare starts in the glass.',
      body: [
        'Skincare does not only happen in cream jars, it starts in the glass too. This three ingredient drink is the simple version of the glow skin juice you see on every board. Carrot brings beta carotene, lemon brings vitamin C, and ginger brings its wake-up sharpness.',
        'The recipe: 3 medium carrots, juice of half a lemon and a thumb of fresh ginger. If you have a juicer, run everything through it. A blender works too: blend the carrot and ginger with a little water, strain through a fine sieve, add the lemon at the end.',
        'The best time is morning, right before breakfast. It also works wonders during the afternoon energy dip. Serve it cold; over ice it drinks almost like lemonade.',
        'A small reality note: no drink changes your skin on its own. But added to the trio of regular vegetables, enough water and good sleep, this glass becomes the shining part of the total.',
      ],
      ingredients: [
        '3 medium carrots',
        'juice of half a lemon',
        'a thumb of fresh ginger',
      ],
      steps: [
        'Wash the carrots and trim the ends. Scrape the ginger skin off with a spoon.',
        'If you have a juicer, run the carrot and ginger through it. If you are using a blender, blend with a little water until smooth.',
        'If you used a blender, strain the mixture through a fine sieve.',
        'Add the lemon juice, stir, and serve cold over ice.',
      ],
    ),
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
    ingredients: [
      '1 çay kaşığı matcha',
      '60 ml sıcak su (70 ila 80 derece)',
      'istersen: 200 ml yulaf sütü',
    ],
    steps: [
      'Suyu ısıt ama kaynatma. 70 ila 80 derece idealdir; daha sıcağı matchayı acılaştırır.',
      'Matchayı kaseye koy, sıcak suyu üzerine yavaşça dök.',
      'Çırpıcıyla W çizerek, yüzeyde ince bir köpük oluşana kadar çırp.',
      'Sade iç ya da köpürttüğün yulaf sütünü üzerine ekleyip latte yap.',
    ],
    en: ArticleTranslation(
      title: 'the matcha ritual',
      readTime: '4 min',
      excerpt:
          'More than a drink: two minutes of slowing down in the middle of the day.',
      body: [
        'What makes matcha special is not only what is in it, but how it is made. A coffee machine works at the push of a button; matcha asks you for two minutes. The powder is measured, the water is warmed, the whisk moves. This little ceremony creates a mandatory, sweet moment of slowness in the middle of your day.',
        'The contents are strong too. The L-theanine in matcha softens the effect of caffeine. Instead of coffee\'s sharp rise and crash, it gives a calm focus spread over hours. This is the drink of feeling awake without feeling tense.',
        'The recipe: 1 teaspoon of matcha and 60 ml of hot water. Not boiling; 70 to 80 degrees is ideal, hotter makes the powder bitter. Whisk in a W motion until a foam forms. Drink it straight, or pour frothed oat milk over it for a latte.',
        'A tip: if the first sip tastes grassy, use less and start with half a teaspoon. Matcha is not a taste you are used to, it is a taste you grow to love. Just like slowing down.',
      ],
      ingredients: [
        '1 teaspoon of matcha',
        '60 ml hot water (70 to 80 degrees)',
        'optional: 200 ml oat milk',
      ],
      steps: [
        'Heat the water but do not boil it. 70 to 80 degrees is ideal; hotter turns the matcha bitter.',
        'Put the matcha in a bowl and slowly pour the hot water over it.',
        'Whisk in a W motion until a fine foam forms on the surface.',
        'Drink it straight, or pour frothed oat milk on top for a latte.',
      ],
    ),
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
    en: ArticleTranslation(
      title: 'moving with attention',
      readTime: '4 min',
      excerpt:
          'The point is not moving a lot, it is being there while you move.',
      body: [
        'A lovely idea is circulating in the wellness world: instead of tiring your body fast, give real attention to the movement you are doing. Walking with a podcast is nice, of course. But sometimes walking while actually feeling your steps gives you something entirely different.',
        'Science backs this up. Movement done with attention reduces stress more than the same exercise done absent-mindedly. Because the mind stops poking at the future and returns to the body. Calling it meditation in motion is no exaggeration.',
        'Try it: give yourself a ten minute movement break today. No headphones, no screen. Roll your shoulders back, stretch your neck to each side, let your hands float upward. In every stretch, watch where your breath goes.',
        'The best part of this approach is that it lowers the bar. You do not have to go to a gym; walking from room to room with attention counts. Your body does not want to be transported, it wants to be noticed.',
      ],
    ),
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
    en: ArticleTranslation(
      title: 'kindness on period days',
      readTime: '5 min',
      excerpt:
          'On those days your body asks for a different tempo. Listen to it.',
      body: [
        'Feeling tired, bloated or sensitive during your period is not weakness, it is biology. Stress hormones rise more easily on those days, and your body asks for gentle movement instead of high tempo workouts. Giving it that is not laziness, it is a smart adjustment.',
        'So what helps? Restorative yoga or soft stretching. Very light movements with deep breathing. Forward folds where you simply let go. A short, slow walk. And of course legs up the wall; it works wonders for cramps and bloating.',
        'Dry brushing is another favourite of these days. Before your shower, sweep the brush in long, light strokes from your feet toward your heart. It wakes up circulation and lifts that heavy feeling. No hard pressing needed, a silky touch is enough.',
        'Most importantly, take the measure from yourself. Whatever you can carry today, that much. Adapting to your cycle instead of fighting it leaves you more balanced through the whole month.',
      ],
    ),
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
    en: ArticleTranslation(
      title: 'your nervous system sets the tone',
      readTime: '5 min',
      excerpt:
          'The signals you send in the first half hour of the morning spread across the whole day.',
      body: [
        'The day is the same day. But on some days everything piles on top of you, and on others the same load feels light. The difference is usually not in the events, but in which mode your nervous system is in. On alert, or at ease?',
        'Your nervous system collects signals from your surroundings all day and sets its tone accordingly. Checking the news and notifications the second you open your eyes sends it a danger signal. Looking at daylight, taking a slow breath, a warm shower says you are safe.',
        'Here is a practical morning trio: when you wake up, go to the window first and look at the daylight for two minutes. Then three slow breaths; make the exhale longer than the inhale. Then a glass of water. The phone comes after these. The news will keep, and you will gain.',
        'You can also correct the tone during the day. If your shoulders have crept toward your ears, breathe out long, soften your jaw, plant your feet on the floor. Your nervous system does not want grand gestures; it softens with small, repeated signals of safety.',
      ],
    ),
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
    en: ArticleTranslation(
      title: 'neuroaesthetics: beauty does you good',
      readTime: '5 min',
      excerpt:
          'Your brain is shaped by what it looks at. Arrange your space accordingly.',
      body: [
        'Why do some places open us up while others close us in? Neuroaesthetics studies exactly this: what beauty does inside the brain. And the findings are clear. What we look at changes what we feel. Soft light, natural textures and order measurably lower the stress response.',
        'You do not need to renovate your home for this. The brain responds most to three things: light, order and nature. A corner that gets daylight, a cleared desk and a pot of green together create a small sanctuary.',
        'Try it: look at the corner where you spend the most time. What are the first three things that catch your eye? If it is a pile of cables and paper, even a five minute tidy-up changes what that corner gives you. Then add a plant or a single object you love. More would be noise.',
        'Beauty is not a luxury, it is a regulator. Building yourself a beautiful corner is not idle aesthetics; it is a quiet form of care that sends your nervous system a hundred good signals a day.',
      ],
    ),
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
    en: ArticleTranslation(
      title: 'not routine, ritual',
      readTime: '4 min',
      excerpt:
          'Same act, two different feelings. What makes the difference is intention.',
      body: [
        'Routine and ritual look the same from the outside: acts repeated every day. But routine is done to finish, ritual is done to live. If your mind is in a meeting while you brush your teeth, that is a routine. If you hear the water and you are actually there, the same act has become a ritual.',
        'The phrase romanticize your life is really about this. Not adding new things, but doing the existing ones with care. Pouring your coffee into your favourite cup, drinking your evening tea by the window, not rushing while applying cream. Small acts of care make an ordinary moment precious.',
        'There is a practical payoff too: rituals last. Habits sustained by force end when willpower runs out. Rituals that bring joy carry themselves. The secret of consistency is not discipline, it is love.',
        'Try it: pick one thing you already do today and turn it into a ritual. Slower, more beautiful, more yours. Life is woven not from grand moments but from small ones lived with care.',
      ],
    ),
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
    en: ArticleTranslation(
      title: 'the weekly reset',
      readTime: '5 min',
      excerpt: 'One hour on Sunday evening: start the week ready, not tired.',
      body: [
        'The heaviness of Monday mornings rarely comes from Monday. It comes from starting a new week on top of an unclosed one. That is exactly why the weekly reset exists: a small one hour ceremony, once a week, to close what ended and gently greet what comes.',
        'A simple flow could look like this. First tidy the environment; desk, bag, even the phone gallery. Then empty the mind: pour the unfinished, the circling and the postponed into a single list. A thought that lands on paper does not wake you at three in the morning.',
        'Then look at the week kindly. Pick three important things from the calendar and promise yourself only those. Cramming twenty goals into seven days is not a reset, it is preparing a new exhaustion. Few promises, fully kept: that is the balance.',
        'Make the closing beautiful. A shower, a tea you love, an early night. The point of the reset is not planning a perfect week, but gifting yourself a soft beginning, regularly.',
      ],
    ),
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
    en: ArticleTranslation(
      title: 'the science of gratitude',
      readTime: '4 min',
      excerpt:
          'Saying thanks is not sentimentality; it is an exercise that reshapes your brain.',
      body: [
        'A gratitude practice can sound too soft, but neuroscience disagrees. Regularly noticing good things strengthens the brain\'s reward and bonding circuits. Research sees this as a drop in stress hormones and a measurable lift in mood.',
        'The mechanism is simple: your brain grows whatever you focus on. If you scan for what is missing all day, you become an expert at finding lack. When you start scanning for what is good, the same skill starts working in your favour.',
        'The practice is just as simple. In the evening, before sleep, pick three good things from your day and write them down. They do not need to be big; a warm shower, a kind message, light falling through the window. What matters is re-feeling that moment for one second as you recall it.',
        'Try it for two weeks straight. What changes will not be your life, but the eyes looking at it. And those eyes set the tone of your day more than you think.',
      ],
    ),
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
    en: ArticleTranslation(
      title: 'make peace with your body clock',
      readTime: '5 min',
      excerpt:
          'The secret of sleep is not hidden in the night, but in the first light of morning.',
      body: [
        'There is a clock inside you that runs without any effort on your part. This inner clock, the circadian rhythm, sets when you wake, when you get hungry and when sleep arrives. Many sleep problems are really the clock and the life drifting apart.',
        'The strongest signal that sets the clock is light. The daylight you see in the first hour of the morning tells your inner clock the day has begun, and makes it easier for melatonin to release right on time at night. In other words, sleeping well at night actually starts with walking to the window in the morning.',
        'Try it: see at least five minutes of daylight within an hour of waking. Balcony, window or a short walk, it does not matter. In the evening, do the opposite; dim the lights and cut the bright screens. Two clear signals for your clock: day is day, night is night.',
        'Then there is consistency. Going to bed and waking at roughly the same time, weekend included, keeps your clock steady. Whoever fights the body clock loses; whoever makes peace with it wakes up without resenting the alarm.',
      ],
    ),
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
    ingredients: [
      'bir avuç yeşillik (roka, ıspanak ya da marul)',
      'yarım su bardağı haşlanmış bulgur ya da kinoa',
      'bir protein: nohut, yumurta ya da balık',
      'zeytinyağı ya da çeyrek avokado',
      'limon ve tuz',
    ],
    steps: [
      'Tahılını haşla; hazırda varsa hafifçe ısıt.',
      'Kaseye önce yeşillikleri, üzerine tahılı yerleştir.',
      'Proteinini hazırla: nohutu tavada birkaç dakika kızart, yumurtayı haşla ya da balığını pişir ve kaseye ekle.',
      'Zeytinyağı ve limonla tatlandır, tuzu serp. Ekrandan uzakta, yavaş ye.',
    ],
    en: ArticleTranslation(
      title: 'food is medicine',
      readTime: '5 min',
      excerpt:
          'Holistic nutrition is not complicated: look at your plate as a whole.',
      body: [
        'Holistic nutrition is the opposite of calorie counting and forbidden lists. The question is: what does this thing I am eating do to my body, my mind and my energy as a whole? Food is not just fuel; it is information that rewrites your mood, sleep and focus every day.',
        'In practice it comes down to three principles. One: whole foods as much as possible; the shorter the ingredient list on the package, the happier the body. Two: colour variety; every colour on the plate is a different family of nutrients. Three: eating slowly; digestion starts with chewing, not with rushing in front of a screen.',
        'An easy starter bowl: a handful of greens, one grain (bulgur or quinoa), one protein (chickpeas, egg or fish), one healthy fat (olive oil or avocado) and lemon on top. Five components, ten minutes, a complete meal.',
        'Make a habit of asking yourself: how do I feel an hour after this meal? As the answers accumulate, you build your own nutrition compass without needing anyone\'s list.',
      ],
      ingredients: [
        'a handful of greens (arugula, spinach or lettuce)',
        'half a cup of cooked bulgur or quinoa',
        'one protein: chickpeas, egg or fish',
        'olive oil or a quarter avocado',
        'lemon and salt',
      ],
      steps: [
        'Cook your grain; if you have some ready, warm it gently.',
        'Layer the bowl: greens first, grain on top.',
        'Prepare your protein: pan-toast the chickpeas for a few minutes, boil the egg or cook your fish, and add it to the bowl.',
        'Dress with olive oil and lemon, sprinkle the salt. Eat slowly, away from screens.',
      ],
    ),
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
    en: ArticleTranslation(
      title: 'less is more: minimalist care',
      readTime: '4 min',
      excerpt: 'Wellness is not a to-do list. Reduce, and go deeper.',
      body: [
        'At some point even taking care of yourself can turn into an exhausting list: a ten step skincare routine, five supplements, three apps, two rituals. Minimalist wellness asks a simple question against all this: which of these actually does me good?',
        'The rule is simple. Few things, done fully, feel better than many things done halfway. One real ten minute pause a day gives more than five so-called rituals rushed through.',
        'Try it: take stock of your own care this week. Write down everything you do and ask each one a single question: do I actually feel better after this, or am I just crossing it off a list? Whatever falls into the second group, let it go with a clear conscience.',
        'Protect and deepen the few things that remain. Simplicity is not a lack; it is knowing yourself well enough to know what works.',
      ],
    ),
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
    en: ArticleTranslation(
      title: 'small steps, big difference',
      readTime: '4 min',
      excerpt: 'Life does not change overnight. It changes one percent a day.',
      body: [
        'Big change decisions are exciting: from tomorrow I will run every morning, I am quitting sugar completely, I will finish a book every day. And most of them are quietly shelved by the third evening. The problem is not you, it is the size of the step.',
        'The power of small steps comes from math. One percent better every day compounds enormously by the end of a year. But the real magic is psychological: a small step needs no willpower, produces no excuses, and sends your brain a little signal of success every time it is completed.',
        'Keep the measure ridiculously small. If you want to read, make the goal one page. If you want movement, a five minute walk. If you forget to drink water, one glass in the morning. Most days the rest follows by itself; and on the days it does not, the goal was met anyway.',
        'A month later, looking back, you will not see a glorious transformation. You will see a few good habits that settled in quietly and now happen without thinking. That is what lasting change looks like.',
      ],
    ),
  ),
  Article(
    id: '',
    order: 16,
    title: 'gece sütü',
    category: ArticleCategory.tarif,
    readTime: '3 dk',
    excerpt: 'Uykudan önce sıcak bir fincan sakinlik. Beş dakikada hazır.',
    imageUrl: '$_u-1669219695489-9163d12a2611?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Gece sütü, panolarda moon milk adıyla dolaşan akşam içeceğinin sade hâli. Sıcak süt zaten kendi başına bir uyku sinyalidir; tarçın ve bal eklenince ortaya yatmadan önce içilen küçük bir ritüel çıkar.',
      'Asıl işi içindekiler kadar zamanlaması yapar. Uyumadan yarım saat önce, ışıkları kısmışken, telefonsuz içilen sıcak bir fincan bedenine günün bittiğini söyler. Tarif bahane, yavaşlamak asıl.',
    ],
    ingredients: [
      '1 su bardağı süt ya da badem sütü',
      'yarım çay kaşığı tarçın',
      'çeyrek çay kaşığı zerdeçal (istersen)',
      '1 çay kaşığı bal',
    ],
    steps: [
      'Sütü küçük bir tencerede kısık ateşte ısıt; kaynatma, buhar tütmeye başlaması yeterli.',
      'Tarçını ve istersen zerdeçalı ekleyip telle karıştır.',
      'Ocaktan al, bir dakika soğumasını bekle ve balı ekle. Bal kaynar süte girmesin; aroması kaybolur.',
      'Sevdiğin fincana koy, ışıkları kıs ve yavaş yudumlarla iç.',
    ],
    en: ArticleTranslation(
      title: 'moon milk',
      readTime: '3 min',
      excerpt: 'A warm cup of calm before sleep. Ready in five minutes.',
      body: [
        'Moon milk is the simple version of the evening drink drifting through the boards. Warm milk is a sleep signal all by itself; add cinnamon and honey and you get a little ritual to drink before bed.',
        'Its timing does as much work as its ingredients. A warm cup, half an hour before sleep, lights dimmed, phone away, tells your body the day is over. The recipe is the excuse; slowing down is the point.',
      ],
      ingredients: [
        '1 cup of milk or almond milk',
        'half a teaspoon of cinnamon',
        'a quarter teaspoon of turmeric (optional)',
        '1 teaspoon of honey',
      ],
      steps: [
        'Warm the milk in a small pot over low heat; do not boil, gentle steam is enough.',
        'Add the cinnamon and, if you like, the turmeric, and stir with a whisk.',
        'Take it off the heat, wait a minute and add the honey. Honey should not hit boiling milk; the aroma fades.',
        'Pour into your favourite cup, dim the lights and sip slowly.',
      ],
    ),
  ),
  Article(
    id: '',
    order: 17,
    title: 'yeşil glow smoothie',
    category: ArticleCategory.tarif,
    readTime: '3 dk',
    excerpt: 'Panolardaki o yeşil bardak. Tadı göründüğünden çok daha iyi.',
    imageUrl: '$_u-1610622930110-3c076902312a?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Elinde yeşil bir bardakla güne başlayan o insanlar bir şey biliyor: bu karışım hem doyuruyor hem de sabaha temiz bir başlangıç hissi veriyor. Ispanağın tadı muzun arkasında tamamen kaybolur; içtiğin şey tatlı ve kremamsı bir kahvaltıdır.',
      'Avokado bu tarifin sessiz kahramanı. Kıvamı ipeksi yapar ve sağlıklı yağıyla seni öğlene kadar tok tutar. Muzun dondurulmuş olması ise smoothieyi milkshake kıvamına taşır.',
    ],
    ingredients: [
      '1 muz (dondurulmuş olursa daha iyi)',
      'bir avuç taze ıspanak',
      'çeyrek avokado',
      '1 su bardağı yulaf sütü',
      'istersen: 1 çay kaşığı bal',
    ],
    steps: [
      'Tüm malzemeleri blendera koy; önce sıvıyı, sonra yeşillikleri, en üste muzu.',
      'Pürüzsüz ve akışkan olana kadar çek. Çok koyuysa biraz daha süt ekle.',
      'Tadına bak; tatlılık istersen balı şimdi ekleyip bir tur daha çek.',
      'Uzun bir bardağa koy ve bekletmeden iç; yeşil karışımlar taze içildiğinde en iyisidir.',
    ],
    en: ArticleTranslation(
      title: 'green glow smoothie',
      readTime: '3 min',
      excerpt:
          'That green glass from the boards. Tastes far better than it looks.',
      body: [
        'The people starting their day with a green glass know something: this blend fills you up and gives the morning a clean-start feeling. The spinach disappears completely behind the banana; what you are drinking is a sweet, creamy breakfast.',
        'Avocado is the quiet hero of this recipe. It makes the texture silky and its healthy fat keeps you full until noon. A frozen banana takes the smoothie all the way to milkshake territory.',
      ],
      ingredients: [
        '1 banana (frozen is even better)',
        'a handful of fresh spinach',
        'a quarter avocado',
        '1 cup of oat milk',
        'optional: 1 teaspoon of honey',
      ],
      steps: [
        'Add everything to the blender; liquid first, then the greens, banana on top.',
        'Blend until smooth and pourable. If it is too thick, add a little more milk.',
        'Taste it; if you want sweetness, add the honey now and blend once more.',
        'Pour into a tall glass and drink right away; green blends are at their best fresh.',
      ],
    ),
  ),
  Article(
    id: '',
    order: 18,
    title: 'hurma lokmaları',
    category: ArticleCategory.tarif,
    readTime: '4 dk',
    excerpt: 'Tatlı krizine şefkatli cevap: üç malzeme, sıfır fırın.',
    imageUrl: '$_u-1596723455658-72ebb0d12edd?auto=format&fit=crop&w=1200&q=80',
    body: [
      'Akşam tatlı krizi geldiğinde iki yol var: dolaptaki hazır tatlıya uzanmak ya da beş dakikada kendi lokmalarını yuvarlamak. Bu tarif ikinci yolu o kadar kolaylaştırıyor ki birincisine gerek kalmıyor.',
      'Hurma doğal şekeriyle tatlı ihtiyacını karşılar, fıstık ezmesi ve yulaf ise kan şekerini dengede tutar. Yani bu lokmalar hem tatlı hem tok tutan cinsten; bir kavanoza dizip buzdolabında hafta boyu saklayabilirsin.',
    ],
    ingredients: [
      '10 yumuşak hurma (çekirdeksiz)',
      '2 yemek kaşığı fıstık ezmesi',
      'yarım su bardağı yulaf',
      'üzeri için: kakao ya da hindistan cevizi',
    ],
    steps: [
      'Hurmaları mutfak robotunda macun kıvamına gelene kadar çek. Robot yoksa ince kıyıp çatalla ez.',
      'Fıstık ezmesi ve yulafı ekleyip karışım top olacak kıvama gelene kadar tekrar çek.',
      'Karışımdan ceviz büyüklüğünde parçalar al ve avucunda yuvarla.',
      'Topları kakao ya da hindistan cevizinde gezdir. Buzdolabında yarım saat dinlendir; kavanozda bir hafta dayanır.',
    ],
    en: ArticleTranslation(
      title: 'date bites',
      readTime: '4 min',
      excerpt:
          'A kind answer to the sweet craving: three ingredients, zero oven.',
      body: [
        'When the evening sweet craving hits, there are two roads: reaching for the packaged dessert in the cupboard, or rolling your own bites in five minutes. This recipe makes the second road so easy that the first becomes unnecessary.',
        'Dates cover the sweetness with their natural sugar, while peanut butter and oats keep your blood sugar steady. So these bites are both sweet and filling; line them up in a jar and they will keep in the fridge all week.',
      ],
      ingredients: [
        '10 soft dates (pitted)',
        '2 tablespoons of peanut butter',
        'half a cup of oats',
        'for coating: cocoa or shredded coconut',
      ],
      steps: [
        'Blitz the dates in a food processor until they turn into a paste. No processor? Chop finely and mash with a fork.',
        'Add the peanut butter and oats and blitz again until the mixture holds together.',
        'Take walnut-sized pieces and roll them in your palm.',
        'Roll the balls in cocoa or coconut. Rest in the fridge for half an hour; they keep a week in a jar.',
      ],
    ),
  ),
];
