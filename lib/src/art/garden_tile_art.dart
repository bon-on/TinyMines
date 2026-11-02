import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'garden_palette.dart';

/// What one board cell shows. Derived from the cell state by the screen.
enum TileLook {
  /// Unrevealed: a grass tuft.
  covered,

  /// Unrevealed with a flag.
  flagged,

  /// After a loss: a flag that was on a safe tile.
  wrongFlag,

  /// Revealed safe soil; the number comes separately.
  soil,

  /// After a loss: a sleepy mole in its burrow.
  mole,

  /// The mole that was dug up (the losing move).
  moleHit,

  /// After a loss: a correctly flagged mole.
  flaggedMole,

  /// After a win: a mine cell blooms into a flower.
  flower,
}

/// Code-drawn garden tiles. Every function paints into [rect] only, so the
/// board, the effects layer and the tutorial share the exact same art.
class GardenTileArt {
  const GardenTileArt._();

  /// Paints one cell. [nearby] is the number shown on [TileLook.soil];
  /// [seed] varies grass blades and soil specks per cell.
  static void paint(
    Canvas canvas,
    Rect rect,
    GardenPalette palette,
    TileLook look, {
    int nearby = 0,
    int seed = 0,
  }) {
    switch (look) {
      case TileLook.covered:
        paintCovered(canvas, rect, palette, seed);
      case TileLook.flagged:
        paintCovered(canvas, rect, palette, seed);
        paintFlag(canvas, rect, palette);
      case TileLook.wrongFlag:
        paintSoil(canvas, rect, palette, seed);
        paintFlag(canvas, rect, palette, faded: true);
        paintCross(canvas, rect, palette.danger);
      case TileLook.soil:
        paintSoil(canvas, rect, palette, seed);
        if (nearby > 0) paintPebble(canvas, rect, palette, nearby);
      case TileLook.mole:
        paintSoil(canvas, rect, palette, seed);
        paintMole(canvas, rect, palette);
      case TileLook.moleHit:
        paintSoil(canvas, rect, palette, seed, hit: true);
        paintMole(canvas, rect, palette, hit: true);
      case TileLook.flaggedMole:
        paintCovered(canvas, rect, palette, seed);
        paintFlag(canvas, rect, palette);
      case TileLook.flower:
        paintCovered(canvas, rect, palette, seed);
        paintFlower(canvas, rect, palette, seed: seed);
    }
  }

  static double _radius(Rect r) => r.shortestSide * 0.2;

  /// A rounded tuft of grass with blades along the top and a darker lip.
  static void paintCovered(
    Canvas canvas,
    Rect rect,
    GardenPalette p,
    int seed, {
    double lift = 0,
  }) {
    final s = rect.shortestSide;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(_radius(rect)));
    // Lip (the tile's side), then the face shifted up.
    canvas.drawRRect(rr, Paint()..color = p.grassShadow);
    final face = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        rect.left,
        rect.top - lift,
        rect.right,
        rect.bottom - s * 0.09 - lift,
      ),
      Radius.circular(_radius(rect)),
    );
    canvas.drawRRect(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.grassTop, p.grassBottom],
        ).createShader(face.outerRect),
    );
    // Soft highlight on the upper left.
    canvas.drawOval(
      Rect.fromLTWH(
        face.left + s * 0.14,
        face.top + s * 0.12,
        s * 0.34,
        s * 0.16,
      ),
      Paint()..color = const Color(0x33FFFFFF),
    );
    // Grass blades: a few tapered strokes, varied per cell.
    final rng = math.Random(seed * 7919 + 17);
    final blade = Paint()
      ..color = p.grassBlade
      ..style = PaintingStyle.fill;
    final count = 3 + rng.nextInt(2);
    for (var i = 0; i < count; i++) {
      final x =
          face.left + s * (0.2 + 0.6 * (i + rng.nextDouble() * 0.6) / count);
      final baseY = face.top + s * (0.5 + rng.nextDouble() * 0.22);
      final h = s * (0.16 + rng.nextDouble() * 0.12);
      final lean = (rng.nextDouble() - 0.5) * s * 0.12;
      final w = s * 0.045;
      final path = Path()
        ..moveTo(x - w, baseY)
        ..quadraticBezierTo(
          x - w * 0.2 + lean * 0.4,
          baseY - h * 0.6,
          x + lean,
          baseY - h,
        )
        ..quadraticBezierTo(
          x + w * 0.6 + lean * 0.4,
          baseY - h * 0.5,
          x + w,
          baseY,
        )
        ..close();
      canvas.drawPath(path, blade);
    }
    // Theme sprinkles: a bud in spring, a leaf in autumn, a firefly at night.
    if (p.isFrost) {
      final cap = Path()
        ..moveTo(face.left + s * 0.06, face.top + s * 0.2)
        ..quadraticBezierTo(face.left, face.top, face.left + s * 0.22, face.top)
        ..lineTo(face.right - s * 0.22, face.top)
        ..quadraticBezierTo(
          face.right,
          face.top,
          face.right - s * 0.06,
          face.top + s * 0.2,
        )
        ..quadraticBezierTo(
          face.right - s * 0.2,
          face.top + s * 0.3,
          face.center.dx + s * 0.08,
          face.top + s * 0.2,
        )
        ..quadraticBezierTo(
          face.center.dx - s * 0.05,
          face.top + s * 0.32,
          face.left + s * 0.16,
          face.top + s * 0.24,
        )
        ..close();
      canvas.drawPath(cap, Paint()..color = const Color(0xF2FFFFFF));
    } else if (seed % 5 == 2) {
      final c = Offset(face.left + s * 0.72, face.top + s * 0.3);
      canvas.drawCircle(c, s * 0.055, Paint()..color = p.decor);
      canvas.drawCircle(c, s * 0.022, Paint()..color = p.flowerCenter);
    }
  }

  /// Dug soil: a recessed rounded square with a darker rim and specks.
  static void paintSoil(
    Canvas canvas,
    Rect rect,
    GardenPalette p,
    int seed, {
    bool hit = false,
  }) {
    final s = rect.shortestSide;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(_radius(rect)));
    canvas.drawRRect(
      rr,
      Paint()..color = hit ? const Color(0xFFE0675A) : p.soilDark,
    );
    final inner = rr.deflate(s * 0.05).shift(Offset(0, s * 0.03));
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: hit
              ? const [Color(0xFFF4A08F), Color(0xFFE77F6F)]
              : [p.soilDark, p.soil],
          stops: const [0, 0.35],
        ).createShader(inner.outerRect),
    );
    final rng = math.Random(seed * 104729 + 3);
    final speck = Paint()
      ..color = (hit ? const Color(0xFFC2503F) : p.soilSpeck);
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(
          inner.left + inner.width * (0.15 + 0.7 * rng.nextDouble()),
          inner.top + inner.height * (0.2 + 0.65 * rng.nextDouble()),
        ),
        s * (0.018 + 0.014 * rng.nextDouble()),
        speck,
      );
    }
  }

  /// A smooth pebble with the number [n] on it.
  static void paintPebble(Canvas canvas, Rect rect, GardenPalette p, int n) {
    final s = rect.shortestSide;
    final c = rect.center + Offset(0, s * 0.03);
    final pebble = Rect.fromCenter(
      center: c,
      width: s * 0.66,
      height: s * 0.56,
    );
    canvas.drawOval(
      pebble.shift(Offset(0, s * 0.045)),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawOval(pebble, Paint()..color = p.pebble(n));
    canvas.drawOval(
      Rect.fromLTWH(
        pebble.left + pebble.width * 0.16,
        pebble.top + pebble.height * 0.1,
        pebble.width * 0.4,
        pebble.height * 0.26,
      ),
      Paint()..color = const Color(0x66FFFFFF),
    );
    final text = _label('$n', p.pebbleInk(n), s * 0.44);
    text.paint(canvas, c - Offset(text.width / 2, text.height / 2));
  }

  /// A little garden flag on a mound. [scale] grows it from its base.
  static void paintFlag(
    Canvas canvas,
    Rect rect,
    GardenPalette p, {
    double scale = 1,
    double sway = 0,
    bool faded = false,
  }) {
    if (scale <= 0) return;
    final s = rect.shortestSide;
    final base = Offset(rect.center.dx, rect.top + s * 0.78);
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(scale);
    canvas.rotate(sway);
    final alpha = faded ? 0.55 : 1.0;
    // Mound.
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: s * 0.42, height: s * 0.14),
      Paint()..color = p.soilDark.withValues(alpha: alpha),
    );
    // Pole.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-s * 0.03, -s * 0.56, s * 0.06, s * 0.58),
        Radius.circular(s * 0.03),
      ),
      Paint()..color = p.flagPole.withValues(alpha: alpha),
    );
    // Cloth: a waving pennant.
    final cloth = Path()
      ..moveTo(s * 0.02, -s * 0.56)
      ..quadraticBezierTo(s * 0.2, -s * 0.6, s * 0.32, -s * 0.46)
      ..quadraticBezierTo(s * 0.2, -s * 0.36, s * 0.02, -s * 0.3)
      ..close();
    canvas.drawPath(
      cloth,
      Paint()..color = p.flagCloth.withValues(alpha: alpha),
    );
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.02, -s * 0.56)
        ..quadraticBezierTo(s * 0.14, -s * 0.57, s * 0.22, -s * 0.5)
        ..lineTo(s * 0.02, -s * 0.47)
        ..close(),
      Paint()..color = const Color(0x40FFFFFF),
    );
    canvas.drawCircle(
      Offset(0, -s * 0.57),
      s * 0.045,
      Paint()..color = const Color(0xFFFFD45E).withValues(alpha: alpha),
    );
    canvas.restore();
  }

  /// A red X over a wrongly flagged tile.
  static void paintCross(Canvas canvas, Rect rect, Color color) {
    final s = rect.shortestSide;
    final paint = Paint()
      ..color = color
      ..strokeWidth = s * 0.1
      ..strokeCap = StrokeCap.round;
    final d = s * 0.26;
    final c = rect.center;
    canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), paint);
    canvas.drawLine(c + Offset(d, -d), c + Offset(-d, d), paint);
  }

  /// A mole peeking out of its burrow. Sleepy by default; [hit] is the
  /// startled one with spiral eyes. [rise] (0..1) lifts it out of the hole.
  static void paintMole(
    Canvas canvas,
    Rect rect,
    GardenPalette p, {
    bool hit = false,
    double rise = 1,
  }) {
    final s = rect.shortestSide;
    final c = rect.center;
    final holeRect = Rect.fromCenter(
      center: c + Offset(0, s * 0.2),
      width: s * 0.72,
      height: s * 0.26,
    );
    canvas.drawOval(holeRect, Paint()..color = const Color(0xFF3A2516));
    if (rise <= 0) return;
    canvas.save();
    // Clip to the area above the hole's middle so the mole sits inside it.
    canvas.clipPath(
      Path()
        ..addRect(
          Rect.fromLTRB(
            rect.left,
            rect.top - s,
            rect.right,
            holeRect.center.dy,
          ),
        )
        ..addOval(holeRect),
    );
    final head = c + Offset(0, s * (0.02 + 0.3 * (1 - rise)));
    final headRect = Rect.fromCenter(
      center: head,
      width: s * 0.56,
      height: s * 0.58,
    );
    canvas.drawOval(headRect, Paint()..color = p.moleFur);
    // Ears.
    for (final dx in const [-1.0, 1.0]) {
      canvas.drawCircle(
        head + Offset(dx * s * 0.22, -s * 0.2),
        s * 0.07,
        Paint()..color = p.moleFur,
      );
      canvas.drawCircle(
        head + Offset(dx * s * 0.22, -s * 0.2),
        s * 0.035,
        Paint()..color = p.moleNose,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: head + Offset(0, s * 0.1),
        width: s * 0.34,
        height: s * 0.28,
      ),
      Paint()..color = p.moleBelly,
    );
    final eye = Paint()
      ..color = const Color(0xFF2A1C17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;
    for (final dx in const [-1.0, 1.0]) {
      final e = head + Offset(dx * s * 0.11, -s * 0.05);
      if (hit) {
        // Spiral-ish dizzy eyes.
        canvas.drawArc(
          Rect.fromCircle(center: e, radius: s * 0.05),
          0,
          math.pi * 1.6,
          false,
          eye,
        );
        canvas.drawCircle(
          e,
          s * 0.012,
          Paint()..color = const Color(0xFF2A1C17),
        );
      } else {
        // Closed, sleepy arcs.
        canvas.drawArc(
          Rect.fromCircle(center: e, radius: s * 0.045),
          0.2,
          math.pi - 0.4,
          false,
          eye,
        );
      }
    }
    // Cheeks and nose.
    for (final dx in const [-1.0, 1.0]) {
      canvas.drawCircle(
        head + Offset(dx * s * 0.17, s * 0.04),
        s * 0.035,
        Paint()..color = p.moleNose.withValues(alpha: 0.45),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: head + Offset(0, s * 0.05),
        width: s * 0.12,
        height: s * 0.08,
      ),
      Paint()..color = p.moleNose,
    );
    // Paws on the rim.
    for (final dx in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: head + Offset(dx * s * 0.16, s * 0.2),
          width: s * 0.14,
          height: s * 0.09,
        ),
        Paint()..color = p.moleBelly,
      );
    }
    canvas.restore();
    if (!hit) {
      // A small "z" for the sleepy ones.
      final z = _label('z', p.textSecondary.withValues(alpha: 0.85), s * 0.22);
      z.paint(canvas, Offset(rect.left + s * 0.68, rect.top + s * 0.02));
    } else {
      for (var i = 0; i < 3; i++) {
        final a = -math.pi / 2 + (i - 1) * 0.8;
        _star(
          canvas,
          head +
              Offset(math.cos(a) * s * 0.34, -s * 0.3 + math.sin(a) * s * 0.08),
          s * 0.06,
          const Color(0xFFFFD45E),
        );
      }
    }
  }

  /// A five-petal flower. [scale] grows it from the stem base.
  static void paintFlower(
    Canvas canvas,
    Rect rect,
    GardenPalette p, {
    double scale = 1,
    int seed = 0,
  }) {
    if (scale <= 0) return;
    final s = rect.shortestSide;
    final base = Offset(rect.center.dx, rect.top + s * 0.74);
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(scale);
    final stem = Paint()
      ..color = p.grassShadow
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(0, -s * 0.3), stem);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.09, -s * 0.12),
        width: s * 0.16,
        height: s * 0.08,
      ),
      Paint()..color = p.grassShadow,
    );
    final center = Offset(0, -s * 0.38);
    final petal = Paint()..color = seed.isEven ? p.petal : p.petalAlt;
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5 - math.pi / 2;
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * s * 0.13,
        s * 0.1,
        petal,
      );
    }
    canvas.drawCircle(center, s * 0.085, Paint()..color = p.flowerCenter);
    canvas.drawCircle(
      center + Offset(-s * 0.025, -s * 0.025),
      s * 0.03,
      Paint()..color = const Color(0x80FFFFFF),
    );
    canvas.restore();
  }

  static void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// A small sparkle (four-point star) used by effects.
  static void paintSparkle(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Laid-out labels shared by all tiles. Effects repaint every frame, so a
  /// TextPainter per paint would be wasteful; the cache is reset if it grows.
  static final Map<String, TextPainter> _labels = <String, TextPainter>{};

  static TextPainter _label(String text, Color color, double fontSize) {
    final size = (fontSize * 2).roundToDouble() / 2;
    final key = '$text|${color.toARGB32()}|$size';
    final cached = _labels[key];
    if (cached != null) return cached;
    if (_labels.length >= 160) {
      for (final painter in _labels.values) {
        painter.dispose();
      }
      _labels.clear();
    }
    return _labels[key] = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }
}

/// Paints one cell; repaints only when its look changes.
class GardenTilePainter extends CustomPainter {
  const GardenTilePainter({
    required this.palette,
    required this.look,
    this.nearby = 0,
    this.seed = 0,
  });

  final GardenPalette palette;
  final TileLook look;
  final int nearby;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    GardenTileArt.paint(
      canvas,
      Offset.zero & size,
      palette,
      look,
      nearby: nearby,
      seed: seed,
    );
  }

  @override
  bool shouldRepaint(GardenTilePainter old) =>
      old.palette != palette ||
      old.look != look ||
      old.nearby != nearby ||
      old.seed != seed;
}
