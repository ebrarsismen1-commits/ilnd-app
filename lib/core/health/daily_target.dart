import 'dart:math' as math;

/// Günlük kalori ve makro hedefi.
///
/// Onboarding yaş, boy, kilo ve hareket durumunu zaten topluyordu ama hiçbir
/// yerde kullanmıyordu: Takip ekranı "1240 kcal" diyordu, "1240 / 1900"
/// demiyordu. Bu dosya o dört alana bir karşılık veriyor.
///
/// **Bu bir tahmindir, reçete değil.** Mifflin-St Jeor denklemi nüfus
/// ortalamasına dayanır; birey bazında sapar. Kullanıcı hedefi elle
/// değiştirebilmeli ve arayüz bunu "tahmin" diliyle sunmalı.

/// Beyan edilen cinsiyet. BMR denkleminin tek girdisi olduğu için var;
/// belirtmek zorunlu DEĞİL.
enum BodySex { kadin, erkek, belirtilmemis }

/// Onboarding'deki hareket durumu anahtarlarının çarpanı.
///
/// Anahtarlar quick_setup / tercihler ekranıyla aynı olmalı.
const Map<String, double> kActivityFactors = {
  'az_hareketli': 1.2,
  'orta': 1.55,
  'aktif': 1.725,
};

/// Kilo hedefinin günlük kaloriye etkisi.
///
/// Açık kasıtlı olarak ılımlı: haftada ~0.5 kg için 500 kcal. Daha agresif
/// açık, bu ürünün tonuna da (suçlandırmayan, sürdürülebilir) aykırı olurdu.
enum WeightGoal { ver, koru, al }

int _goalShift(WeightGoal goal) => switch (goal) {
  WeightGoal.ver => -500,
  WeightGoal.koru => 0,
  WeightGoal.al => 300,
};

/// Güvenlik tabanı: hesap ne çıkarırsa çıkarsın bunun altına inilmez.
///
/// Düşük boylu, hafif ve hareketsiz bir profilde "kilo ver" açığı hedefi
/// tehlikeli bir sayıya indirebiliyor. Sağlık iddiası taşıyan bir üründe
/// böyle bir sayıyı ekrana yazmak kabul edilemez, o yüzden taban kodda.
const int kMinDailyKcal = 1200;

class DailyTarget {
  const DailyTarget({
    required this.kalori,
    required this.protein,
    required this.karbonhidrat,
    required this.yag,
  });

  final int kalori;
  final int protein;
  final int karbonhidrat;
  final int yag;
}

/// Mifflin-St Jeor bazal metabolizma hızı (kcal/gün).
///
/// Cinsiyet belirtilmemişse iki denklemin ortası alınır (+5 ve −161'in
/// ortalaması olan −78): bilmediğimiz bir şeyi varsaymaktansa ortada durmak.
double basalMetabolicRate({
  required int age,
  required int heightCm,
  required int weightKg,
  required BodySex sex,
}) {
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return base +
      switch (sex) {
        BodySex.erkek => 5,
        BodySex.kadin => -161,
        BodySex.belirtilmemis => -78,
      };
}

/// Günlük hedef. Zorunlu alanlardan biri eksikse `null` döner — eksik veriyle
/// uydurulmuş bir hedef göstermektense hiç göstermemek doğru.
DailyTarget? calculateDailyTarget({
  required int? age,
  required int? heightCm,
  required int? weightKg,
  required String? activityKey,
  BodySex sex = BodySex.belirtilmemis,
  WeightGoal goal = WeightGoal.koru,
}) {
  if (age == null || heightCm == null || weightKg == null) return null;
  // Akla yatkın sınırlar: bunların dışındaki bir giriş yazım hatasıdır ve
  // hedef hesabına sokulursa saçma bir sayı üretir.
  if (age < 13 || age > 100) return null;
  if (heightCm < 120 || heightCm > 230) return null;
  if (weightKg < 30 || weightKg > 300) return null;

  final factor = kActivityFactors[activityKey] ?? kActivityFactors['orta']!;
  final bmr = basalMetabolicRate(
    age: age,
    heightCm: heightCm,
    weightKg: weightKg,
    sex: sex,
  );

  final kcal = math.max(
    kMinDailyKcal,
    (bmr * factor + _goalShift(goal)).round(),
  );

  // Protein vücut ağırlığına bağlanır (1.6 g/kg), yağ kalorinin %27'si,
  // kalan karbonhidrat. Yüzdeye değil kiloya bağlamak, düşük kalorili
  // hedeflerde proteinin ezilmesini önlüyor.
  final protein = (weightKg * 1.6).round();
  final yag = (kcal * 0.27 / 9).round();
  final karbonhidrat = math.max(
    0,
    ((kcal - protein * 4 - yag * 9) / 4).round(),
  );

  return DailyTarget(
    kalori: kcal,
    protein: protein,
    karbonhidrat: karbonhidrat,
    yag: yag,
  );
}
