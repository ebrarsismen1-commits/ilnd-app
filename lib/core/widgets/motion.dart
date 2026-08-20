import 'package:flutter/material.dart';

/// Kullanıcı "hareketi azalt" dediyse animasyon oynatılmaz.
///
/// Erişilebilirlik gereği (Apple HIG, Material): vestibüler rahatsızlığı olan
/// kullanıcılar için kayan/ölçeklenen arayüz baş dönmesi yapar. Sistem ayarı
/// iOS'ta Ayarlar → Erişilebilirlik → Hareket, Android'de Geliştirici/
/// Erişilebilirlik → animasyon ölçeği; web'de `prefers-reduced-motion`.
/// Flutter bunların üçünü de [MediaQueryData.disableAnimations] altında
/// birleştirir.
///
/// Kural: sürekli/dekoratif hareket **tamamen durur**; bilgi taşıyan geçişler
/// (ekran değişimi gibi) durmaz, çünkü onlar mekânsal bağlamı anlatır.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Hareket azaltılmışsa [reduced], değilse [full] süresi.
///
/// Sıfır süre = animasyon yok ama widget ağacı aynı kalır; böylece "azaltılmış
/// mod" ayrı bir kod yolu açmaz, yalnız süreyi kısar.
Duration motionDuration(
  BuildContext context, {
  required Duration full,
  Duration reduced = Duration.zero,
}) => prefersReducedMotion(context) ? reduced : full;
