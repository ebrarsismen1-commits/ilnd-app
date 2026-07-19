import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

/// Ortak kart yakalama + paylaşma: RepaintBoundary'yi PNG'ye çevirip sistem
/// paylaşım sayfasına verir. Üç kart ekranı da (vibe/quote/streak) bunu
/// kullanır — capture mantığı tek yerde yaşar.
///
/// Başarıda true döner; boundary yoksa/encode başarısızsa false (çağıran
/// toast gösterir). Share sheet'in kendisinden fırlayan hatalar yukarı
/// taşınır — çağıranın catch'i karşılar.
Future<bool> shareCardCapture({
  required GlobalKey captureKey,
  required String text,
  required String fileName,
}) async {
  final boundary =
      captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return false;

  final image = await boundary.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return false;

  await Share.shareXFiles([
    XFile.fromData(
      byteData.buffer.asUint8List(),
      mimeType: 'image/png',
      name: fileName,
    ),
  ], text: text);
  return true;
}
