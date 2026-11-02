import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../art/garden_palette.dart';
import '../art/garden_tile_art.dart';

/// A board cell paired with the delay before its effect starts.
typedef TimedCell = ({int cell, int delayMs});

abstract class _FxEvent {
  /// Effect clock time when the event was queued.
  Duration start = Duration.zero;

  /// Random seed for this event's particles.
  int seed = 0;

  /// Total length including the longest delay.
  int get lengthMs;
}

/// Grass tufts popping off newly dug cells, rippling out from the tap.
class _RevealEvent extends _FxEvent {
  _RevealEvent(this.cells);
  final List<TimedCell> cells;
  static const int popMs = 280;
  @override
  int get lengthMs =>
      cells.fold<int>(0, (m, c) => math.max(m, c.delayMs)) + popMs;
}

class _FlagEvent extends _FxEvent {
  _FlagEvent(this.cell, this.planted);
  final int cell;
  final bool planted;
  @override
  int get lengthMs => planted ? 420 : 220;
}

/// Burst at the dug-up mole, a shake, then the other moles pop up in turn.
class _BlastEvent extends _FxEvent {
  _BlastEvent(this.cell, this.others);
  final int cell;
  final List<TimedCell> others;
  static const int popMs = 320;
  @override
  int get lengthMs => math.max(
    900,
    others.fold<int>(0, (m, c) => math.max(m, c.delayMs)) + popMs,
  );
}

/// Flowers blooming on the mine cells and confetti over the board.
class _BloomEvent extends _FxEvent {
  _BloomEvent(this.flowers);
  final List<TimedCell> flowers;
  static const int growMs = 420;
  static const int confettiMs = 1800;
  @override
  int get lengthMs => math.max(
    confettiMs,
    flowers.fold<int>(0, (m, c) => math.max(m, c.delayMs)) + growMs,
  );
}

class _SparkleEvent extends _FxEvent {
  _SparkleEvent(this.cell);
  final int cell;
  @override
  int get lengthMs => 700;
}

/// Queue of board effects. Rules are applied by the screen right away; the
/// effects only trail behind on a separate layer, so they never block input.
///
/// The effect clock belongs to this queue, not to the layer, so a rebuilt
/// layer continues the same timeline.
class BoardFx extends ChangeNotifier {
  final List<_FxEvent> _events = <_FxEvent>[];
  Duration _clock = Duration.zero;
  int _seed = 1;

  bool get isActive => _events.isNotEmpty;

  void reveal(List<TimedCell> cells) {
    if (cells.isEmpty) return;
    _add(_RevealEvent(cells));
  }

  void flag(int cell, {required bool planted}) {
    _events.removeWhere((e) => e is _FlagEvent && e.cell == cell);
    _add(_FlagEvent(cell, planted));
  }

  void blast(int cell, List<TimedCell> others) =>
      _add(_BlastEvent(cell, others));

  void bloom(List<TimedCell> flowers) => _add(_BloomEvent(flowers));

  void sparkle(int cell) => _add(_SparkleEvent(cell));

  /// Drops every effect (new board).
  void clear() {
    if (_events.isEmpty) return;
    _events.clear();
    notifyListeners();
  }

  void _add(_FxEvent event) {
    event
      ..start = _clock
      ..seed = _seed++;
    _events.add(event);
    notifyListeners();
  }

  /// Advances the clock; drops finished events. Returns whether any remain.
  bool _advance(Duration now) {
    _clock = now;
    _events.removeWhere((e) => (now - e.start).inMilliseconds > e.lengthMs);
    return _events.isNotEmpty;
  }
}

/// Paints [fx] over [child] (the board grid) and shakes both on a blast.
/// One ticker, running only while effects are queued; only the painter and
/// the shake transform rebuild per frame.
class BoardFxLayer extends StatefulWidget {
  const BoardFxLayer({
    super.key,
    required this.fx,
    required this.palette,
    required this.size,
    required this.gap,
    required this.child,
  });

  final BoardFx fx;
  final GardenPalette palette;

  /// Cells per row.
  final int size;

  /// Spacing between cells, as in the grid.
  final double gap;
  final Widget child;

  @override
  State<BoardFxLayer> createState() => _BoardFxLayerState();
}

class _BoardFxLayerState extends State<BoardFxLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _Frame _frame = _Frame();
  // Effect clock value when the ticker last started.
  Duration _base = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.fx.addListener(_onFxChanged);
    _onFxChanged();
  }

  @override
  void didUpdateWidget(BoardFxLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fx != widget.fx) {
      oldWidget.fx.removeListener(_onFxChanged);
      widget.fx.addListener(_onFxChanged);
      _onFxChanged();
    }
  }

  @override
  void dispose() {
    widget.fx.removeListener(_onFxChanged);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _onFxChanged() {
    final fx = widget.fx;
    if (fx.isActive && !_ticker.isActive) {
      _base = fx._clock;
      _ticker.start();
    } else if (!fx.isActive && _ticker.isActive) {
      _ticker.stop();
    }
    _frame.tick();
  }

  void _onTick(Duration elapsed) {
    final alive = widget.fx._advance(_base + elapsed);
    if (!alive) _ticker.stop();
    _frame.tick();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _frame,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          IgnorePointer(
            child: CustomPaint(
              painter: _FxPainter(
                fx: widget.fx,
                palette: widget.palette,
                size: widget.size,
                gap: widget.gap,
                repaint: _frame,
              ),
            ),
          ),
        ],
      ),
      builder: (context, child) =>
          Transform.translate(offset: _shake(), child: child),
    );
  }

  Offset _shake() {
    final fx = widget.fx;
    for (final event in fx._events) {
      if (event is! _BlastEvent) continue;
      final t = (fx._clock - event.start).inMilliseconds;
      if (t < 0 || t > 420) continue;
      final decay = 1 - t / 420;
      final amp = 7 * decay * decay;
      return Offset(amp * math.sin(t / 18.0), amp * 0.6 * math.cos(t / 23.0));
    }
    return Offset.zero;
  }
}

/// Repaint signal for the effect painter and the shake.
class _Frame extends ChangeNotifier {
  void tick() => notifyListeners();
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

double _easeOutBack(double t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final x = t - 1;
  return 1 + c3 * x * x * x + c1 * x * x;
}

class _FxPainter extends CustomPainter {
  _FxPainter({
    required this.fx,
    required this.palette,
    required this.size,
    required this.gap,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final BoardFx fx;
  final GardenPalette palette;
  final int size;
  final double gap;

  Rect _cellRect(Size box, int index) {
    final cell = (box.width - gap * (size - 1)) / size;
    final row = index ~/ size;
    final col = index % size;
    return Rect.fromLTWH(col * (cell + gap), row * (cell + gap), cell, cell);
  }

  @override
  void paint(Canvas canvas, Size box) {
    final now = fx._clock;
    for (final event in fx._events) {
      final t = (now - event.start).inMilliseconds;
      switch (event) {
        case _RevealEvent():
          _paintReveal(canvas, box, event, t);
        case _FlagEvent():
          _paintFlag(canvas, box, event, t);
        case _BlastEvent():
          _paintBlast(canvas, box, event, t);
        case _BloomEvent():
          _paintBloom(canvas, box, event, t);
        case _SparkleEvent():
          _paintSparkle(canvas, box, event, t);
      }
    }
  }

  /// Before its delay a cell still shows grass; then the tuft hops up,
  /// shrinks and fades while a few blades fly off.
  void _paintReveal(Canvas canvas, Size box, _RevealEvent e, int t) {
    for (final c in e.cells) {
      final rect = _cellRect(box, c.cell);
      final local = t - c.delayMs;
      if (local < 0) {
        GardenTileArt.paintCovered(canvas, rect, palette, c.cell);
        continue;
      }
      final p = _clamp01(local / _RevealEvent.popMs);
      if (p >= 1) continue;
      final scale = p < 0.3
          ? 1 + 0.12 * (p / 0.3)
          : 1.12 * (1 - (p - 0.3) / 0.7);
      final opacity = 1 - _clamp01((p - 0.35) / 0.65);
      canvas.saveLayer(
        rect.inflate(rect.width),
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
      );
      final center = rect.center - Offset(0, rect.height * 0.35 * p);
      canvas.translate(center.dx, center.dy);
      canvas.scale(math.max(0.01, scale));
      canvas.translate(-rect.center.dx, -rect.center.dy);
      GardenTileArt.paintCovered(canvas, rect, palette, c.cell);
      canvas.restore();
      // Blades flying off.
      final rng = math.Random(e.seed * 977 + c.cell);
      final blade = Paint()
        ..color = palette.grassBlade.withValues(alpha: 1 - p)
        ..strokeWidth = math.max(1.5, rect.width * 0.06)
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 2.2;
        final speed = rect.width * (0.6 + rng.nextDouble() * 0.6);
        final pos =
            rect.center +
            Offset(math.cos(angle), math.sin(angle)) * speed * p +
            Offset(0, rect.width * 0.9 * p * p);
        final dir =
            Offset(math.cos(angle + p * 3), math.sin(angle + p * 3)) *
            rect.width *
            0.12;
        canvas.drawLine(pos - dir, pos + dir, blade);
      }
    }
  }

  void _paintFlag(Canvas canvas, Size box, _FlagEvent e, int t) {
    final rect = _cellRect(box, e.cell);
    final p = _clamp01(t / e.lengthMs);
    GardenTileArt.paintCovered(canvas, rect, palette, e.cell);
    if (e.planted) {
      final grow = _clamp01(t / 300);
      final scale = _easeOutBack(grow);
      final sway = math.sin(t / 40.0) * 0.25 * (1 - p);
      GardenTileArt.paintFlag(canvas, rect, palette, scale: scale, sway: sway);
      // Dust puff at the base.
      final puff = Paint()
        ..color = palette.soilDark.withValues(alpha: 0.5 * (1 - p));
      final base = Offset(rect.center.dx, rect.top + rect.height * 0.8);
      for (final dx in const [-1.0, 1.0]) {
        canvas.drawCircle(
          base +
              Offset(
                dx * rect.width * (0.15 + 0.3 * p),
                -rect.height * 0.05 * p,
              ),
          rect.width * 0.08 * (1 - p * 0.5),
          puff,
        );
      }
    } else {
      GardenTileArt.paintFlag(canvas, rect, palette, scale: 1 - p);
    }
  }

  void _paintBlast(Canvas canvas, Size box, _BlastEvent e, int t) {
    final rect = _cellRect(box, e.cell);
    final s = rect.width;
    // Expanding ring and flash.
    final ringP = _clamp01(t / 420);
    if (ringP < 1) {
      canvas.drawCircle(
        rect.center,
        s * (0.4 + 1.8 * ringP),
        Paint()
          ..color = palette.danger.withValues(alpha: 0.6 * (1 - ringP))
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.18 * (1 - ringP) + 1,
      );
      canvas.drawCircle(
        rect.center,
        s * (0.3 + 0.6 * ringP),
        Paint()..color = palette.sparkle.withValues(alpha: 0.7 * (1 - ringP)),
      );
    }
    // Dirt clods thrown out and falling.
    final dirtP = _clamp01(t / 800);
    if (dirtP < 1) {
      final rng = math.Random(e.seed * 31 + 5);
      for (var i = 0; i < 14; i++) {
        final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * math.pi * 1.6;
        final speed = s * (1.0 + rng.nextDouble() * 1.4);
        final pos =
            rect.center +
            Offset(math.cos(angle), math.sin(angle)) * speed * dirtP +
            Offset(0, s * 2.2 * dirtP * dirtP);
        canvas.drawCircle(
          pos,
          s * (0.05 + 0.05 * rng.nextDouble()) * (1 - dirtP * 0.5),
          Paint()
            ..color = (i.isEven ? palette.soilDark : palette.soilSpeck)
                .withValues(alpha: 1 - dirtP),
        );
      }
    }
    // Other moles: grass until their turn, then the tuft pops away.
    for (final c in e.others) {
      final r = _cellRect(box, c.cell);
      final local = t - c.delayMs;
      if (local < 0) {
        GardenTileArt.paintCovered(canvas, r, palette, c.cell);
        continue;
      }
      final p = _clamp01(local / _BlastEvent.popMs);
      if (p >= 1) continue;
      canvas.saveLayer(
        r.inflate(r.width),
        Paint()..color = Color.fromRGBO(0, 0, 0, 1 - p),
      );
      final center = r.center - Offset(0, r.height * 0.5 * p);
      canvas.translate(center.dx, center.dy);
      canvas.scale(math.max(0.01, 1 - 0.6 * p));
      canvas.translate(-r.center.dx, -r.center.dy);
      GardenTileArt.paintCovered(canvas, r, palette, c.cell);
      canvas.restore();
    }
  }

  void _paintBloom(Canvas canvas, Size box, _BloomEvent e, int t) {
    for (final c in e.flowers) {
      final rect = _cellRect(box, c.cell);
      final local = t - c.delayMs;
      final p = _clamp01(local / _BloomEvent.growMs);
      if (p >= 1) continue;
      // Cover the static flower with grass and grow a new one.
      GardenTileArt.paintCovered(canvas, rect, palette, c.cell);
      if (local >= 0) {
        GardenTileArt.paintFlower(
          canvas,
          rect,
          palette,
          scale: _easeOutBack(p),
          seed: c.cell,
        );
      }
    }
    // Confetti and petals falling over the whole board.
    final p = _clamp01(t / _BloomEvent.confettiMs);
    if (p >= 1) return;
    final rng = math.Random(e.seed * 7 + 11);
    final colors = [
      palette.petal,
      palette.petalAlt,
      palette.flowerCenter,
      palette.accent,
      palette.flagCloth,
    ];
    final w = box.width;
    for (var i = 0; i < 46; i++) {
      final startX = w * (0.1 + 0.8 * rng.nextDouble());
      final vx = (rng.nextDouble() - 0.5) * w * 0.8;
      final vy = -box.height * (0.5 + rng.nextDouble() * 0.6);
      final spin = rng.nextDouble() * 12;
      final delay = rng.nextDouble() * 0.15;
      final local = _clamp01((p - delay) / (1 - delay));
      if (local <= 0) continue;
      final pos = Offset(
        startX + vx * local,
        box.height * 0.55 + vy * local + box.height * 1.4 * local * local,
      );
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(spin * local);
      final size = w * 0.018;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: size * 1.6,
            height: size * (0.6 + 0.4 * math.cos(spin * local * 2).abs()),
          ),
          Radius.circular(size * 0.3),
        ),
        Paint()
          ..color = colors[i % colors.length].withValues(
            alpha: 1 - _clamp01((local - 0.75) / 0.25),
          ),
      );
      canvas.restore();
    }
  }

  void _paintSparkle(Canvas canvas, Size box, _SparkleEvent e, int t) {
    final rect = _cellRect(box, e.cell);
    final p = _clamp01(t / e.lengthMs);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + p * 2;
      final pos =
          rect.center +
          Offset(math.cos(a), math.sin(a)) * rect.width * (0.3 + 0.35 * p);
      GardenTileArt.paintSparkle(
        canvas,
        pos,
        rect.width * 0.18 * math.sin(p * math.pi),
        palette.sparkle,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.2)),
      Paint()
        ..color = palette.sparkle.withValues(alpha: 0.8 * (1 - p))
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.width * 0.08,
    );
  }

  @override
  bool shouldRepaint(_FxPainter old) =>
      old.fx != fx ||
      old.palette != palette ||
      old.size != size ||
      old.gap != gap;
}
