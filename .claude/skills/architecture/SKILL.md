---
name: architecture
description: Yeni özellik/bağımlılık/şema değişikliği öncesi mimari değerlendirme kapısı. Boyutlandırır (S/M/L), 7 soruyu cevaplar, gerekirse feature'ı reddeder; L kararlarda ADR + kullanıcı onayı ister.
---

# architecture — Mimari Kapı

`build` Adım 0'dan otomatik tetiklenir. Kod, bu değerlendirme bitmeden yazılmaz.

## Boyutlandırma
```
S  Tek dosya/ekran içi; şema, bağımlılık, public API değişikliği yok
   → değerlendirme yok, build devam eder (tek satır not yeter)
M  Yeni provider / koleksiyon / paket / servis entegrasyonu
   → 7 Soru + Mini-Proposal (aşağıda), rapora eklenir
L  Yeni modül, migration, auth/ödeme/veri modeli değişikliği, breaking API
   → Tam Proposal + ADR taslağı + KULLANICI ONAYI (Escalation)
```

## 7 Soru (M ve L için, her biri 1-2 cümle)
1. Mevcut mimariye uyuyor mu (katman sırası, tek-doğru-yer)?
2. Teknik borç üretiyor mu? Üretiyorsa bilinçli mi, ADR'lı mı?
3. Hangi mevcut modülleri etkiliyor (bağımlılık grafiği)?
4. Daha basit/standart alternatif var mı? Neden bu?
5. Modülerliği bozuyor mu (Circle+Etkinlik primitif kararı gibi temellerle çelişki)?
6. 1M kullanıcıda bu sorgu/şema/akış ayakta kalır mı?
7. 2 yıl sonra bu karar hâlâ doğru mu; geri alma maliyeti ne?

**Red yetkisi:** Cevaplardan biri kırmızıysa feature bu haliyle reddedilir —
redde her zaman bir alternatif tasarım eşlik eder.

## Mini-Proposal (M)
Problem · Çözüm (2-3 cümle) · Etkilenen modüller · Şema/Index etkisi ·
Test stratejisi · Risk (tek madde)

## Tam Proposal (L) — Mini + şunlar
User Value · API/Migration etkisi · Performans etkisi · Güvenlik/gizlilik etkisi ·
Rollback stratejisi · Açık sorular → sonra `docs/adr/` kaydı

## Escalation — DUR ve onay iste
Büyük refactor · veri kaybı riski · birden fazla savunulabilir mimari ·
büyük bağımlılık değişimi · breaking API · database migration ·
auth/ödeme akışına dokunan her şey

## Definition of Done
- [ ] Boyut sınıfı raporda; M/L ise sorular cevaplı
- [ ] L ise: ADR dosyası yazıldı + kullanıcı onayı alındı
- [ ] Karar `docs/decisions.md`'ye tek satır girildi
