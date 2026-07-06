---
name: perf
description: Performans işleri. Ölçüm-önce disiplini — kanıtlanmamış soruna optimizasyon yapılmaz.
---

# perf — Ölçüm-Önce Optimizasyon

## Demir Kural
Ölçemediğin şeyi optimize etme. Kanıt yoksa iş yok; "muhtemelen yavaştır" bir
bulgu değildir. Kanıt kaynakları: DevTools timeline/memory (cihazda kullanıcı
koşar, sen yorumlarsın), yapısal kanıt (kod okumasıyla gösterilebilir gereksiz
iş — örn. child-pass-through eksikliği), APK boyut raporu.

## Şüpheli Sıralaması (önce en ucuz teşhis)
1. **Rebuild** — `ref.watch` kapsamı geniş mi? `select` kullanılabilir mi?
   Provider zinciri gereksiz derinlikte mi?
2. **Repaint** — sürekli animasyon + içerik aynı katmanda mı? (`RepaintBoundary`,
   `AnimatedBuilder(child:)` pass-through — AnimatedBackground'da uygulanmış desen)
3. **Liste** — builder/sliver mı, yoksa Column+shrinkWrap mi?
4. **Görsel** — decode boyutu sınırlı mı (URL `w=` paramı / cacheWidth)?
5. **Başlangıç** — main()'de sıralı await'lerden hangileri gerçekten sıralı olmalı?
6. **Boyut** — yayında AAB (APK değil); minify AÇILACAKSA cihaz smoke testi şart.

## Akış
1. Kanıtı yaz (rapora): ne, nerede, nasıl ölçüldü/gösterildi
2. Tek değişiklik yap → davranış aynı mı (Kapı) → kanıt tekrar: iyileşme var mı?
3. İyileşme gösterilemiyorsa geri al — "zararı yok" yeterli değil, karmaşıklık maliyettir.

## Yasak
- Tasarım kararlarını (nefes animasyonu gibi) perf bahanesiyle sessizce kaldırmak —
  maliyetliyse raporla, karar kullanıcının.

## Definition of Done
- [ ] Kanıt-öncesi ve kanıt-sonrası raporda; iyileşme gösterildi (yoksa geri alındı)
- [ ] Davranış değişmedi (Kapı yeşil)
