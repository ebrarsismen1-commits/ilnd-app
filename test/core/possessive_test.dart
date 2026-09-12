import 'package:flutter_test/flutter_test.dart';
import 'package:ilnd_app/core/utils/possessive.dart';

/// Bugün'deki ada kartı "Ela'nın adası" diyor. Ek ismin son ünlüsüne göre
/// değiştiği için tek bir .arb şablonu yetmiyor; yanlış ek ("Ebrar'nın")
/// kullanıcının kendi adında göze batar.
void main() {
  test('ünlüyle biten isim araya n alır', () {
    expect(turkishGenitive('Ela'), "Ela'nın");
    expect(turkishGenitive('Ayşe'), "Ayşe'nin");
    expect(turkishGenitive('Duru'), "Duru'nun");
    expect(turkishGenitive('Öykü'), "Öykü'nün");
  });

  test('ünsüzle biten isim yalın eki alır', () {
    expect(turkishGenitive('Ebrar'), "Ebrar'ın");
    expect(turkishGenitive('Mert'), "Mert'in");
    expect(turkishGenitive('Oğuz'), "Oğuz'un");
    expect(turkishGenitive('Gül'), "Gül'ün");
  });

  test('büyük I ve İ Türkçe okunur', () {
    expect(turkishGenitive('IŞIK'), "IŞIK'ın");
    expect(turkishGenitive('İPEK'), "İPEK'in");
  });

  test('boşluklar kırpılır, boş isim boş kalır', () {
    expect(turkishGenitive('  Ela '), "Ela'nın");
    expect(turkishGenitive(''), '');
  });

  test('cümle başı Türkçe büyütülür: i harfi İ olur', () {
    // toUpperCase() 'i' harfini 'I' yapıyor ve Bugün ekranında "Iyi günler"
    // yazıyordu.
    expect(capitalizeTr('iyi günler'), 'İyi günler');
    expect(capitalizeTr('ıslak'), 'Islak');
    expect(capitalizeTr('günaydın'), 'Günaydın');
    expect(capitalizeTr('şu an'), 'Şu an');
    expect(capitalizeTr(''), '');
  });
}
