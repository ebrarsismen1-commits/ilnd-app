# ilnd — Product Roadmap (Now / Next / Later)

Sahipler: **E**=ebrar(kod) · **B**=Beyza(operasyon/büyüme) · **D**=diyetisyen(içerik)
Vizyon fazları: docs/ilnd_tasarim_vizyonu.md §7 · Bu belge sprint kaynağıdır;
her sprint kapanışında güncellenir.

## NOW — Yayın Blokerleri (v1.0 çıkışı)
| İş | Sahip | Durum |
|---|---|---|
| Supabase Google/Apple provider + Google Cloud OAuth ID | E/B | panel |
| RevenueCat ürünler + API key | B | panel |
| Upload keystore + Play Console listing | E/B | panel |
| Firestore kopya makale `--prune` + service-role ROTASYON | E | komut |
| KVKK/hukuki metin avukat onayı | B | dış |
| 10 placeholder makale → Dyt. imzalı gerçek içerik | D | içerik |
| Cihaz QA (docs/release_qa_checklist.md) | E+B | test |

## NEXT — Yayın Sonrası İlk Çeyrek (retention + topluluk tohumları)
1. **Push bildirim** (streak-koruma ile başla) — E · architecture:M
2. **Topluluk sekmesi v1**: elle girilen İstanbul etkinlik listesi + RSVP — E · Blueprint §3 primitifleriyle · architecture:L(ADR)
3. **İlk buluşma** (Sabah Rutini Yürüyüşü) + etkinlik-skinli vibe card — B(lojistik)+E(kod)+D(yüz)
4. Navigasyon geçişi: Takip→Sen birleşimi + merkez halka — E · ui+refactor
5. Analytics event sözlüğü + Beyza KPI panosu — E+B
6. Sosyal medya döngüsü başlangıcı (vibe card→repost) — D+B

## LATER — Vizyon Fazları (tetikleyiciye bağlı, tarihe değil)
- Ritüeller (stories yerine) · saat-uyumlu tema · yıllık özet (Wrapped)
  → tetik: NEXT-4 bitti + retention verisi var
- Circle v1 (tek şehir) → tetik: 2+ başarılı buluşma
- İlk merch (etkinlikte tek ürün) → tetik: buluşma talebi kanıtı
- Koç/creator piloti · ikinci şehir → tetik: Circle canlılığı + Blueprint §4 eşikleri
- Uluslararası (EN pazarı aktif pazarlama) → tetik: TR retention hedefi tutturuldu

## Kurallar
- NOW bitmeden NEXT'e kod yazılmaz (yayın > özellik).
- LATER'daki hiçbir iş tarihle değil tetikleyiciyle çekilir.
- Yeni fikir → önce bu dosyaya, sprint planında tartışılır; doğrudan koda gitmez.
