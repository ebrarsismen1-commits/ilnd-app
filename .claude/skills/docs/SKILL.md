---
name: docs
description: Dokümantasyon ve ADR sistemi. Neyin nereye yazılacağına karar verir; karar kayıtlarının kaybolmasını önler.
---

# docs — Dokümantasyon Karar Mekanizması

## Ne Nereye
```
Bilgi tipi                          → Yeri
Mimari karar (geri alması pahalı)   → docs/adr/NNNN-basit-ad.md (şablon: 0000)
Faz/iş kararı (tek satırlık)        → docs/decisions.md (append-only tablo)
Tekrarlanabilir hata deseni/kural   → CLAUDE.md Sert Kurallar / Tuzaklar
Test deseni                         → .claude/skills/testing/SKILL.md
Kullanıcıya görünen değişiklik      → CHANGELOG.md (+ docs/en, docs/tr eşleniği varsa)
Panel/kurulum adımı (Supabase vb.)  → docs/en|tr ilgili rehber
Kod içi "neden"                     → yorum (yalnız kodun gösteremediği kısıt;
                                      "ne yaptığını" anlatan yorum yazılmaz)
```

## ADR Ne Zaman Zorunlu
- `architecture` L kararları (her zaman)
- Bilinçli teknik borç kabulü ("şimdilik böyle, çünkü...")
- İki savunulabilir seçenekten birinin seçimi (aylar sonra "neden?" sorusu doğacaksa)

## ADR Yaşam Döngüsü
Status: Proposed → Accepted → (gerekirse) Superseded by NNNN.
ADR silinmez, üzerine yazılmaz — yeni karar yeni ADR + eskiye referans.

## Definition of Done
- [ ] Karar doğru katmana yazıldı (yukarıdaki tablo)
- [ ] ADR ise: şablonun tüm alanları dolu, numara sıralı, decisions.md'ye satır düştü
- [ ] Belge Türkçe, kod/komutlar olduğu gibi
