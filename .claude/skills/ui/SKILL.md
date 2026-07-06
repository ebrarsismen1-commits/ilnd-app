---
name: ui
description: Görsel/tasarım/tema işleri. Marka token'ları, editoryal dil kuralları ve koyu mod + i18n + erişilebilirlik checklist'i.
---

# ui — Tasarım Sistemi ve Ekran Checklist'i

## Token'lar — TEK KAYNAK: docs/DESIGN_SYSTEM.md (aşağısı hızlı özet)
- Gündüz: krem #F5F4F1 zemin · yeşil #1F9D57 vurgu · turuncu #E2611C pop
- Gece: botanik siyah (#10120F ailesi) · parlak yeşil #34C77A — nötr gri koyu YASAK
- Tipografi: Noto Serif (başlık, *italik kelime vurgusu* imzadır) · DM Sans (gövde) · Plex Mono (sayı)
- Motion dili "nefes": yavaş 4sn/6sn ritim (halka), `settle` ~320ms easeOut,
  giriş = `Entrance`, basma = `Pressable`. Yeni curve/süre icat etme.

## Editoryal Kurallar (ölü/AI-jenerik görünümün panzehiri)
- Kutu hastalığı yasak: bölümleri çerçeve değil boşluk + tipografi ayırır
- Ölçek zıtlığı şart: ekranın TEK büyük anı olur (hero); her şey orta boyoysa yanlış
- Fotoğraf zemin olabilir (CoverImage), süs olamaz; renk fotoğraftan gelir
- Duolingo-suçluluğu yasak: streak/boş durum dili şefkatli ("ara vermek de bakımın parçası")

## Ekran Checklist (her UI değişikliğinde)
- [ ] Tüm metinler .arb'de (tr+en) — hardcoded string sıfır
- [ ] Koyu modda bakıldı: palet + Material overlay (dialog/sheet açılıyorsa özellikle)
- [ ] Dar ekran (320dp): satırlar `Expanded`/`Flexible`, taşma yok
- [ ] Klavye: alan görünür kalıyor (Scaffold resize varsayılanı bozulmadı)
- [ ] Tap hedefleri ≥44px; ikon-butonlarda `Semantics` etiketi
- [ ] Boş / yükleme / hata durumu tasarlandı (yükleme = shimmer veya nefes, spinner değil)
- [ ] Renkler paletten; yeni hex gerekiyorsa önce palete eklenir

## Doğrulama
Bu ortamda cihaz önizlemesi güvenilmez → widget testi veya (görsel karar için)
kullanıcıya mockup göster. Kapı her zaman.

## Definition of Done
- [ ] Ekran checklist'inin 7 maddesi işaretli
- [ ] Kapı yeşil · görsel karar gerekiyorsa kullanıcıya gösterildi
