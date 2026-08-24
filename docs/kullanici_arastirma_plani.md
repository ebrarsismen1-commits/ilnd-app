# ilnd · Yayın Öncesi Kullanıcı Araştırma Planı

Durum: v1.0.0-rc1, mağazaya çıkmadı. Analytics event sözlüğü henüz yok
(PRODUCT_ROADMAP NEXT-5), yani elimizde **hiç davranış verisi yok**. Bu yüzden
bu tur niceliksel değil, niteliksel: az kişiyle derin bakış.

Sahipler: **E**=ebrar (moderasyon + kod) · **B**=Beyza (katılımcı bulma, notlar)
· **D**=diyetisyen (içerik sorularında gözlemci)

---

## 1. Amaç

Üç soruya cevap arıyoruz. Hepsi yayın kararını değiştirebilecek sorular:

1. **İlk 5 dakika tutuyor mu?** Karşılama, hızlı kurulum ve ilk kayıt akışından
   sonra kullanıcı ILND'nin ne olduğunu kendi cümleleriyle anlatabiliyor mu?
2. **ILND "beni hatırlıyor" hissi veriyor mu?** Ürünün en kritik
   farklılaştırıcısı bu (decisions.md 2026-07-19, Faz 1B) ve bugüne kadar hiç
   kullanıcıyla test edilmedi.
3. **Neyi paylaşırlar?** Vibe card, alıntı kartı ve streak kartı yatırımın
   büyük kısmını aldı. Kullanıcı bunlardan hangisini gerçekten gönderir?

Amaç olmayan: özellik fikri toplamak. Yeni fikir doğrudan koda gitmez, önce
PRODUCT_ROADMAP'e yazılır (yol haritası kuralı).

## 2. Yöntem

| Aşama | Yöntem | Kişi | Süre |
|---|---|---|---|
| A | Moderasyonlu kullanılabilirlik testi (cihazda, sesli düşünme) | 6 | 45 dk / kişi |
| B | 5 günlük hafif günlük çalışması (aynı 6 kişiden 4'ü devam eder) | 4 | 5 gün |
| C | Kapanış görüşmesi (B'nin sonunda) | 4 | 20 dk / kişi |

Neden 6 kişi: kullanılabilirlik sorunlarının büyük kısmı 5-8 kişide çıkar,
daha fazlası aynı bulguyu tekrar eder. Neden günlük çalışması: bu ürünün asıl
vaadi tek oturumda değil, günler içinde ortaya çıkıyor (hafıza, streak,
haftalık kart). Tek oturumluk test bunu ölçemez.

**Cihaz**: kendi telefonları, internal testing/TestFlight derlemesiyle.
Tarayıcıda test etmeyin: bildirimler, deep link ve paylaşım sayfası web'de
farklı davranıyor, yanlış bulgu üretir.

## 3. Katılımcı profili

6 kişi, hepsi 20-30 yaş, Türkçe arayüz kullanacak:

- 3 kişi: daha önce wellness/meditasyon uygulaması **kullanmış ve bırakmış**
  (bırakma nedeni en değerli veri)
- 2 kişi: hiç kullanmamış, ilgi duyuyor
- 1 kişi: hâlâ aktif kullanıyor (kıyas noktası)

Dışarıda bırak: ekibin arkadaşları ve ürünü daha önce görmüş herkes. Nazik
davranıp gerçek tepkiyi saklarlar.

En az 2 kişi Android, en az 2 kişi iOS olsun. En az 1 kişi sistem yazı
boyutunu büyük kullansın (dynamic type kırılmaları ancak böyle görünür).

## 4. Görüşme kılavuzu (Aşama A, 45 dk)

**Isınma (5 dk)**
- Telefonunda son bir haftada en çok açtığın 3 uygulama hangisi?
- Kendine iyi bakmak dediğimizde aklına ilk ne geliyor? (ürün kelimesi
  kullanma, onların kelimelerini topla)

**Bağlam (8 dk)**
- Daha önce böyle bir uygulama indirdin mi? Ne oldu, neden bıraktın?
- Gün içinde ne zaman telefona "biraz nefes almak için" bakarsın?

**Görev 1 · kurulumdan ilk ana (12 dk)**
Görev: "Uygulamayı yeni indirdin, kur ve sana uygun hâle getir."
İzlenecek: hızlı kurulumda nerede duraksıyor, ilk kayıt ekranındaki şık
seçici anlaşılıyor mu, ILND'nin ilk cevabını okuyor mu yoksa geçiyor mu.
Sonda: "Şu an bu uygulama sence ne yapıyor?" (2. amaç maddesinin ön ölçümü)

**Görev 2 · ILND ile konuşma (10 dk)**
Görev: "Bugünle ilgili aklında ne varsa ILND'ye yaz."
İzlenecek: kaç mesaj sonra bırakıyor, cevabın uzunluğu doğru mu, Türkçesi
tuhaf gelen bir yer var mı (kelime kelime not al, düzeltme prompt'a girecek).

**Görev 3 · paylaşım (7 dk)**
Kartları göster (vibe card, alıntı kartı, streak kartı).
Soru: "Bunlardan birini birine gönderir miydin? Kime, neden?"
Sonda: "Göndermezdin diyorsan, neyi değişse gönderirdin?"

**Kapanış (3 dk)**
- Bu uygulamayı bir arkadaşına tek cümleyle nasıl anlatırdın?
- Sormadığım ama sormam gereken bir şey var mı?

## 5. Günlük çalışması (Aşama B, 5 gün)

Günde tek soru, akşam WhatsApp'tan, tek satır cevap yeterli:

- 1. gün: Bugün uygulamayı açtın mı? Açtıysan seni ne açtırdı?
- 2. gün: Bugün seni rahatsız eden bir şey oldu mu?
- 3. gün: ILND sana seni tanıyormuş gibi bir şey söyledi mi?
- 4. gün: Bugün uygulamada yaptığın en işe yarar şey neydi?
- 5. gün: Yarın silsen ne kaybederdin?

5. gün sorusu kritik: cevap "hiçbir şey" ise retention sorunu yayından
önce görünmüş olur.

## 6. Ölçütler

Sayıya değil eşiğe bakıyoruz. Yayın için beklenen:

| Ölçüt | Eşik |
|---|---|
| Kurulumu yardımsız tamamlayan | 6/6 |
| "Bu uygulama ne yapıyor?" sorusuna ürüne yakın cevap veren | 5/6 |
| ILND'nin Türkçesini tuhaf bulan | 1/6 veya daha az |
| Kartlardan en az birini "gönderirdim" diyen | 4/6 |
| 5. günde "bir şey kaybederdim" diyen | 3/4 |

Eşik tutmazsa: yayın ertelenmez, ama tutmayan madde P0 olarak
PRODUCT_ROADMAP NOW'a girer.

## 7. Sentez

Her oturumdan sonra 24 saat içinde ham not, hafta sonunda affinity mapping:
gözlemler temaya, temalar etki/emek matrisine. Çıktılar:

- `docs/arastirma/<tarih>-bulgular.md` · temalar, alıntılar, öneriler
- Kod değişikliği gerektiren her bulgu için tek satır: bulgu, dosya, öncelik
- Karar seviyesindeki her sonuç `docs/decisions.md`'ye bir satır

Alıntılar birebir yazılır, özetlenmez. Özet, bulgunun rengini öldürüyor.

## 8. Etik ve veri

- Kayıt yalnız izinle, ekran kaydı yeterli, yüz gerekmez
- Katılımcının yazdığı günlük içeriği araştırma notuna kopyalanmaz, yalnız
  davranış not edilir (ürünün kendi gizlilik sözüyle tutarlı kalmak için)
- Test hesapları çalışma bitince `deleteAccount` ile silinir
- Katılımcıya karşılık: 1 yıllık premium erişim (satın alma değil, hesaba
  tanımlama)
