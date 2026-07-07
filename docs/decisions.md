# Decision Log (append-only)

Her faz/iş kapanışında bir satır. Büyük kararlar ayrıca ADR alır (docs/adr/).
Format: tarih · karar · neden · alternatif · risk/ders.

| Tarih | Karar | Neden | Alternatif | Risk / Ders |
|---|---|---|---|---|
| 2026-07-02 | Marka paleti yeşil/turuncuya restore edildi | Kod, CLAUDE.md marka tanımından sapmıştı (mor/pembe) | Mor paleti resmileştirmek | Ders: tasarım token'ları tek kaynaktan; sapma = regresyon |
| 2026-07-03 | Auth hataları enum kod + UI-l10n mimarisi | Provider'da hardcoded metin EN kullanıcıya TR hata gösteriyordu | Provider'a l10n taşımak | Ders: katman sınırı — metin yalnız UI'da |
| 2026-07-03 | AI hafızası uid-scoped storage + legacy migration | Hesaplar arası gizlilik sızıntısı | Logout'ta silme | Migration ile mevcut kullanıcı hafızası korundu |
| 2026-07-04 | Kullanıcı provider'ları köprü-auth'u da izler | İlk girişte Firestore stream'leri ölü kalıyordu | Stream retry sarmalayıcı | Ders: Firestore stream hatadan sonra kendini yenilemez |
| 2026-07-04 | LLM/analiz HTTP çağrılarına 60sn timeout | Asılı istek sohbeti kalıcı kilitliyordu | Cancel butonu | Kural #4 doğdu |
| 2026-07-04 | AppTheme.dark + themeMode bağlandı | Koyu modda Material overlay'ler açık kalıyordu | Overlay'leri tek tek boyamak | Kural #7 doğdu |
| 2026-07-04 | minify/shrink release'te KAPALI bırakıldı | Cihaz smoke testi yapılamadan runtime kırılma riski | Açıp proguard kuralları | Aktivasyon = cihaz testli ayrı iş |
| 2026-07-04 | Skill tabanlı workflow sistemi kuruldu | Öğrenilen desenler oturumlar arası kayboluyordu | Tek büyük CLAUDE.md | Çekirdek ince + skill'ler talep-üzerine (context ekonomisi) |
| 2026-07-04 | feature/analytics ayrı skill YAPILMADI | build ile çakışma; bağımsız iş akışı yok | 12 ayrı skill | İlke #10: kullanılmayan süreç borçtur |
| 2026-07-04 | Nav v2 kodlandı: merkez halka + Topluluk sekmesi; NOW blokerleri beklerken NEXT öne çekildi | Owner kararı (tasarım momentum'u) | NOW'u beklemek | Takip tam birleşmesi ve gerçek etkinlik listesi (arch:L) sonraki fazlarda |
| 2026-07-04 | Etkinlik+RSVP: kök events + rsvps/{uid} alt koleksiyonu (ADR-0002) | Idempotent RSVP, aggregate count, festival ölçeği | rsvpIds array | Yazma çekişmesi/1MB sınırı elendi |
| 2026-07-07 | Sohbet ekranı v2: halka başlıkta, ILND balonsuz+serif | Vizyon mockup'ı zaten bunu tasarlamıştı, sadece uygulandı | Balonu korumak | Marka jesti (halka) artık 2. ekranda da yaşıyor |
| 2026-07-07 | Keşfet v2: emoji 'stories' şeridi öldürüldü → Ritüeller rafı (gerçek hedefli) | Vizyon: 'Instagram klişesi, dokunulduğunda derinliği yok' — 5/6 kart zaten ölü dokunmaydı | Emoji şeridini korumak | Eşleşen içerik yoksa kart hiç gösterilmez (asla sahte özellik) |
| 2026-07-07 | Sen v2 (serif hero + halka ikon) + Takip'e geri butonu eklendi | Bug: Takip nav v2'de sekmeden push-route'a geçmişti ama header'da geri butonu unutulmuştu — iOS'ta çıkış yolu yoktu | Test yazmak (Firestore mock maliyeti orantısız) | Statik/veri-bağımsız UI eklemesi için manuel kod incelemesi yeterli görüldü |
| 2026-07-07 | Onboarding: 2 dosyada ölü buton-rengi override'ı + yanlış yorum kaldırıldı | Phase 7'de AppTheme.dark bağlanınca bu manuel kod gereksizleşti ama yorum güncellenmemişti | Yorumu güncelleyip kodu bırakmak | Aynı sonuç, daha az kod — refactor değil, stale-doc fix'i |
