# ilnd — Architecture Blueprint

Mevcut durum + hedef mimari. İlkeler: docs/PROJECT_PRINCIPLES.md ·
Büyük kararlar: docs/adr/ · Vizyon: docs/ilnd_tasarim_vizyonu.md

## 1. Bugünkü Sistem (v1.0 — doğrulanmış)
```
Flutter (Riverpod + go_router)
 ├─ Auth: Supabase ──köprü(ADR-0001)──▶ Firebase request.auth
 ├─ Veri: Firestore (rules+index versiyonlu) · SharedPreferences (cihaz/uid-scoped)
 ├─ AI:   IlndService ─▶ CF anthropicProxy (anahtar+limit sunucuda, App Check)
 ├─ Ödeme: RevenueCat (entitlement 'premium')     ├─ Analytics: FA
 └─ İçerik: content/articles.json ─seed script─▶ articles (client read-only)
```
Katman kuralları CLAUDE.md'de; burada tekrar edilmez.

## 2. Modül Sınırları (feature ekleme haritası)
| Modül | Sahip olduğu | BAĞIMLI OLAMAZ |
|---|---|---|
| core/ilnd | AI karakter+hafıza+servis | feature'lara |
| core/repositories | Firestore erişimi | UI'a, l10n'a (hata=kod) |
| core/billing | entitlement+usage | feature iç detayına |
| features/* | ekran+provider | başka feature'ın iç dosyasına (paylaşım core'a iner) |

## 3. Hedef Primitifler (vizyon §Topluluk — henüz kodlanmadı)
Gelecek her sosyal/ticari özellik İKİ primitifin özelleşmesidir:
- **Circle** `{id, type: circle|program|corporate, ownerId, memberIds[], city?}`
- **Etkinlik** `{id, circleId?, city, date, capacity, rsvps[]}`
Creator=Circle sahibi · Koç programı=ücretli Circle · Festival=mega Etkinlik.
Bu şemadan sapma = architecture L kararı + ADR.

## 4. Ölçek Eşikleri (tetikleyici → aksiyon)
| Eşik | Aksiyon |
|---|---|
| MAU 10k | Analytics event sözlüğü zorunlu denetim; Crashlytics alarm kurulumu |
| MAU 50k | ADR-0001 yeniden değerlendir (tek-auth); weeklyCheckin count() maliyet kontrolü |
| MAU 100k+ | Journal/feed sorgularına sayfalama zorunlu; CF bölge/ölçek gözden geçirme |
| İlk creator geliri | Ödeme akışı ayrı modüle (core/payments), marketplace ADR'ı |
| 3. dil | İçerik pipeline'ına (articles.json) locale boyutu |

## 5. Bilinçli Borçlar (kayıtlı, izlenen)
1. Çift-auth köprüsü — ADR-0001, tetikleyicisi tanımlı
2. Onboarding verisi cihaz-scoped (userName) — hesap değişiminde kozmetik sızıntı
3. minify kapalı — cihaz-testli ayrı iş
4. Hukuki gövde yalnız TR — avukat onaylı çeviri bekliyor
Yeni borç eklemek = bu listeye + gerekçe; sessiz borç yasak.

## 6. Genişleme Reçetesi (özet — detay: build skill)
Yeni özellik = architecture(S/M/L) → l10n → model(+rules+index) → provider
(auth-scoped checklist) → UI(ui skill) → test(testing skill) → Kapı.
