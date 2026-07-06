---
name: refactor
description: Davranışı değiştirmeden yapıyı iyileştirme. Davranış-koruma kanıtı, küçük adımlar ve her adımda yeşil test şartı.
---

# refactor — Davranış-Korumalı Değişiklik

## Ön Koşul (yoksa refactor'a başlama)
1. Kapı ŞU AN yeşil mi? Değilse önce `fix`.
2. Dokunulacak davranışı 3-5 maddeyle listele ("sözleşme"). Test kapsamıyorsa
   önce o davranışı kilitleyen testi yaz — refactor'dan ÖNCE.

## Kurallar
- Tek turda tek tür değişiklik: taşıma AYRI, yeniden adlandırma AYRI, mantık
  değişikliği ise bu skill'in konusu DEĞİL (`build`/`fix`).
- Her küçük adımdan sonra Kapı; kırmızıya düşen adım geri alınır, ikiye bölünür.
- Public API değişiyorsa tüm çağıranlar aynı adımda güncellenir — yarım bırakma.
- "Hazır elim değmişken" iyileştirmesi yasak; gördüğünü raporun "kalan" bölümüne yaz.

## Ne Zaman Refactor DEĞİL
- Davranış da değişecekse → `build`
- Amaç hız/bellek ise → `perf` (ölçüm ister)
- CLAUDE.md kuralı: "Never rewrite working code" — refactor'un gerekçesi
  somut olmalı (tekrar eden bug kaynağı, kanıtlı okunabilirlik engeli, yeni
  özelliğin önünü açma). "Daha şık olur" gerekçe değildir.

## Rapor
Sözleşme maddeleri + hepsinin hâlâ yeşil olduğu kanıtı / dosyalar / kalan.

## Definition of Done
- [ ] Sözleşme maddelerinin tümü hâlâ yeşil (kanıt raporda)
- [ ] Public API değiştiyse tüm çağıranlar güncel · Kapı yeşil
- [ ] "Elim değmişken" yapılmadı; görülenler Kalan'da
