import 'dart:math';

/// ILND karakterine uygun, önceden hazırlanmış yedek cevaplar.
///
/// Canlı AI çalışmadığında (anahtar yok, internet yok, limit) demonun akıcı
/// kalması için kullanılır — hata balonu yerine sıcak, inandırıcı bir ILND
/// cümlesi. Her havuzdan rastgele seçilir ki tekrar etmiş gibi durmasın.
class IlndFallbacks {
  IlndFallbacks._();

  static final _rng = Random();

  static String _pick(List<String> pool) => pool[_rng.nextInt(pool.length)];

  /// Genel sohbet karşılığı.
  static String chat() => _pick(const [
        'seni dinliyorum. biraz daha anlatmak ister misin?',
        'bunu paylaşman güzel. şu an bedeninde bunu nerede hissediyorsun?',
        'buradayım. bugün sana en çok dokunan şey neydi?',
        'anlıyorum. bunu biraz daha açsak, altında ne var sence?',
      ]);

  /// Günlük yazısına nazik karşılık.
  static String journal() => _pick(const [
        'bunu yazdığın için teşekkürler. bugün sana iyi gelen tek küçük şey neydi?',
        'duygularını buraya bırakman değerli. yarın kendine ne dilemek istersin?',
        'seni duyuyorum. bu hissin sana söylemeye çalıştığı şey ne olabilir?',
      ]);

  /// Yemek analizine diyetisyen-dost yorumu.
  static String food() => _pick(const [
        'güzel bir seçim. yanına biraz yeşillik eklersen dengesi tam olur.',
        'iyi görünüyor. bol su içmeyi de unutma, sana iyi gelir.',
        'dengeli bir öğün. protein iyi, sonraki öğünde lif eklemeyi deneyebilirsin.',
        'keyifli görünüyor. suçluluk yok — küçük dokunuşlar yeter, baskı değil.',
      ]);
}
