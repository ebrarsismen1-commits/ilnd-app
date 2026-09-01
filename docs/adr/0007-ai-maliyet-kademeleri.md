# ADR-0007 — AI maliyet kademeleri: model son çare, ilk çare veri

- **Durum:** Kabul edildi
- **Tarih:** 2026-09-02
- **Tetikleyen:** owner, 2026-09-01: "token kullanımı bizim için büyük sorun,
  premium bir kullanıcı bile 5 dolarlık token harcarsa zarara giriyoruz"

## Bağlam

Uygulamadaki her AI yüzeyi tek kapıdan geçiyor (`ilnd_service.dart` →
`anthropicProxy`) ve o kapının arkasında tek bir fiyat var: Sonnet sınıfı bir
model, milyon token başına 3 dolar girdi, 15 dolar çıktı.

Bugün yalnız **çağrı** sayıyoruz (`ai_usage`): ücretsiz katmanda haftada 20
mesaj ve 5 fotoğraf, herkeste günlük kademe tavanı (quick 300, deep 60).
Sayaç, bir çağrının ne kadar tuttuğunu bilmiyor. Yirmi kelimelik bir mesajla
yirmi bin karakterlik bir yapıştırma orada aynı "1 mesaj"; faturada arasında
elli kat fark var.

Ölçüsüz de olsa büyüklük sırası belli: sekiz turluk geçmiş ve ~800 token'lık
sistem prompt'uyla bir sohbet çağrısı yaklaşık bir sent, fotoğraflı bir analiz
iki katı. Günlük tavanları sonuna kadar kullanan tek bir premium hesap günde
5 dolara ulaşabiliyor. Abonelik bunun altında.

Üç yapısal sızıntı var:

1. **Çıktı tavanı gereğinden geniş.** Karakter "1 ila 3 cümle" konuşuyor
   (~80 token), tavan 512. Çıktı, girdinin beş katı fiyatta.
2. **Girdi zamanla büyüyor.** `IlndMemory.facts` ve `goals` prompt'a tam
   giriyor, tavanı yok: altı ay kullanan biri her mesajda birkaç yüz token
   fazla ödetir. 2026-09-01'de eklenen sohbet geçmişi de ortalamayı artırdı,
   çünkü sekiz turluk pencere artık ilk mesajdan itibaren dolu.
3. **Görünmez çağrılar.** Karşılama, hafıza çıkarımı (dört mesajda bir),
   yemek yorumu; kullanıcının saymadığı ama fatura çıkaran çağrılar.

Kaliteyi ucuzlatma yolu kapalı: quick katmanı eskiden Haiku'ydu, Türkçesi
zayıf geldiği için Sonnet'e alındı (2026-07-08 owner geri bildirimi,
`functions/index.js` TIER_CONFIG notu). Yani "daha ucuz model" bu üründe
denenmiş ve reddedilmiş bir cevaptır.

## Karar

**Modelin cevapladığı her soru, önce daha ucuz bir katmana sorulur. Model son
çaredir ve giderek daha çok "doğrulayıcı", daha az "kaynak" olur.**

Üç kademe, sırayla denenir:

### Kademe 0 — Yerel veri ve şablon (sıfır token)

Elimizde cevabı **zaten olan** hiçbir soru modele gitmez.

- Sohbet: veriden cevaplanabilen mesajlar ("bugün kaç kalori aldım", "iki
  bardak su ekle", "dün ne yemiştim") yerel bir niyet katmanında karşılanır.
- Tekrar eden metinler (streak, ritüel adımları, yedek cevaplar) şablondan
  gelir; bu desen `IlndFallbacks` ve `streak_copy.dart` ile zaten var.

**Yemek bu kademenin dışındadır (owner kararı, 2026-09-02).** Yerel besin
veritabanı ve barkod önerisi reddedildi: fotoğraf analizi ürünün kendisi,
kullanıcıyı listeden yemek seçmeye göndermek onu başka bir uygulamaya
çevirir. Fotoğraf yolunda kesinti, analizin KENDİSİNDEN değil çevresinden
yapılır (aşağıya bakınız).

### Kademe 1 — Ucuz model (sınıflandırma ve çıkarım)

Çıktısı JSON ya da tek cümle olan, karakterin sesini taşımayan çağrılar ucuz
bir modele gider: hafıza çıkarımı, niyet sınıflandırma, malzemeden makro
tahmini. Kalite riski düşük çünkü bu çıktıları kullanıcı ILND'nin ağzından
duymuyor.

### Kademe 2 — Sonnet (gerçek sohbet ve doğrulama)

Kullanıcının ILND ile konuştuğu an ve tanınmayan tabağın analizi. Kaliteden
buradan kısılmaz.

### Fotoğraf yolunda kesinti analizin çevresinden yapılır

Analiz çağrısının kalitesine dokunulmaz; etrafındaki israf temizlenir.
2026-09-02'de uygulanan iki kesinti bu ilkenin örneğidir:

1. **Yorum analize gömüldü.** Her fotoğraftan sonra ILND'nin tek cümlelik
   yorumu için İKİNCİ bir tam çağrı gidiyordu: kişilik prompt'u baştan
   gönderiliyor, karşılığında bir cümle alınıyordu. Model tabağa zaten
   bakıyor; `yorum` artık analiz JSON'unun bir alanı. Öğün başına iki çağrı
   yerine bir.
2. **Görüntü 1024 pikselle sınırlandı** (önce 1280 genişlik, yükseklik
   sınırsız). Anthropic 1.15 megapikselin üstünü zaten kendi küçültüyor, yani
   dikey bir karenin fazlalığı hiç modele ulaşmadan atılıyor ama token'ı
   ödeniyordu. Modelin gördüğü şey değişmez.

Kural: **analiz kalitesi kısılmaz, aynı çağrıya daha çok iş yaptırılır ve
kullanılmayan girdi gönderilmez.**

### Sohbette uzun vadeli hatırlama pencerede değil hafızadadır

Owner, 2026-09-02: "modelin eski konuşmaları çok iyi hatırlamasına gerek yok,
kritik şeyleri tutsun yeter." Modele giden tur penceresi sekizden dörde
indi ve eski turlar 400 karaktere kırpılıyor. Uzun vadeli hatırlama
`IlndMemory`'nin işi: hedefler, gerçekler ve tarihli notlar her çağrıda
gidiyor, ham konuşma geçmişi gitmiyor.

**Ekrandaki geçmiş kısalmaz.** Kullanıcı bütün konuşmayı görmeye devam eder;
kısalan yalnız modele gönderdiğimiz kısımdır. Bu ayrım korunmalı: pencereyi
küçültmek bir maliyet kararıdır, kullanıcıdan bir şey almak değil.

### Sınırlar veriyle konur, tahminle değil

2026-09-02'de token muhasebesi kuruldu (`functions/tokenUsage.js`,
`ai_token_usage/{uid}_{gün}`): her çağrının gerçek girdi, çıktı ve önbellek
token'ı, tür ve katman kırılımıyla yazılıyor. **Hiçbir tavan bu veriden önce
değiştirilmez** (owner kararı: "önce gerçek rakamı görelim"). Bir haftalık
veriden sonra `npm run report:tokens` çıktısındaki en pahalı kullanıcının
aylık izdüşümü, günlük tavanın ve çıktı tavanının ne olacağını söyler.

## Alternatifler

**Daha ucuz model (Haiku ya da açık 7B sınıfı).** Denendi ve geri alındı:
Türkçesi kullanıcıya bozuk geliyordu. Sohbet ürünün kalbi, kalite orada
ucuzlatılmaz. Kademe 1'de yeniden değerlendirilebilir çünkü orada model
kullanıcıyla konuşmuyor.

**Yalnız tavanları indirmek.** En kötü hâli sınırlar ama ürünü de küçültür:
çok konuşan premium kullanıcı gün içinde duvara çarpar ve ödediği şeyi
kullanamaz. Tavan gerekli, tek başına yeterli değil.

**Kendi sunucumuzda GPU ile model çalıştırmak.** Sabit maliyet aylık birkaç
yüz dolar; bugünkü hacimde serverless bir açık model sağlayıcısı çok daha
ucuz. Hacim büyürse yeniden bakılır.

**Hiçbir şey yapmamak, kullanım büyüyünce bakmak.** Kabul edilmedi: zarar
kullanıcı başına ve sessiz. Büyüme, sorunu keşfetme anını değil faturayı
büyütür.

## Sonuçlar

- Yeni bir AI yüzeyi eklerken **önce kademe 0 aranır.** "Bunu modele
  sormadan cevaplayabilir miyiz" sorusu, mimari kapısının parçasıdır.
- Her metered çağrının çıktı tavanı, o yüzeyin gerçekten ihtiyacı olan
  uzunluğa göre belirlenir. Varsayılan tavanı kopyalamak bir karar değildir.
- Prompt'a giren her şeyin bir tavanı olmalı: geçmiş penceresi, not
  penceresi, `facts`, `goals`. Tavansız alan, zamanla büyüyen bir fatura
  kalemidir.
- Token muhasebesi kapatılmaz. Sınır tartışması her zaman rapordan başlar.
- Fiyatlar `tokenUsage.js` içinde sabit: model değişirse orası da değişmeli,
  yoksa rapor sessizce yanlışlaşır.

## Açık soru: sağlayıcıdan bağımsızlaşma

Owner'ın uzun vadeli hedefi (2026-09-02): "kullanıcı geldikçe yeterli veriyi
toplayarak Anthropic'ten bağımsız olmak." Bu, kademe mimarisinin doğal
devamı ve maliyet sorununun kalıcı çözümü.

Ama bir çelişki taşıyor ve KARARLAŞTIRILMADAN uygulanmamalı: bugünkü veri
sözleşmesi tam tersini söylüyor. Kullanıcının adı hiçbir istekte cihazdan
çıkmıyor, not penceresi bilerek kırpılıyor (bkz. `ilnd_memory.dart`,
`test/core/ilnd/data_minimization_test.dart`, KVKK gerekçesi 2026-08-11).
Model eğitmek için fotoğraf, analiz ve sohbet çiftlerini saklamak, o
sözleşmenin açıkça gevşetilmesi demektir.

Yapılması gereken sırayla: (1) hangi verinin, ne kadar süreyle, hangi amaçla
saklanacağına karar ver, (2) açık ve ayrı bir rıza akışı tasarla (varsayılan
kapalı), (3) aydınlatma metnini ve saklama süresini gizlilik politikasına
yaz, (4) ancak ondan sonra toplamaya başla. Toplanan veri kimliksizleştirilse
bile fotoğraf ve günlük metni kişisel veridir.

## Gelecek etkisi

Model fiyatları düşerse kademe 1 ile kademe 2 arasındaki fark kapanır ve
sınıflandırma çağrılarını ayrı bir sağlayıcıda tutmanın anlamı kalmaz; o
noktada kademe 1 kaldırılabilir, kademe 0 kalır. Kademe 0 fiyattan bağımsız
olarak doğru: yerel veritabanından gelen makro, en iyi modelin tahmininden
de hızlı ve doğrudur.

Geri alma maliyeti kademeye göre değişir. Kademe 0 kalıcı bir varlıktır
(besin veritabanı, barkod). Kademe 1 bir yönlendirme kararıdır, tek yerden
(proxy) geri alınır.
