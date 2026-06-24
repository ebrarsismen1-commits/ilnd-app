# ILND App

## Vision
Gen-Z wellness & lifestyle app. "Emotional operating system."
Tone: warm, minimal, non-preachy.

## Tech Stack
- Flutter + Dart
- Supabase (auth + storage)
- Firebase Firestore (user data, journal entries)
- Riverpod (state management)
- go_router (navigation)
- SQLite / SharedPreferences (local cache)

## Design (ilnd.app marka kimliğiyle hizalı)
- Tema çift: gündüz açık/havadar/gri-tonlu, gece soğuk kömür luxe — `app_palette.dart`
- Gündüz zemin: #F5F4F1 (havadar, neredeyse beyaz); yüzey: beyaz
- Metin: #111827 (arduvaz); soluk: #6B7280
- Birincil vurgu: yeşil #1F9D57; ikincil pop: turuncu #E2611C
- Fontlar: Noto Serif (başlık/hero, roman, sıkı aralık), DM Sans (gövde), IBM Plex Mono (sayı)
- Stil: açık, editoryal, bol boşluk, desature fotoğraf öne çıkar — renk arayüzden değil fotoğraftan gelir
- Estetik referansı: ilnd.app + Pinterest "ILND" panosu ("clean girl" / sessiz lüks)

## MVP Screens
1. Onboarding (3 steps)
2. Home — daily mood check-in
3. Journal — write + AI prompt
4. Profile + streak

## Rules
- No feature outside MVP scope
- Turkish + English string support from day one
- Minimum 44px tap targets
