---
name: plan
description: Tek oturuma sığmayacak büyük görevleri fazlara bölen orkestratör. Fazlar arası onay kapısı ve rapor disiplini uygular; her fazı doğru skill'e yönlendirir.
---

# plan — Büyük Görev Orkestratörü

## Ne Zaman
Görev şunlardan biriyse tetiklenir: 3+ ekrana/katmana dokunuyor, "her şeyi",
"baştan sona", "production'a hazırla" gibi geniş ifade içeriyor, veya tahminen
tek Kapı turundan uzun sürecek.

## Akış
1. **Envanter** (yalnız tespit, düzeltme yok) — kapsamı gez, sorunları/işleri
   listele, her birine öncelik ver:
   - P0: crash / veri kaybı / güvenlik / gizlilik sızıntısı
   - P1: kullanıcıyı bloklayan yanlış davranış
   - P2: doğruluk/tutarlılık (i18n, tema, durum yönetimi)
   - P3: performans / temizlik / kozmetik
2. **Fazlara böl** — her faz: tek tema, tek Kapı turunda bitebilir boyut,
   önceki faza bağımlıysa sonra gelir. Fazı ilgili skill'e ata (fix/build/ui/...).
3. **Onay al** — faz listesi + ilk fazın kapsamı. Onaysız faza başlama;
   faz bitince rapor ver ve DUR (kullanıcı "devam" demeden sonraki faza geçme).
4. **Faz raporu formatı** (sabit):
   İncelenen / Yanlış olan / Düzeltilen / Dosyalar / Kalan / Önerilen sonraki adım.
5. **Kapanış** — tüm fazlar bitince: özet tablo + kullanıcıya kalan işler
   (panel/cihaz) + öğrenilen yeni desen varsa CLAUDE.md'ye kural olarak işle.

## Kurallar
- Faz içinde kapsam büyümesi yasak: yeni keşif "Kalan"a yazılır, o an yapılmaz.
- Her faz kendi Kapı'sından geçmeden rapor yazılamaz.
- P0 keşfi her şeyi bekletir: mevcut fazı bitir, P0'ı bir sonraki faz yap, raporla.

## Definition of Done (kapanış)
- [ ] Tüm fazlar raporlu; kullanıcıya kalanlar listeli
- [ ] docs/decisions.md'ye faz kararları girildi (docs skill formatı)
- [ ] Retro: tekrarlanan problem var mıydı? → kural/skill güncellemesi önerildi
- [ ] docs/PROJECT_PRINCIPLES.md'ye 1 dk uyum kontrolü yapıldı
