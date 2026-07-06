# ilnd — Admin Rehberi

Uygulamayı işletmek için tek belge. Kod bilgisi gerektirmeyen işler 🟢,
terminal gerektirenler 🟡, geliştirici işi 🔴 ile işaretli.

---

## 1. İçerik Yönetimi

### 🟡 Makale ekleme / düzenleme
Kaynak: `content/articles.json` (tek doğru yer — uygulama Firestore'dan canlı okur,
**app güncellemesi gerekmez**).
1. JSON'a yeni kayıt ekle. Alanlar:
   `id` (kalıcı, benzersiz, değiştirme!) · `order` (sıralama) · `title` ·
   `category` (`wellness`|`tarif`|`yazi`) · `readTime` ("5 dk") · `excerpt` ·
   `imageUrl` (Unsplash vb.) · `body` (paragraf dizisi)
2. Yayınla:
   ```
   node functions/scripts/seedArticles.js          # ekle/güncelle
   node functions/scripts/seedArticles.js --prune  # JSON'dan sildiklerini Firestore'dan da kaldır
   ```
   Ön koşul (bir kez): `gcloud auth application-default login`
3. Uygulamada saniyeler içinde görünür.

### 🟡 Etkinlik ekleme + RSVP izleme
- Kaynak: `content/events.json` → `node functions/scripts/seedEvents.js` (aynı desen).
- Alanlar: `id` · `title` · `city` · `venue` · `startsAt` (ISO tarih) · `capacity`.
- Kimler geliyor? Firebase Console → Firestore → `events/{id}/rsvps` — her doküman
  bir katılımcı (doc id = kullanıcı id'si). Katılımcı sayısı uygulamada canlı.

---

## 2. Kullanıcıları İzleme

### 🟢 Kullanıcı listesi ve hesap yönetimi — Supabase Dashboard
supabase.com/dashboard → proje → **Authentication → Users**
- Kayıtlı herkes: e-posta, kayıt tarihi, son giriş, giriş yöntemi
- Hesap silme/banlama buradan (kullanıcı zaten uygulama içinden de silebiliyor)

### 🟢 Davranış metrikleri — Firebase Console → Analytics
- DAU/WAU/MAU, app_open, ekran süreleri, ülke/cihaz dağılımı
- İlk hafta yapılacak: Analytics → Dashboards'u haftalık ritüel yap (Beyza'nın alanı)

### 🟢 Çökme izleme — Firebase Console → Crashlytics
- Release'te otomatik açık. Haftada bir bak; yeni "issue" görürsen ebrar'a ilet.

### ⚠️ Etik sınır
`users/{uid}` altındaki günlükler/yemekler teknik olarak Console'dan okunabilir —
**okumayın.** Gizlilik Politikası kullanıcıya "verini yalnız hizmet için işleriz" diyor;
destek talebi olmadan kullanıcı içeriğine bakmak hem güveni hem KVKK'yı ihlal eder.

---

## 3. Güncelleme Yayınlama

### İçerik ≠ Uygulama
Makale/etkinlik = anında, mağazasız (yukarıdaki script'ler).
Kod/tasarım değişikliği = mağaza sürümü (aşağıda).

### 🔴 Android sürümü (mevcut CI ile)
1. `pubspec.yaml` → `version: 1.0.1+2` (semver + build no artır)
2. Commit → `git tag v1.0.1 && git push --tags`
3. GitHub Actions `release.yml` imzalı `.aab` üretir
   (ön koşul: repo Secrets'ta keystore — bkz. `android/KEYSTORE.md`)
4. Play Console → Production (ilk sürümde: Internal testing önce!) → AAB yükle →
   sürüm notu → **staged rollout %10-20 ile başlat**
5. 24-48 saat Crashlytics izle → sorun yoksa %100'e çek

### 🔴 Geri alma (kötü sürüm çıktıysa)
Play Console → ilgili release → "Halt rollout"; düzeltme sürümü hazırlanana kadar
eski sürüm dağıtımda kalır. (APK "geri yüklenmez"; hızlı hotfix sürümü çıkılır.)

### 🔴 iOS
Xcode → Archive → App Store Connect → TestFlight → Review. (CI'a taşınması LATER.)

### 🟡 Kural/fonksiyon güncellemeleri (app sürümünden bağımsız)
```
firebase deploy --only firestore:rules     # güvenlik kuralları
firebase deploy --only functions           # AI proxy, referral, deleteAccount
```

---

## 4. Servis Panelleri (ne nerede yönetilir)

| Panel | Ne için | Kritik ayarlar |
|---|---|---|
| Supabase | Kimlik | Auth Providers (Google/Apple), reset-password URL, **service-role key rotasyonu** |
| Firebase | Veri+ölçüm | Firestore verisi, Rules, Analytics, Crashlytics, App Check |
| Google Cloud | OAuth | Google Sign-In client ID'leri |
| RevenueCat | Abonelik | Ürünler/fiyat, entitlement `premium`, gelir paneli |
| Play/App Store | Dağıtım | Sürümler, listing, yorumlara cevap |

---

## 5. Haftalık Admin Ritüeli (30 dk)

- [ ] Crashlytics: yeni çökme var mı?
- [ ] Analytics: DAU/haftalık trend + en çok kullanılan ekran
- [ ] Supabase Users: yeni kayıt sayısı
- [ ] Mağaza yorumları: cevapla (marka sesiyle: sıcak, kısa)
- [ ] İçerik: bu haftanın makalesi girildi mi? (Dyt.)
- [ ] `docs/PRODUCT_ROADMAP.md` günceli yansıtıyor mu?

## 6. Acil Durum Kartları

- **"Uygulama açılmıyor" dalgası** → Crashlytics'e bak → ebrar'a issue linki
- **Supabase/Firebase kesintisi** → status.supabase.com / status.firebase.google.com;
  uygulama nazik hata gösterir, panik yok
- **Veri silme talebi (KVKK)** → kullanıcıya uygulama içi "hesabımı sil"i göster;
  yapamıyorsa: Supabase'den kullanıcıyı bul → deleteAccount akışı ebrar ile
- **Yanlış içerik yayınlandı** → JSON'dan düzelt → seed script → saniyeler içinde düzelir

---
*Uzun vadede (LATER): Bu işlerin çoğu için web admin paneli — şimdilik JSON+panel
yeterli ve güvenli; erken panel = erken karmaşıklık (İlke #10).*
