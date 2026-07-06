---
name: build
description: Yeni özellik, ekran veya yetenek ekleme. İşi katman sırasıyla küçük adımlara böler; her adım Kapı'dan geçmeden sonrakine geçilmez.
---

# build — Özellik Geliştirme Akışı

## Adım 0 — Kapsam Sözleşmesi + Mimari Kapı
Tek paragraf: ne YAPILACAK / YAPILMAYACAK / dokunulan ekran-akışlar.
Sonra `architecture` skill'i ile boyutlandır (S/M/L): M → mini-proposal,
L → tam proposal + ADR + kullanıcı onayı. Onaysız L koduna başlanmaz.
Görev 1 oturumdan büyükse → `plan`.

## Katman Sırası (her adım: yaz → Kapı → sonraki)
```
1. l10n     → yeni tüm metinler app_tr.arb (şablon) + app_en.arb; gen-l10n
2. Model    → fromDoc güvenli desen (data() ?? {}), toMap alan adları rules ile uyumlu
3. Rules    → yeni koleksiyon varsa firestore.rules + gerekirse index; kural yoksa
              koleksiyon PROD'DA ÖLÜdür (deny-all)
4. Repo/Provider → aşağıdaki checklist
5. UI       → `ui` skill kuralları otomatik geçerli
6. Test     → en az: mutlu yol + 1 sınır durumu
```

## Yeni Provider Checklist
- [ ] Kullanıcı verisi mi? → `authNotifierProvider` (select uid) + `firebaseAuthUidProvider` izle
- [ ] Hesap değişince state sıfırlanmalı mı? (chat/memory deseni)
- [ ] Stream mi? Hata durumunda UI ne gösterir (boş mu, hata durumu mu)?
- [ ] Dış çağrı varsa timeout + kullanıcı-dostu hata (enum kod → l10n)
- [ ] Ölçülmesi gereken kullanıcı eylemi varsa analytics event'i tanımlı (isim: `alan_eylem`)

## Otomatik Tetikler
- Ekran/görsel içeriyorsa → `ui` checklist'i uygulanır
- Firestore'a yeni sorgu → composite mi kontrol et (where+orderBy farklı alan = index)
- Özellik bitti → `ship` değil; sadece Kapı. `ship` yalnız yayın öncesi.

## Rapor Formatı
Yapılan / dosyalar / bilinçli kapsam-dışı bırakılanlar / sonraki adım önerisi.

## Definition of Done
- [ ] Kapsam sözleşmesi karşılandı; M/L ise mimari değerlendirme raporda
- [ ] Tüm metinler tr+en .arb'de · testing skill karar ağacına göre testler yeşil
- [ ] Kapı yeşil · PROJECT_PRINCIPLES hızlı kontrolü yapıldı
