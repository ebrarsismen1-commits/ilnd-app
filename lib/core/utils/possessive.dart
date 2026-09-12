import 'package:ilnd_app/l10n/app_localizations.dart';

/// Bir ismin sahiplik hâli: "Ela" → "Ela'nın", "Ebrar" → "Ebrar'ın".
///
/// Türkçede ek ismin son ünlüsüne göre değişir (ünlü uyumu) ve isim
/// ünlüyle bitiyorsa araya "n" girer; .arb şablonu bunu ifade edemediği
/// için ek burada hesaplanır. İsim özel ad olduğu için kesmeyle ayrılır.
String turkishGenitive(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return trimmed;

  const back = {'a', 'ı'};
  const front = {'e', 'i'};
  const backRound = {'o', 'u'};
  const frontRound = {'ö', 'ü'};

  // Türkçe küçük harf: I → ı, İ → i. String.toLowerCase bunu yerel ayardan
  // bağımsız garanti etmiyor.
  final lower = trimmed.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  String? lastVowel;
  for (var i = lower.length - 1; i >= 0; i--) {
    final c = lower[i];
    if (back.contains(c) ||
        front.contains(c) ||
        backRound.contains(c) ||
        frontRound.contains(c)) {
      lastVowel = c;
      break;
    }
  }

  final vowel = switch (lastVowel) {
    final v? when back.contains(v) => 'ı',
    final v? when backRound.contains(v) => 'u',
    final v? when frontRound.contains(v) => 'ü',
    // Ünlüsüz kısaltmalar ("Mrt") ince okunur.
    _ => 'i',
  };

  final endsWithVowel =
      lastVowel != null && lower.endsWith(lastVowel) && lower.length > 1;
  final buffer = endsWithVowel ? 'n' : '';
  return "$trimmed'$buffer${vowel}n";
}

/// Uygulama diline göre sahiplik hâli: TR "Ela'nın", EN "Ela's".
String possessiveName(AppLocalizations l10n, String name) =>
    l10n.localeName.startsWith('tr') ? turkishGenitive(name) : "$name's";

/// Cümle başı büyük harf, Türkçe kurallarıyla.
///
/// `String.toUpperCase()` 'i' harfini 'I' yapar; Türkçede karşılığı 'İ'.
/// Selamlama .arb'de küçük harfle duruyor (cümle ortasında da kullanılıyor)
/// ve Bugün ekranı başını büyütüyor: düzeltilmezse ekranda "Iyi günler"
/// yazıyordu.
String capitalizeTr(String text) {
  if (text.isEmpty) return text;
  final first = text[0];
  final upper = switch (first) {
    'i' => 'İ',
    'ı' => 'I',
    _ => first.toUpperCase(),
  };
  return '$upper${text.substring(1)}';
}
