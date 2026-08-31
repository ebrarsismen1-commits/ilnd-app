import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';

/// Ada illüstrasyonu — topografik yön (owner kararı, 2026-08-26).
///
/// Handoff §7 üç katman istiyor: su / kara / öğe. Burada üçü de çizgi
/// diliyle kuruluyor — su eş yükselti halkaları, kara kıyı konturu, öğeler
/// harita işareti. Gerekçe metnin kendisi: "ada hafızanın haritası olur".
///
/// Kurallar:
/// - Hiç animasyon yok (Sert Kural #12). Su durgun; kazanılan öğe bir
///   sonraki açılışta yerinde durur, kıpırdamaz.
/// - Tek renk paletten gelir (Sert Kural #6); yeni hex yok, su tonları
///   `accentSoft` ile `water` arasında karıştırılır.
/// - Asset yok: her şey Path. Karanlık mod ayrı varyant istemez, ölçek
///   ayrı dosya istemez.
///
/// Çizim 362x330'luk sabit bir tasarım uzayında yapılır (prototipin Adan
/// ekranı ölçüsü) ve hedefe "cover" ile oturur: dar kartta alt kenar
/// korunur, üstten kırpılır. Ada her iki ölçekte de aynı yerde durur.
class IslandPainter extends CustomPainter {
  const IslandPainter({required this.state, required this.p});

  final IslandState state;
  final AppPalette p;

  static const double _designW = 362;
  static const double _designH = 330;

  /// Ölçeklemede genişliğin üst sınırı. Tasarım bir telefon tuvaline
  /// çizildi; bundan geniş kutularda ada büyümez, ortalanır.
  static const double _maxScaleWidth = 430;

  /// Kompozisyon düzeltmesi. Ham eğri prototipin yer tutucusundan geliyor
  /// ve 330'luk görünümde adayı çok aşağıda bırakıyordu: üst yarı boş
  /// gökyüzüydü. Ada bir bütün olarak büyütülüp yukarı alınır — kıyı, iç
  /// konturlar ve öğeler aynı dönüşümden geçtiği için hiçbiri diğerine
  /// göre kaymaz.
  static const double _lift = 40;
  static const double _grow = 1.22;
  static const Offset _pivot = Offset(181, 250);

  static Offset _place(double x, double y) => Offset(
    _pivot.dx + (x - _pivot.dx) * _grow,
    _pivot.dy + (y - _pivot.dy) * _grow - _lift,
  );

  /// Halkaların ve iç konturların ölçek merkezi — kompozisyondan sonraki
  /// ada merkezi.
  static final Offset _center = _place(182, 248);

  /// Öğelerin adadaki sabit yerleri: 40x48'lik yerel kutunun MERKEZİ, ham
  /// tasarım uzayında. Yer sabittir — kilitliyken kesik çizgili boşluk,
  /// kazanılınca aynı noktada öğenin kendisi. Ada büyürken hiçbir şey yer
  /// değiştirmez.
  static const _slots = <String, Offset>{
    'pine': Offset(112, 216),
    'lantern': Offset(166, 212),
    'oven': Offset(220, 226),
    'windrose': Offset(258, 236),
    'meetingStone': Offset(140, 266),
  };

  /// Ay gökyüzünde: adayla birlikte büyüyüp yukarı kaymaz, yoksa kadraj
  /// dışına çıkar. Bu yüzden yeri son koordinatta verilir.
  static const Offset _moonAt = Offset(298, 70);

  /// Kıyı çizgisi. Su halkaları ve iç konturlar bu tek eğrinin ölçeklenmiş
  /// kopyalarıdır — harita dili buradan geliyor, ayrı path'ten değil.
  static Path get _coast {
    final start = _place(46, 250);
    final path = Path()..moveTo(start.dx, start.dy);
    void curve(
      double ax,
      double ay,
      double bx,
      double by,
      double cx,
      double cy,
    ) {
      final a = _place(ax, ay);
      final b = _place(bx, by);
      final c = _place(cx, cy);
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    }

    curve(58, 218, 108, 202, 152, 204);
    curve(196, 206, 232, 194, 268, 208);
    curve(300, 220, 326, 238, 318, 256);
    curve(306, 282, 236, 292, 168, 292);
    curve(96, 292, 34, 278, 46, 250);
    return path..close();
  }

  /// Kartın zemini. Sessizlik arttıkça `accentSoft`ten `water`a doğru
  /// kayar — üç kademe, dördüncüsü yok (bkz. [WaterDepth]).
  ///
  /// Karışım oranı ölçümle sınırlandı: 0.20'de zemin `water` tokenına o
  /// kadar yaklaşıyordu ki aynı tokenla çizilen ay 2.77:1'e düşüyordu
  /// (gecede aynı yerde fener 2.80). Derinleşme işini asıl su halkaları
  /// yapar, zemin yalnız eşlik eder.
  static Color groundColor(AppPalette p, WaterDepth depth) =>
      Color.lerp(p.accentSoft, p.water, switch (depth) {
        WaterDepth.clear => 0.0,
        WaterDepth.deep => 0.07,
        WaterDepth.deepest => 0.13,
      })!;

  /// Su halkalarının koyuluğu. 0.32'de halka zemine karşı 1.43:1 çıkıyordu,
  /// yani çizgi vardı ama görünmüyordu; eşik `contrast_test`te kilitli.
  static double seaOpacity(WaterDepth depth) => switch (depth) {
    WaterDepth.clear => 0.5,
    WaterDepth.deep => 0.65,
    WaterDepth.deepest => 0.8,
  };

  /// Halka sayısı da sessizlikle artar: derinleşme yalnız renkte kalırsa
  /// küçük kartta hiç okunmuyor. Taban dört halka, çünkü su yalnız adanın
  /// çevresinde kalırsa kadrajın üstü boş bir alan gibi duruyor.
  ({int rings, double opacity}) get _sea => (
    rings: switch (state.water) {
      WaterDepth.clear => 4,
      WaterDepth.deep => 5,
      WaterDepth.deepest => 6,
    },
    opacity: seaOpacity(state.water),
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = groundColor(p, state.water),
    );
    if (size.isEmpty) return;

    // Ölçek hesabında genişlik bir referans telefon genişliğiyle sınırlanır.
    // Sınır olmadan geniş bir kutuda (masaüstü web'de kart tam genişlik,
    // ~1700px) genişlik oranı yüksekliğinkini 4-5 kat aşıyor, tasarım o
    // oranda büyüyor ve görünen tek şey kıyı konturunun devasa, yayvan bir
    // dilimi oluyordu. Telefon genişliklerinde sınır hiç devreye girmez,
    // yani mobil görünüm birebir aynı kalır.
    final effectiveWidth = math.min(size.width, _maxScaleWidth);
    final scale = math.max(effectiveWidth / _designW, size.height / _designH);

    canvas.save();
    // Yatayda GERÇEK genişliğe göre ortala (zemin tüm kutuyu doldurur),
    // dikeyde alta yasla: kırpma üstten olur, ada ve kıyı her ölçekte
    // tam görünür.
    canvas.translate(
      (size.width - _designW * scale) / 2,
      size.height - _designH * scale,
    );
    canvas.scale(scale);

    _paintSea(canvas, scale);
    _paintLand(canvas, scale);
    _paintItems(canvas, scale);

    canvas.restore();
  }

  /// Kıyıdan dışa açılan eş yükselti halkaları.
  void _paintSea(Canvas canvas, double scale) {
    const factors = [1.14, 1.3, 1.48, 1.7, 1.95, 2.24];
    final sea = _sea;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = p.water.withValues(alpha: sea.opacity);

    for (final f in factors.take(sea.rings)) {
      _scaled(canvas, f, () {
        // Çizgi kalınlığı hem hedef ölçekle hem halka ölçeğiyle bölünür,
        // yoksa dıştaki halkalar kalınlaşır ve kıyıyı bastırır.
        paint.strokeWidth = 1.0 / (scale * f);
        canvas.drawPath(_coast, paint);
      });
    }
  }

  /// Kara: hafif dolgu + kıyı konturu + iki iç eş yükselti.
  void _paintLand(Canvas canvas, double scale) {
    canvas.drawPath(
      _coast,
      Paint()..color = p.accent.withValues(alpha: p.isDark ? 0.16 : 0.10),
    );
    canvas.drawPath(
      _coast,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 / scale
        ..color = p.accent,
    );

    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..color = p.accent.withValues(alpha: 0.5);
    for (final f in const [0.74, 0.48]) {
      _scaled(canvas, f, () {
        inner.strokeWidth = 1.0 / (scale * f);
        canvas.drawPath(_coast, inner);
      });
    }
  }

  void _paintItems(Canvas canvas, double scale) {
    // Öğeler de adayla aynı oranda büyür, yoksa büyüyen adanın üstünde
    // küçük kalırlar.
    final k = scale * _grow;
    Paint stroke(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width / k
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;

    final line = stroke(p.accent, 1.8);
    final amber = stroke(p.amber, 1.8);
    // Ay `water` tokenıyla çizilmişti; zemin sessiz günlerde aynı tokena
    // doğru kaydığı için ikisi 2.99:1'e kadar yaklaşıyordu — yani ay, tam
    // da görünmesi gereken günlerde kayboluyordu. Mürekkep rengi hem çizgi
    // diline uyuyor hem zeminden bağımsız.
    final moon = stroke(p.text, 1.6);
    final locked = stroke(p.textMuted, 1.4);

    for (final item in kIslandItems) {
      final center = item.id == 'moonlight'
          ? _moonAt
          : (_slots[item.id] == null
                ? null
                : _place(_slots[item.id]!.dx, _slots[item.id]!.dy));
      if (center == null) continue;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(_grow);
      canvas.translate(-20, -24); // yerel 40x48 kutunun merkezi
      if (state.has(item.id)) {
        _drawItem(canvas, item.id, line, amber, moon);
      } else {
        // Kilitli öğe adada boş yer olarak durur (owner kararı): "burada
        // büyüyecek bir şey var" der, eksiklik değil.
        _dashedCircle(canvas, const Offset(20, 24), 15, locked);
      }
      canvas.restore();
    }
  }

  /// Öğe çizimleri — hepsi 40x48'lik yerel kutuda, sol üst köşe (0,0).
  void _drawItem(
    Canvas canvas,
    String id,
    Paint line,
    Paint amber,
    Paint moon,
  ) {
    switch (id) {
      case 'pine':
        canvas.drawPath(_polygon(const [(20, 4), (30, 23), (10, 23)]), line);
        canvas.drawPath(_polygon(const [(20, 16), (33, 37), (7, 37)]), line);
        canvas.drawLine(const Offset(20, 37), const Offset(20, 46), line);
      case 'lantern':
        canvas.drawLine(const Offset(20, 25), const Offset(20, 46), line);
        canvas.drawLine(const Offset(13, 46), const Offset(27, 46), line);
        canvas.drawPath(
          Path()
            ..moveTo(11, 10.5)
            ..lineTo(20, 3.5)
            ..lineTo(29, 10.5),
          line,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(13.5, 10.5, 13, 14),
            const Radius.circular(2.5),
          ),
          amber,
        );
        // İki kısa ışık çizgisi: bunlar olmadan siluet fener değil,
        // tabela okunuyordu.
        canvas.drawLine(const Offset(7, 17.5), const Offset(10, 17.5), amber);
        canvas.drawLine(const Offset(30, 17.5), const Offset(33, 17.5), amber);
      case 'oven':
        canvas.drawPath(
          Path()
            ..moveTo(6, 44)
            ..arcToPoint(
              const Offset(34, 44),
              radius: const Radius.circular(14),
            )
            ..close(),
          line,
        );
        // Baca kubbenin omzunda oturur: bacaklar kubbe yüzeyine DEĞDİĞİ
        // yerde biter (x=26'da y≈31.4, x=31'de y≈35.3). Daha aşağı
        // inerse kubbenin içine giriyor, daha yukarıda kalırsa havada
        // asılı duruyor — ikisini de yaşadık.
        canvas.drawPath(
          Path()
            ..moveTo(26, 31.4)
            ..lineTo(26, 20)
            ..lineTo(31, 20)
            ..lineTo(31, 35.3),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(14, 44)
            ..arcToPoint(
              const Offset(26, 44),
              radius: const Radius.circular(6),
            ),
          amber,
        );
      case 'windrose':
        canvas.drawPath(
          _polygon(const [
            (20, 3),
            (23.5, 20.5),
            (38, 24),
            (23.5, 27.5),
            (20, 45),
            (16.5, 27.5),
            (2, 24),
            (16.5, 20.5),
          ]),
          line,
        );
        canvas.drawCircle(const Offset(20, 24), 3.6, line);
      case 'moonlight':
        // Hilalin iç yayı DIŞ yaydan daha büyük yarıçapta olmalı: küçük
        // yarıçap veriliyordu, Flutter onu kirişe sığdırmak için büyütüyor
        // ve iki yay üst üste binip tek bir "C" çıkıyordu.
        canvas.drawPath(
          Path()
            ..moveTo(28, 7)
            ..arcToPoint(
              const Offset(28, 41),
              radius: const Radius.circular(17),
              clockwise: false,
            )
            ..arcToPoint(const Offset(28, 7), radius: const Radius.circular(26))
            ..close(),
          moon,
        );
      case 'meetingStone':
        // Taşlar kuş bakışı — haritada bir yer, ayakta duran nesne değil.
        canvas.drawCircle(const Offset(12, 20), 6, line);
        canvas.drawCircle(const Offset(27, 17), 5, line);
        canvas.drawCircle(const Offset(20, 33), 7, line);
    }
  }

  /// Ada merkezine göre ölçekli çizim — halkalar ve iç konturlar için.
  void _scaled(Canvas canvas, double factor, VoidCallback draw) {
    canvas.save();
    canvas.translate(_center.dx, _center.dy);
    canvas.scale(factor);
    canvas.translate(-_center.dx, -_center.dy);
    draw();
    canvas.restore();
  }

  static Path _polygon(List<(double, double)> points) {
    final path = Path()..moveTo(points.first.$1, points.first.$2);
    for (final (x, y) in points.skip(1)) {
      path.lineTo(x, y);
    }
    return path..close();
  }

  static void _dashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    const segments = 14;
    const gapRatio = 0.4;
    const sweep = 2 * math.pi / segments;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < segments; i++) {
      canvas.drawArc(rect, i * sweep, sweep * (1 - gapRatio), false, paint);
    }
  }

  @override
  bool shouldRepaint(IslandPainter old) =>
      old.p != p ||
      old.state.water != state.water ||
      !setEquals(old.state.earned, state.earned);
}
