# Mimari — ilnd

## Genel Bakış

ilnd, Gen-Z refahı için geliştirilmiş bir Flutter mobil uygulamasıdır. Çift arka uç mimarisi kullanır: Supabase kimlik doğrulama arayüzünü yönetir; Firebase tüm kalıcı verileri ve sunucu tarafı mantığını üstlenir. Yapay zeka katmanı (Anthropic Claude), yalnızca bir Cloud Function proxy'si üzerinden sunulur — API anahtarı hiçbir zaman istemci binary'sine girmez.

```
┌─────────────────────────────────────────────────────────────────┐
│                         Flutter İstemci                         │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │  Riverpod │  │ go_router│  │ AppTheme │  │ AppLocaliz.  │  │
│  │  (durum) │  │  (nav)  │  │(palet)   │  │  (TR / EN)   │  │
│  └──────────┘  └──────────┘  └──────────┘  └───────────────┘  │
└───────────────────┬──────────────────────────────┬─────────────┘
                    │                              │
          ┌─────────▼────────┐          ┌──────────▼──────────┐
          │   Supabase Auth  │          │  Firebase Firestore  │
          │  (e-posta/şifre) │          │  (tüm uygulama v.) │
          └─────────┬────────┘          └──────────┬──────────┘
                    │  JWT                         │
          ┌─────────▼────────────────────────────┐ │
          │  Cloud Functions (Firebase v2/Node 20)│ │
          │                                      │ │
          │  mintFirebaseToken ◄──── Supabase JWT │ │
          │  anthropicProxy   ──────────────────────┘
          │  redeemReferralCode                  │
          │  deleteAccount                       │
          └──────────────────────┬───────────────┘
                                 │
                    ┌────────────▼──────────┐
                    │  Anthropic API        │
                    │  (haiku-4-5 / sonnet) │
                    └───────────────────────┘
```

## Çift Kimlik Doğrulama Sistemi

Supabase, giriş/kayıt arayüzünü ve oturum yönetimini sağlar. Firebase, Firestore güvenlik kurallarını çalıştırır. Köprüleme şu şekilde çalışır:

1. Kullanıcı Supabase ile giriş yapar → Supabase JWT alır
2. İstemci, JWT ile `mintFirebaseToken` Cloud Function'ı çağırır
3. Cloud Function, JWT'yi Supabase JWKS uç noktasıyla doğrular
4. Firebase özel token'ı döner
5. İstemci bu token ile Firebase Auth'a giriş yapar
6. Tüm Firestore okuma/yazma işlemleri `request.auth.uid` kullanır

Bkz. [`lib/features/auth/auth_provider.dart`](../../lib/features/auth/auth_provider.dart) ve [`functions/index.js`](../../functions/index.js).

## Durum Yönetimi

Tüm durum **Riverpod 2.6.1** ile yönetilir:

| Tür | Kullanım Amacı | Örnek |
|-----|---------------|-------|
| `Provider` | Tekil servisler | `ilndServiceProvider` |
| `StateNotifierProvider` | Değiştirilebilir durum | `authNotifierProvider`, `themeModeProvider` |
| `FutureProvider` | Tek seferlik async | `userGrowthProvider`, `articleProvider` |
| `StreamProvider` | Gerçek zamanlı Firestore | `habitsProvider` |

## Navigasyon

**go_router 14.x** — auth ve onboarding durumunu izleyen `_RouterNotifier` ile:

```
/splash
/auth/login
/auth/register
/onboarding/welcome
/onboarding/quick-setup
/onboarding/first-entry
/home  (alt navigasyon shell'i)
  /chat
  /takip
  /ekle
  /profile
/explore/article/:id
/legal/privacy
/legal/terms
/referral
/vibe-card
/paywall
```

`/legal/privacy` ve `/legal/terms` rotaları auth korumasını atlayarak giriş öncesinde erişilebilir.

## Firestore Veri Modeli

```
users/{uid}
  onboarding_complete: bool
  display_name: string

users/{uid}/journal_entries/{entryId}
  text: string
  aiResponse: string
  mood: string
  createdAt: timestamp

habits/{habitId}
  userId: string
  name: string
  createdAt: timestamp

habit_completions/{completionId}
  userId: string
  habitId: string
  date: string  (YYYY-MM-DD)

user_growth/{uid}
  referral_code: string
  referred_by_code: string | null
  founding_member: bool
  premium_access_until: timestamp | null

referrals/{referralId}
  referrer_id: string
  referred_id: string
  redeemed_at: timestamp

ai_usage/{uid}/{tier}/{date}
  count: int

articles/{articleId}
  id: string
  title: string
  body: string
  category: string
  readTimeMinutes: int
```

## Cloud Functions

| Fonksiyon | Auth Gerekli | App Check | Gizli |
|-----------|-------------|-----------|-------|
| `mintFirebaseToken` | Supabase JWT | Hayır (kasıtlı) | — |
| `anthropicProxy` | Firebase ID token | Evet | `ANTHROPIC_API_KEY` |
| `redeemReferralCode` | Firebase ID token | Evet | — |
| `deleteAccount` | Firebase ID token | Evet | `SUPABASE_SERVICE_ROLE_KEY` |

## Yapay Zeka Katmanı

| Katman | Model | Maks Token | Günlük Limit |
|--------|-------|-----------|-------------|
| `quick` | `claude-haiku-4-5` | 512 | 300/kullanıcı/gün |
| `deep` | `claude-sonnet-4-6` | 1024 | 60/kullanıcı/gün |

Kullanım, Firestore transaction'ı içinde sunucu tarafında takip edilir. İstemci model veya sınırları geçersiz kılamaz.

## Tasarım Sistemi

Uygulama, Flutter'ın `ThemeData.dark()` yerine özel palet sistemi kullanır:

- [`lib/core/theme/app_palette.dart`](../../lib/core/theme/app_palette.dart) — `AppPalette` (açık/koyu varyantlar)
- [`lib/core/theme/app_colors.dart`](../../lib/core/theme/app_colors.dart) — `const` mirror
- [`lib/core/theme/app_theme.dart`](../../lib/core/theme/app_theme.dart) — `MaterialApp`'e uygulanan tema
- [`lib/core/theme/app_text_styles.dart`](../../lib/core/theme/app_text_styles.dart) — tipografi skalası

**Bilinen sınırlama:** `MaterialApp` yalnızca `AppTheme.light` uygular. Stock Material widget'ları koyu mod için call-site renk geçersiz kılması gerektirir. Tam `ThemeData.dark()` entegrasyonu v1.1 için planlanmıştır.

## Dizin Yapısı

```
ilnd_app/
├── lib/
│   ├── main.dart                    # Uygulama girişi, Firebase/Supabase init
│   ├── core/
│   │   ├── billing/                 # RevenueCat sarmalayıcısı
│   │   ├── ilnd/                    # AI servisi, hafıza, kopya yardımcıları
│   │   ├── repositories/            # Firestore CRUD
│   │   ├── router/                  # go_router yapılandırması
│   │   ├── services/                # AppConfig, AppCheckHeaders
│   │   ├── theme/                   # AppPalette, AppColors, AppTheme
│   │   ├── utils/                   # Validators, tarih yardımcıları
│   │   └── widgets/                 # Pressable, AnimatedBackground
│   ├── features/
│   │   ├── auth/                    # Giriş, kayıt, AuthNotifier
│   │   ├── chat/                    # ILND sohbet ekranı
│   │   ├── ekle/                    # Kayıt ekleme alt sayfaları
│   │   ├── explore/                 # Makale listesi ve detayı
│   │   ├── habits/                  # Alışkanlık listesi ve istatistikleri
│   │   ├── home/                    # Ana ekran, ruh hali, niyet
│   │   ├── legal/                   # Gizlilik Politikası, Kullanım Şartları
│   │   ├── onboarding/              # Karşılama, kurulum, ilk giriş
│   │   ├── premium/                 # Ödeme ekranı
│   │   ├── profile/                 # Profil ve ayarlar
│   │   ├── referral/                # Davet kodu arayüzü
│   │   ├── takip/                   # Makro, yemek, aktivite, alışkanlık takibi
│   │   └── vibe_card/               # Haftalık refah kartı (9:16 PNG)
│   └── l10n/                        # app_tr.arb (şablon), app_en.arb
├── functions/                       # Firebase Cloud Functions
├── content/articles.json            # Makale içeriği
├── firestore.rules                  # Güvenlik kuralları
└── .github/workflows/               # CI/CD
```

## İlgili Belgeler

- [KURULUM.md](KURULUM.md) — yerel geliştirme ortamı
- [GELISTIRME.md](GELISTIRME.md) — günlük iş akışı
- [FIREBASE.md](FIREBASE.md) — Firestore şema referansı
- [GUVENLIK.md](GUVENLIK.md) — tehdit modeli ve önlemler
