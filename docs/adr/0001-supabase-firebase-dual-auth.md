# ADR-0001: Supabase + Firebase çift-auth köprüsü korunuyor

**Status:** Accepted
**Date:** 2026-07-04

## Decision
Auth Supabase'de kalır; Firestore erişimi `FirebaseAuthBridge` (mintFirebaseToken
custom token) üzerinden sağlanır. Tek auth sistemine geçiş ŞİMDİLİK yapılmaz.

## Context
Kimlik Supabase'de, kullanıcı verisi Firestore'da doğdu. Firestore rules
`request.auth` ister; köprüsüz tüm okuma/yazmalar permission-denied olur.
Production-hardening programında köprünün yarış durumu providers'ın
`firebaseAuthUidProvider`'ı izlemesiyle kapatıldı.

## Alternatives
1. Tamamen Firebase Auth'a geçiş — köprü ve Cloud Function kalkar; ama tüm auth
   UI/akışları + Supabase profiles bağı yeniden yazılır, kullanıcı migration'ı gerekir.
2. Tamamen Supabase'e geçiş (Firestore→Postgres) — daha büyük migration, AI/journal
   repository katmanı komple değişir.

## Pros / Cons
+ Çalışan, testli, yarışları kapatılmış mevcut sistem; sıfır migration riski
+ İki sağlayıcının güçlü yanları kullanılmaya devam (Supabase auth DX, Firestore realtime)
− Kalıcı karmaşıklık: her kullanıcı-provider'ı iki auth kaynağını izlemek zorunda (Sert Kural #2)
− Cloud Function'a (mintFirebaseToken) çalışma-zamanı bağımlılığı

## Reason
Yayın öncesi dönemde migration riski, köprünün taşıma maliyetinden büyük.
Karmaşıklık kurala bağlandı (CLAUDE.md #2) ve kontrol altında.

## Consequences
- Sert Kural #2 kalıcıdır; yeni provider'lar buna uymak zorunda
- `ship` panel listesinde AUTH_BRIDGE_URL deploy kontrolü kalır

## Future Impact
Kullanıcı tabanı büyümeden önce (maliyet: function çağrısı/giriş) tek-auth'a
geçiş L-işi olarak yeniden değerlendirilir; tetikleyici: aylık aktif > 50k
veya köprü kaynaklı ikinci üretim olayı.
