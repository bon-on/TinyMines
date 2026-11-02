import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'garden_palette.dart';

/// Static garden backdrop: sky, sun or moon, clouds, rolling hills, a picket
/// fence and bushes, with theme touches (blossoms, leaves, snow, fireflies).
/// Painted once per size or theme; it never animates.
class GardenScenery extends StatelessWidget {
  const GardenScenery({super.key, required this.palette});

  final GardenPalette palette;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: GardenSceneryPainter(palette),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class GardenSceneryPainter extends CustomPainter {
  const GardenSceneryPainter(this.p);

  final GardenPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.skyTop, p.skyBottom],
        ).createShader(rect),
    );
    final unit = math.min(w, h);
    final rng = math.Random(42);

    if (p.isNight) {
      // Stars.
      for (var i = 0; i < 70; i++) {
        final pos = Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.55);
        final r = 0.6 + rng.nextDouble() * 1.4;
        canvas.drawCircle(
          pos,
          r,
          Paint()
            ..color = const Color(
              0xFFFFFFFF,
            ).withValues(alpha: 0.4 + 0.5 * rng.nextDouble()),
        );
      }
      // Moon with a crescent bite and a glow.
      final moon = Offset(w * 0.82, h * 0.16);
      final mr = unit * 0.07;
      canvas.drawCircle(
        moon,
        mr * 2.2,
        Paint()..color = p.sun.withValues(alpha: 0.08),
      );
      canvas.drawCircle(
        moon,
        mr * 1.5,
        Paint()..color = p.sun.withValues(alpha: 0.12),
      );
      canvas.drawCircle(moon, mr, Paint()..color = p.sun);
      canvas.drawCircle(
        moon + Offset(mr * 0.45, -mr * 0.25),
        mr * 0.85,
        Paint()..color = p.skyTop.withValues(alpha: 0.9),
      );
    } else {
      final sun = Offset(w * 0.84, h * 0.15);
      final sr = unit * 0.075;
      canvas.drawCircle(
        sun,
        sr * 2.1,
        Paint()..color = p.sun.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        sun,
        sr * 1.45,
        Paint()..color = p.sun.withValues(alpha: 0.3),
      );
      canvas.drawCircle(sun, sr, Paint()..color = p.sun);
    }

    // Clouds.
    final cloud = Paint()
      ..color = p.cloud.withValues(alpha: p.isNight ? 0.35 : 0.9);
    for (final c in const [
      Offset(0.14, 0.12),
      Offset(0.45, 0.07),
      Offset(0.64, 0.22),
      Offset(0.28, 0.3),
    ]) {
      _cloud(canvas, Offset(c.dx * w, c.dy * h), unit * 0.05, cloud);
    }

    // Hills, far to near.
    _hill(canvas, size, 0.58, 0.05, 1.3, p.hillFar, 0.3);
    _hill(canvas, size, 0.68, 0.06, 1.9, p.hillMid, 1.4);
    if (p.isFrost) {
      _hill(
        canvas,
        size,
        0.585,
        0.05,
        1.3,
        const Color(0x66FFFFFF),
        0.3,
        band: 0.015,
      );
    }

    // Picket fence along the near hill.
    final fenceY = h * 0.74;
    final post = Paint()..color = p.fence;
    final postShadow = Paint()..color = p.fence.withValues(alpha: 0.5);
    final postW = unit * 0.022;
    final gap = postW * 2.6;
    canvas.drawRect(
      Rect.fromLTWH(0, fenceY + postW * 1.4, w, postW * 0.7),
      postShadow,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, fenceY + postW * 3.2, w, postW * 0.7),
      postShadow,
    );
    for (var x = gap * 0.3; x < w; x += gap) {
      final top = fenceY;
      final path = Path()
        ..moveTo(x, top + postW * 0.7)
        ..lineTo(x + postW / 2, top)
        ..lineTo(x + postW, top + postW * 0.7)
        ..lineTo(x + postW, top + postW * 5)
        ..lineTo(x, top + postW * 5)
        ..close();
      canvas.drawPath(path, post);
    }

    _hill(canvas, size, 0.8, 0.04, 2.6, p.hillNear, 2.2);
    if (p.isFrost) {
      _hill(
        canvas,
        size,
        0.805,
        0.04,
        2.6,
        const Color(0xCCFFFFFF),
        2.2,
        band: 0.02,
      );
    }

    // Bushes in the corners and along the bottom.
    for (final b in const [
      Offset(0.04, 0.9),
      Offset(0.13, 0.95),
      Offset(0.9, 0.92),
      Offset(0.98, 0.88),
      Offset(0.55, 1.0),
    ]) {
      _bush(canvas, Offset(b.dx * w, b.dy * h), unit * 0.09, rng);
    }

    // Theme decoration floating over the scene.
    final decor = Paint()..color = p.decor;
    if (p.isNight) {
      for (var i = 0; i < 26; i++) {
        final pos = Offset(
          rng.nextDouble() * w,
          h * (0.45 + rng.nextDouble() * 0.5),
        );
        canvas.drawCircle(
          pos,
          unit * 0.012,
          Paint()..color = p.decor.withValues(alpha: 0.18),
        );
        canvas.drawCircle(pos, unit * 0.004, decor);
      }
    } else if (p.isFrost) {
      for (var i = 0; i < 60; i++) {
        final pos = Offset(rng.nextDouble() * w, rng.nextDouble() * h);
        canvas.drawCircle(
          pos,
          unit * (0.003 + rng.nextDouble() * 0.005),
          Paint()..color = const Color(0xCCFFFFFF),
        );
      }
    } else {
      // Petals (spring) or leaves (autumn) drifting.
      for (var i = 0; i < 22; i++) {
        final pos = Offset(
          rng.nextDouble() * w,
          h * (0.15 + rng.nextDouble() * 0.8),
        );
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(rng.nextDouble() * math.pi);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: unit * 0.018,
            height: unit * 0.01,
          ),
          Paint()..color = p.decor.withValues(alpha: 0.75),
        );
        canvas.restore();
      }
    }
  }

  void _cloud(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawCircle(c, r, paint);
    canvas.drawCircle(c + Offset(r * 0.9, r * 0.25), r * 0.75, paint);
    canvas.drawCircle(c + Offset(-r * 0.9, r * 0.3), r * 0.65, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          c.dx - r * 1.5,
          c.dy + r * 0.1,
          c.dx + r * 1.6,
          c.dy + r * 0.85,
        ),
        Radius.circular(r * 0.4),
      ),
      paint,
    );
  }

  void _hill(
    Canvas canvas,
    Size size,
    double baseY,
    double amp,
    double waves,
    Color color,
    double phase, {
    double? band,
  }) {
    final w = size.width;
    final h = size.height;
    final path = Path()..moveTo(0, h);
    const steps = 48;
    for (var i = 0; i <= steps; i++) {
      final x = w * i / steps;
      final y =
          h * (baseY - amp * math.sin(phase + waves * math.pi * i / steps));
      if (i == 0) {
        path.lineTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    if (band != null) {
      // Only a thin strip along the ridge (snow cap).
      for (var i = steps; i >= 0; i--) {
        final x = w * i / steps;
        final y =
            h *
            (baseY +
                band -
                amp * math.sin(phase + waves * math.pi * i / steps));
        path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(
        path..fillType = PathFillType.nonZero,
        Paint()..color = color,
      );
      return;
    }
    path
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _bush(Canvas canvas, Offset c, double r, math.Random rng) {
    final dark = Paint()..color = p.bushDark;
    final light = Paint()..color = p.bush;
    canvas.drawCircle(c + Offset(-r * 0.6, r * 0.1), r * 0.7, dark);
    canvas.drawCircle(c + Offset(r * 0.6, r * 0.15), r * 0.65, dark);
    canvas.drawCircle(c, r, light);
    canvas.drawCircle(c + Offset(-r * 0.7, r * 0.3), r * 0.6, light);
    canvas.drawCircle(c + Offset(r * 0.7, r * 0.35), r * 0.55, light);
    canvas.drawCircle(
      c + Offset(-r * 0.3, -r * 0.35),
      r * 0.35,
      Paint()..color = const Color(0x22FFFFFF),
    );
    if (p.isFrost) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(0, -r * 0.75),
          width: r * 1.3,
          height: r * 0.5,
        ),
        Paint()..color = const Color(0xEEFFFFFF),
      );
      return;
    }
    final blossom = Paint()
      ..color = p.isNight ? p.decor.withValues(alpha: 0.8) : p.petal;
    for (var i = 0; i < 5; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final d = rng.nextDouble() * r * 0.8;
      final pos = c + Offset(math.cos(a), math.sin(a)) * d;
      canvas.drawCircle(pos, r * 0.1, blossom);
      canvas.drawCircle(pos, r * 0.04, Paint()..color = p.flowerCenter);
    }
  }

  @override
  bool shouldRepaint(GardenSceneryPainter old) => old.p != p;
}
