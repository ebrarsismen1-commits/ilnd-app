import 'package:ilnd_app/core/ilnd/ilnd_memory.dart';

/// Demo modu — toplantı/sunum için uygulamayı "dolu ve seni tanıyor" gösterir.
///
/// Açıkken: hafıza inandırıcı bir kişilikle tohumlanır ve sohbet zaten başlamış
/// gibi açılır. Gerçek kullanıma geçerken `false` yap.
const bool kDemoMode = false;

/// Demo kullanıcısının önceden "hatırlanan" profili.
const IlndMemory kDemoMemory = IlndMemory(
  name: 'Ela',
  goals: [
    'akşamları daha az şeker',
    'haftada 3 gün yürüyüş',
    'daha düzenli uyku',
  ],
  facts: [
    'vejetaryen',
    'akşamları stresli olabiliyor',
    'sabah kahvesini seviyor',
    'laktoza hassas',
  ],
  recentNotes: [
    'Günlük: bugün işte yoğundum ama akşam yürüyüşü iyi geldi',
    'Yemek: Mercimek Çorbası (180 kcal)',
    'Kullanıcı: bu aralar uykum biraz düzensiz',
  ],
);

/// Sohbet ekranını "ilişki zaten sürüyor" hissiyle açan örnek diyalog.
const List<({bool fromUser, String text})> kDemoChatOpening = [
  (fromUser: false, text: 'günaydın Ela 🌿 dün akşam yürüyüşün nasıl geçti?'),
  (fromUser: true, text: 'iyiydi aslında, kafam biraz dağıldı'),
  (
    fromUser: false,
    text:
        'buna sevindim. hareket sana iyi geliyor gibi. bugün şeker hedefin için '
        'kendine küçük bir şey ayarlamak ister misin?',
  ),
];
