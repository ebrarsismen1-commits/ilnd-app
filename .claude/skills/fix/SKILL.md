---
name: fix
description: Bug, crash, exception veya yanlış davranış düzeltme. Sistematik kök-neden akışı — belirtiyi değil kaynağı düzeltir, sınıf-genelinde kapatır, regresyon testiyle kilitler.
---

# fix — Bug Düzeltme Akışı

## Karar Ağacı
```
Belirti ne?
├─ Crash/exception → stack trace'ten SORUMLU frame'i bul (framework frame'i değil)
├─ Yanlış veri/davranış → veriyi kaynağından UI'a kadar izle; hangi katmanda bozuluyor?
│   sıra: Firestore doc → fromDoc → repository → provider → widget
├─ "Bazen oluyor" → race şüphesi: await sonrası state? auth/köprü sırası? stream yaşam döngüsü?
└─ Görsel bozukluk → `ui` skill'ine geç
```

## Adımlar
1. **Yeniden üret** — mümkünse başarısız bir test olarak yaz (bu test kalacak).
   Testte üretilemiyorsa (cihaz/ağ bağımlı) yeniden üretme koşullarını rapora yaz.
2. **Kök nedeni bul** — "nerede patlıyor" değil "neden bu değer/durum oluştu".
   Belirtinin olduğu satırı yamalamak yasak; nedeni bulana kadar in.
3. **Minimal düzelt** — mevcut mimariyi koru; düzeltme 3+ dosyaya yayılıyorsa dur,
   `refactor` mü gerekiyor değerlendir ve raporla.
4. **Sınıfı kapat** — aynı hata deseni başka yerde var mı? Grep'le, hepsini aynı
   turda düzelt (örn. bir `data()!` bulundu → beşi de düzeltildi).
5. **Kilitle** — 1'deki test artık geçiyor; desen yeniyse CLAUDE.md Sert Kurallar'a
   tek satır ekle.
6. **Kapı** (CLAUDE.md) → rapor: neydi / kökü neydi / ne değişti / hangi dosyalar.

## Yasaklar
- try/catch ile belirtiyi yutmak (kök neden bilinmeden)
- Kök neden bulunmadan "muhtemelen budur" düzeltmesi commit'lemek
- Test edilebilir bir bug'ı regresyon testi olmadan kapatmak

## Definition of Done
- [ ] Kök neden raporda yazılı (belirti değil)
- [ ] Regresyon testi var ve önce kırmızı görüldü
- [ ] Sınıf taraması yapıldı (aynı desen codebase'de kalmadı)
- [ ] Desen yeniyse CLAUDE.md kuralı eklendi · Kapı yeşil
