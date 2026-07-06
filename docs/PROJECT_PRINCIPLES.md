# ilnd — Project Principles (Kuzey Yıldızı)

Çatışma anında üstteki kazanır. Her feature kapanışında bu listeye karşı
1 dakikalık uyum kontrolü yapılır (plan/build DoD maddesi).

1. **Kullanıcı verisi kutsaldır** — gizlilik sızıntısı, veri kaybı ve güvenlik
   her şeyi bekletir (P0). "Warm" marka, güvenle başlar.
2. **Maintainability > hız** — iki yıl sonra da doğru olacak çözüm; kolay ama
   borç üreten çözüm reddedilir. Borç bilinçli alınacaksa ADR'a yazılır.
3. **Tek doğru yer** — bir kural/renk/metin/desen tek kaynakta yaşar
   (palet, Validators, .arb, AuthErrorCode). Kopya = gelecekteki bug.
4. **Ölçeklenebilir varsayılan** — koleksiyon şeması, sorgu ve provider tasarımı
   1M kullanıcıda da çalışacak biçimde seçilir (aggregate sorgu, index, sayfalama).
5. **Davranış kanıtla değişir** — refactor sözleşmeyle, optimizasyon ölçümle,
   bug fix regresyon testiyle.
6. **Marka tutarlılığı üründür** — "warm, minimal, non-preachy" ton ve editoryal
   tasarım dili kod kadar korunur; jenerikleşme bir regresyondur.
7. **Kullanıcı asla ham hata görmez** — her dış bağımlılık için fallback/nazik
   hata; exception metni UI'a sızmaz.
8. **Consistency over cleverness** — mevcut desen dururken yeni desen icat
   edilmez; desen değişecekse her yerde değişir (ADR ile).
9. **Otonom ama şeffaf** — kararlar raporlanır, büyük kararlar (Escalation
   listesi) onay bekler, hiçbir şey sessizce yapılmaz.
10. **Gereksiz karmaşıklık borçtur** — süreç dahil: kullanılmayan workflow,
    okunmayan doküman ve erken soyutlama silinir.
