import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../meta/garden_plots.dart';
import 'garden_palette.dart';

/// Paints one garden plot (feature-garden-collection): a soil bed with the
/// plot's decoration, all drawn in code. Pure painting, no animation.
class PlotPainter extends CustomPainter {
  const PlotPainter({required this.plot, required this.palette});

  final GardenPlot plot;
  final GardenPalette palette;

  static const Color _leaf = Color(0xFF4E9A3C);
  static const Color _leafDark = Color(0xFF357A2B);
  static const Color _stem = Color(0xFF3F7F34);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s / 100);
    _bed(canvas);
    switch (plot) {
      case GardenPlot.sprouts:
        _sprouts(canvas);
      case GardenPlot.tulips:
        _tulips(canvas);
      case GardenPlot.roseArch:
        _roseArch(canvas);
      case GardenPlot.sunflowers:
        _sunflowers(canvas);
      case GardenPlot.mushrooms:
        _mushrooms(canvas);
      case GardenPlot.lilyPond:
        _lilyPond(canvas);
      case GardenPlot.berryBush:
        _berryBush(canvas);
      case GardenPlot.birdBath:
        _birdBath(canvas);
    }
    canvas.restore();
  }

  Paint _fill(Color color) => Paint()..color = color;

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  void _bed(Canvas canvas) {
    final grass = RRect.fromLTRBR(4, 52, 96, 96, const Radius.circular(18));
    canvas.drawRRect(grass, _fill(palette.grassBottom));
    canvas.drawRRect(
      RRect.fromLTRBR(4, 50, 96, 90, const Radius.circular(18)),
      _fill(palette.grassTop),
    );
    final soil = RRect.fromLTRBR(14, 58, 86, 86, const Radius.circular(14));
    canvas.drawRRect(soil, _fill(palette.soilDark));
    canvas.drawRRect(
      RRect.fromLTRBR(16, 58, 84, 82, const Radius.circular(12)),
      _fill(palette.soil),
    );
    final speck = _fill(palette.soilSpeck);
    for (final (x, y) in const [(26.0, 66.0), (48.0, 74.0), (70.0, 64.0)]) {
      canvas.drawCircle(Offset(x, y), 1.8, speck);
    }
  }

  void _leafAt(Canvas canvas, Offset base, double angle, double length) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(length * 0.5, -length * 0.45, length, 0)
      ..quadraticBezierTo(length * 0.5, length * 0.45, 0, 0);
    canvas.drawPath(path, _fill(_leaf));
    canvas.restore();
  }

  void _sprouts(Canvas canvas) {
    for (final x in const [30.0, 50.0, 70.0]) {
      final top = x == 50 ? 44.0 : 50.0;
      canvas.drawLine(Offset(x, 72), Offset(x, top), _stroke(_stem, 3));
      _leafAt(canvas, Offset(x, top + 4), -2.4, 13);
      _leafAt(canvas, Offset(x, top + 4), -0.7, 13);
    }
  }

  void _tulip(Canvas canvas, double x, double top, Color color) {
    canvas.drawLine(Offset(x, 74), Offset(x, top + 8), _stroke(_stem, 3));
    _leafAt(canvas, Offset(x, 68), -2.2, 12);
    final cup = Path()
      ..moveTo(x - 8, top)
      ..lineTo(x - 4, top + 4)
      ..lineTo(x, top - 1)
      ..lineTo(x + 4, top + 4)
      ..lineTo(x + 8, top)
      ..quadraticBezierTo(x + 9, top + 12, x, top + 12)
      ..quadraticBezierTo(x - 9, top + 12, x - 8, top)
      ..close();
    canvas.drawPath(cup, _fill(color));
  }

  void _tulips(Canvas canvas) {
    _tulip(canvas, 28, 40, palette.petal);
    _tulip(canvas, 50, 32, const Color(0xFFE8574A));
    _tulip(canvas, 72, 40, palette.petalAlt);
  }

  void _rose(Canvas canvas, Offset c, Color color) {
    canvas.drawCircle(c, 6, _fill(color));
    canvas.drawCircle(
      c,
      3.2,
      _fill(Color.lerp(color, const Color(0xFF000000), 0.2)!),
    );
  }

  void _roseArch(Canvas canvas) {
    final wood = Color.lerp(palette.fence, const Color(0xFF8A5A33), 0.5)!;
    final arch = Rect.fromLTRB(22, 18, 78, 90);
    canvas.drawArc(arch, math.pi, math.pi, false, _stroke(wood, 6));
    canvas.drawLine(
      const Offset(22, 54),
      const Offset(22, 80),
      _stroke(wood, 6),
    );
    canvas.drawLine(
      const Offset(78, 54),
      const Offset(78, 80),
      _stroke(wood, 6),
    );
    for (var i = 0; i < 7; i++) {
      final a = math.pi + math.pi * i / 6;
      final c = Offset(50 + 28 * math.cos(a), 54 + 36 * math.sin(a));
      _leafAt(canvas, c, a + 1.2, 8);
      _rose(canvas, c, i.isEven ? const Color(0xFFE2465F) : palette.petal);
    }
  }

  void _sunflower(Canvas canvas, double x, double top, double r) {
    canvas.drawLine(Offset(x, 76), Offset(x, top + r), _stroke(_stem, 3.5));
    _leafAt(canvas, Offset(x, 66), -2.5, 13);
    _leafAt(canvas, Offset(x, 60), -0.6, 12);
    final petal = _fill(const Color(0xFFF7C531));
    for (var i = 0; i < 10; i++) {
      final a = 2 * math.pi * i / 10;
      canvas.drawCircle(
        Offset(x + r * 0.95 * math.cos(a), top + r * 0.95 * math.sin(a)),
        r * 0.42,
        petal,
      );
    }
    canvas.drawCircle(Offset(x, top), r * 0.62, _fill(const Color(0xFF7A4A1E)));
    canvas.drawCircle(
      Offset(x - r * 0.15, top - r * 0.15),
      r * 0.2,
      _fill(const Color(0xFF9C6532)),
    );
  }

  void _sunflowers(Canvas canvas) {
    _sunflower(canvas, 34, 34, 9);
    _sunflower(canvas, 66, 26, 11);
  }

  void _mushroom(Canvas canvas, double x, double y, double s) {
    canvas.drawRRect(
      RRect.fromLTRBR(
        x - s * 0.3,
        y - s * 0.2,
        x + s * 0.3,
        y + s * 0.7,
        Radius.circular(s * 0.2),
      ),
      _fill(const Color(0xFFF5EBD8)),
    );
    final cap = Path()
      ..moveTo(x - s, y)
      ..quadraticBezierTo(x - s, y - s * 1.1, x, y - s * 1.1)
      ..quadraticBezierTo(x + s, y - s * 1.1, x + s, y)
      ..close();
    canvas.drawPath(cap, _fill(const Color(0xFFD9432F)));
    final dot = _fill(const Color(0xFFFFFFFF));
    canvas.drawCircle(Offset(x - s * 0.4, y - s * 0.45), s * 0.17, dot);
    canvas.drawCircle(Offset(x + s * 0.3, y - s * 0.7), s * 0.14, dot);
    canvas.drawCircle(Offset(x + s * 0.55, y - s * 0.2), s * 0.12, dot);
  }

  void _mushrooms(Canvas canvas) {
    _mushroom(canvas, 28, 66, 8);
    _mushroom(canvas, 50, 58, 11);
    _mushroom(canvas, 72, 66, 8);
    _mushroom(canvas, 39, 76, 6);
    _mushroom(canvas, 62, 77, 6);
  }

  void _lilyPond(Canvas canvas) {
    final rim = Rect.fromCenter(
      center: const Offset(50, 64),
      width: 74,
      height: 34,
    );
    canvas.drawOval(rim.inflate(3), _fill(const Color(0xFFB9AE9C)));
    canvas.drawOval(rim, _fill(const Color(0xFF4FA6D8)));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(44, 60), width: 40, height: 12),
      _fill(const Color(0xFF7CC4EA)),
    );
    final pad = _fill(_leaf);
    for (final (x, y, r) in const [
      (32.0, 66.0, 7.0),
      (62.0, 70.0, 8.0),
      (58.0, 56.0, 5.5),
    ]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(x, y), radius: r),
        0.5,
        2 * math.pi - 1.0,
        true,
        pad,
      );
    }
    final bloom = _fill(palette.petal);
    for (var i = 0; i < 6; i++) {
      final a = 2 * math.pi * i / 6;
      canvas.drawCircle(
        Offset(62 + 3.5 * math.cos(a), 68 + 3.5 * math.sin(a)),
        2.6,
        bloom,
      );
    }
    canvas.drawCircle(const Offset(62, 68), 2, _fill(palette.flowerCenter));
  }

  void _berryBush(Canvas canvas) {
    final dark = _fill(_leafDark);
    final light = _fill(_leaf);
    for (final (x, y, r) in const [
      (34.0, 58.0, 16.0),
      (66.0, 58.0, 16.0),
      (50.0, 46.0, 18.0),
    ]) {
      canvas.drawCircle(Offset(x, y + 2), r, dark);
      canvas.drawCircle(Offset(x - 1, y), r - 2, light);
    }
    for (final (x, y, c) in const [
      (30.0, 54.0, Color(0xFFC0304A)),
      (42.0, 44.0, Color(0xFF5B3A8C)),
      (55.0, 38.0, Color(0xFFC0304A)),
      (62.0, 52.0, Color(0xFF5B3A8C)),
      (72.0, 60.0, Color(0xFFC0304A)),
      (48.0, 58.0, Color(0xFFC0304A)),
      (38.0, 64.0, Color(0xFF5B3A8C)),
    ]) {
      canvas.drawCircle(Offset(x, y), 3.6, _fill(c));
      canvas.drawCircle(
        Offset(x - 1, y - 1.2),
        1.1,
        _fill(const Color(0xAAFFFFFF)),
      );
    }
  }

  void _birdBath(Canvas canvas) {
    const stone = Color(0xFFBDB6AA);
    const stoneDark = Color(0xFF948B7E);
    canvas.drawRRect(
      RRect.fromLTRBR(40, 70, 60, 78, const Radius.circular(3)),
      _fill(stoneDark),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(45, 46, 55, 72, const Radius.circular(3)),
      _fill(stone),
    );
    final bowl = Path()
      ..moveTo(22, 40)
      ..lineTo(78, 40)
      ..quadraticBezierTo(74, 52, 50, 52)
      ..quadraticBezierTo(26, 52, 22, 40)
      ..close();
    canvas.drawPath(bowl, _fill(stone));
    canvas.drawOval(Rect.fromLTRB(24, 36, 76, 44), _fill(stoneDark));
    canvas.drawOval(
      Rect.fromLTRB(27, 37, 73, 43),
      _fill(const Color(0xFF6DB8E2)),
    );
    // A small bird on the rim.
    const bird = Color(0xFF4F7FC0);
    canvas.drawOval(Rect.fromLTRB(56, 24, 72, 36), _fill(bird));
    canvas.drawCircle(const Offset(71, 25), 5, _fill(bird));
    canvas.drawCircle(
      const Offset(72.5, 24),
      1.2,
      _fill(const Color(0xFF1E1E1E)),
    );
    final beak = Path()
      ..moveTo(75.5, 24.5)
      ..lineTo(80, 26)
      ..lineTo(75.5, 27)
      ..close();
    canvas.drawPath(beak, _fill(const Color(0xFFF2A33A)));
    canvas.drawOval(
      Rect.fromLTRB(58, 27, 66, 33),
      _fill(const Color(0xFF86A9DA)),
    );
  }

  @override
  bool shouldRepaint(PlotPainter old) =>
      old.plot != plot || old.palette != palette;
}
