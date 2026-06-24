// Keşfet içeriğinin veri modeli.
//
// Şimdilik kodda sabit; Supabase açılınca `articles` tablosundan okunacak
// (aynı alanlar). Diyetisyen ortağın buraya içerik girer.

enum ArticleCategory { wellness, tarif, yazi }

extension ArticleCategoryX on ArticleCategory {
  /// Kart üstünde görünen küçük etiket.
  String get tag => switch (this) {
        ArticleCategory.wellness => 'wellness',
        ArticleCategory.tarif => 'tarif',
        ArticleCategory.yazi => 'yazı',
      };

  /// Editoryal arka plan paleti (görsel yoksa / yüklenmezse).
  int get palette => switch (this) {
        ArticleCategory.wellness => 0,
        ArticleCategory.tarif => 1,
        ArticleCategory.yazi => 3,
      };
}

class Article {
  const Article({
    required this.title,
    required this.category,
    required this.readTime,
    required this.excerpt,
    required this.body,
    this.imageUrl,
  });

  final String title;
  final ArticleCategory category;
  final String readTime;
  final String excerpt;

  /// Yazının gövdesi — her eleman bir paragraf.
  final List<String> body;

  /// Kapak fotoğrafı (web). Boşsa veya yüklenemezse editoryal degrade kullanılır.
  final String? imageUrl;
}

const _img =
    'https://images.unsplash.com/photo'; // ortak önek; her birine farklı id

const kArticles = <Article>[
  Article(
    title: 'nefes & sakinlik',
    category: ArticleCategory.wellness,
    readTime: '4 dk',
    excerpt: 'Zihnini yavaşlatmanın en hızlı yolu, en yavaş şeyden geçer: nefes.',
    imageUrl: '$_img-1506126613408-eca07ce68773?auto=format&fit=crop&w=900&q=70',
    body: [
      'Gün içinde fark etmeden tuttuğumuz nefes, aslında zihnimizin en sadık aynasıdır. Stresliyken sığ ve hızlı, sakinken derin ve yavaş nefes alırız. İyi haber şu: bu ilişki çift yönlü. Yani nefesini bilinçli olarak yavaşlatırsan, zihnin de onu takip eder.',
      'Bugün denemen için basit bir ritüel: dört saniye burnundan al, dört saniye tut, altı saniye ağzından yavaşça ver. Bunu sadece üç kez tekrarla. Vermeyi almaktan uzun tutmak, bedenine "güvendesin" mesajını gönderir.',
      'Sabah uyanınca, bir toplantı öncesi ya da gece yatmadan… Günde tek bir dakika bile bedeninle aranı yeniden kurmaya yeter. Mükemmel olmak zorunda değilsin; sadece bir nefes, sonra bir tane daha.',
    ],
  ),
  Article(
    title: 'yeşil smoothie',
    category: ArticleCategory.tarif,
    readTime: '2 dk',
    excerpt: 'Sabaha hafif ve canlı başlamanın en pratik yolu.',
    imageUrl: '$_img-1610970881699-44a5587cabec?auto=format&fit=crop&w=900&q=70',
    body: [
      'Bu smoothie ağır değil, seni şişirmiyor; aksine güne hafif ve berrak bir zihinle başlatıyor. Hazırlaması tam üç dakika.',
      'Malzemeler: 1 avuç ıspanak, yarım muz, yarım yeşil elma, 1 yemek kaşığı chia, 1 su bardağı bitkisel süt, biraz buz. Hepsini blenderdan geçir, bu kadar.',
      'İpucu: kıvamı sevdiysen yarım avokado ekle — daha kremamsı ve tok tutan bir doku verir. Şeker eklemene gerek yok, elma ve muz yeterli tatlılığı taşıyor.',
    ],
  ),
  Article(
    title: 'dijital detoks',
    category: ArticleCategory.yazi,
    readTime: '6 dk',
    excerpt: 'Telefonu bırakmak değil mesele; dikkatini geri almak.',
    imageUrl: '$_img-1499750310107-5fef28a66643?auto=format&fit=crop&w=900&q=70',
    body: [
      'Dijital detoks denince akla telefonu bir kenara fırlatmak gelir. Ama mesele cihazı suçlamak değil; dikkatinin nereye aktığını fark etmek. Ekran kötü değil, dikkatin dağınık olması yorucu.',
      'Küçük bir deney yap: uyandıktan sonraki ilk 30 dakika telefona bakma. Onun yerine pencereden dışarı bak, su iç, bir esneme yap. Günün ilk düşüncesi bir bildirim değil, kendi düşüncen olsun.',
      'Akşam da benzer bir sınır koy: yatmadan bir saat önce ekranlar kapanır. İlk birkaç gün zor gelebilir, çünkü beynin o küçük dopamin dürtüsüne alışmış. Ama bir hafta sonra uykunun derinleştiğini fark edeceksin.',
      'Amaç tamamen kopmak değil. Amaç, teknolojiyle ilişkini sen seçesin diye küçük aralıklar açmak.',
    ],
  ),
  Article(
    title: 'protein kasesi',
    category: ArticleCategory.tarif,
    readTime: '3 dk',
    excerpt: 'Öğle için dengeli, doyurucu ve hazırlaması kolay.',
    imageUrl: '$_img-1512621776951-a57141f2eefd?auto=format&fit=crop&w=900&q=70',
    body: [
      'Öğlen çökmesini yaşamak istemiyorsan, tabağında protein, lif ve sağlıklı yağ bir arada olmalı. Bu kase tam olarak bunu yapıyor.',
      'Tabanı bir kâse kinoa ya da bulgur. Üzerine nohut, ızgara tavuk ya da haşlanmış yumurta; bol yeşillik, avokado, kiraz domates. Üstüne biraz zeytinyağı ve limon.',
      'Bu kombinasyon kan şekerini dengede tutar, seni öğleden sonraya enerjik taşır. Hazırlaması beş dakika, ama etkisi tüm öğleden sonranı belirliyor.',
    ],
  ),
  Article(
    title: 'sabah ritüeli',
    category: ArticleCategory.wellness,
    readTime: '5 dk',
    excerpt: 'Güne nasıl başladığın, günün geri kalanını belirler.',
    imageUrl: '$_img-1495214783159-3503fd1b572d?auto=format&fit=crop&w=900&q=70',
    body: [
      'Sabahları telaşla başlamak, tüm güne o telaşı taşımak demektir. Oysa ilk yarım saatini kendine ayırmak, günün tonunu tamamen değiştirir.',
      'Karmaşık bir program gerekmiyor. Bir bardak su, birkaç dakika sessizlik, bugünün niyetini belirlemek. Belki kısa bir esneme, belki sadece pencere kenarında bir fincan kahve.',
      'Ritüel demek tekrar demek. Aynı küçük şeyleri her sabah yapmak, beynine "gün benim kontrolümde başlıyor" der. Ve bu his, dışarıdaki kaos ne olursa olsun seninle kalır.',
    ],
  ),
  Article(
    title: 'sınır koymak',
    category: ArticleCategory.yazi,
    readTime: '7 dk',
    excerpt: '"Hayır" demek, ilişkilerini değil; enerjini korur.',
    imageUrl: '$_img-1518609878373-06d740f60d8b?auto=format&fit=crop&w=900&q=70',
    body: [
      'Çoğumuz "hayır" demeyi öğrenmedik. Onaylanmak, sevilmek, çatışmadan kaçınmak isteriz. Ama her "evet", aslında başka bir şeye söylenmiş sessiz bir "hayır"dır — çoğu zaman kendine.',
      'Sınır koymak bencillik değil. Tam tersine, ilişkilerini daha dürüst kılar. İnsanlar gerçekten ne istediğini bildiğinde, seninle daha net bir bağ kurar.',
      'Küçük başla. Bu hafta sadece bir kez, normalde otomatik "evet" diyeceğin bir şeye "şu an müsait değilim" de. Suçluluk hissetmen normal; bu, eski bir alışkanlığın direnci. Geçer.',
      'Unutma: kendine alan açmak, başkalarına sırtını dönmek değil. Sadece, dolu bir bardaktan başkasına su verebileceğini hatırlamak.',
    ],
  ),
];
