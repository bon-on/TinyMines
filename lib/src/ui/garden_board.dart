import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';

import '../../mine_field.dart';
import '../art/garden_palette.dart';
import '../art/garden_tile_art.dart';
import 'board_fx.dart';

/// What [cell] at [index] shows, given how the run ended.
TileLook lookFor(MineField field, int index, {required int? hitIndex}) {
  final cell = field.cells[index];
  final lost = field.lost;
  if (!cell.revealed) {
    if (field.won && cell.mine) return TileLook.flower;
    if (cell.flagged) {
      return lost && !cell.mine ? TileLook.wrongFlag : TileLook.flagged;
    }
    return TileLook.covered;
  }
  if (cell.mine) {
    if (index == hitIndex || field.blasted.contains(index)) {
      return TileLook.moleHit;
    }
    return cell.flagged ? TileLook.flaggedMole : TileLook.mole;
  }
  return TileLook.soil;
}

/// Boards whose cells are smaller than this (logical px) can be zoomed
/// (feature-mobile-touch-zoom).
const double zoomCellThreshold = 32;

/// Largest board zoom.
const double maxBoardZoom = 3;

/// Side of one cell for a grid of [size] cells in [inner] px with [gap].
double boardCellSide(double inner, int size, double gap) =>
    (inner - gap * (size - 1)) / size;

/// Zoom transform that scales by [scale] and centres [focus] (child
/// coordinates) in a viewer of [viewport], clamped so no space past the
/// board edge shows.
Matrix4 boardZoomMatrix(Size viewport, double scale, Offset focus) {
  final tx = (viewport.width / 2 - scale * focus.dx).clamp(
    viewport.width - scale * viewport.width,
    0.0,
  );
  final ty = (viewport.height / 2 - scale * focus.dy).clamp(
    viewport.height - scale * viewport.height,
    0.0,
  );
  return Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setEntry(0, 3, tx)
    ..setEntry(1, 3, ty);
}

/// The board: a wooden planter frame around a grid of garden tiles, with
/// the effects layer on top. Each tile is an [InkWell] in a [GridView].
/// The grid and the effects sit in an [InteractiveViewer] that pinch-zooms
/// and pans when [zoomable] (the frame does not scale).
class GardenBoard extends StatelessWidget {
  const GardenBoard({
    super.key,
    required this.field,
    required this.palette,
    required this.fx,
    required this.gap,
    required this.hitIndex,
    required this.onTap,
    required this.onFlag,
    required this.dimension,
    this.flagMode = false,
    this.zoom,
    this.zoomable = false,
    this.zoomed = false,
    this.viewerKey,
  });

  /// The grid is zoomed in: clip it to the bed. Unzoomed, effects may spill
  /// onto the frame as before.
  final bool zoomed;

  /// Zoom state of the grid; null keeps the grid unzoomed.
  final TransformationController? zoom;

  /// Pinch zoom and panning are on.
  final bool zoomable;

  /// Key of the zoom viewer, so callers can read its size.
  final Key? viewerKey;

  final MineField field;
  final GardenPalette palette;
  final BoardFx fx;
  final double gap;
  final int? hitIndex;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onFlag;

  /// Outer size of the framed board.
  final double dimension;

  /// Taps plant flags: the frame turns flag-coloured so the mode is visible
  /// right where the player taps.
  final bool flagMode;

  /// Frame thickness for a board of [dimension].
  static double frameFor(double dimension) => (dimension * 0.028).clamp(6, 14);

  @override
  Widget build(BuildContext context) {
    final frame = frameFor(dimension);
    final gameOver = field.lost || field.won;
    return Container(
      key: const ValueKey('garden-board'),
      width: dimension,
      height: dimension,
      padding: EdgeInsets.all(frame),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(frame * 2.2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(palette.boardFrame, Colors.white, 0.18)!,
            palette.boardFrame,
          ],
        ),
        border: Border.all(
          color: flagMode
              ? palette.flagCloth
              : Color.lerp(palette.boardFrame, Colors.black, 0.25)!,
          width: flagMode ? 3 : 2,
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0x40000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
          if (flagMode)
            BoxShadow(
              color: palette.flagCloth.withValues(alpha: 0.55),
              blurRadius: 14,
              spreadRadius: 2,
            ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.boardBed,
          borderRadius: BorderRadius.circular(frame * 1.2),
        ),
        child: Padding(
          padding: EdgeInsets.all(gap),
          child: InteractiveViewer(
            key: viewerKey,
            transformationController: zoom,
            minScale: 1,
            maxScale: maxBoardZoom,
            scaleEnabled: zoomable,
            panEnabled: zoomable,
            clipBehavior: zoomed ? Clip.hardEdge : Clip.none,
            child: _grid(gameOver),
          ),
        ),
      ),
    );
  }

  Widget _grid(bool gameOver) => BoardFxLayer(
    fx: fx,
    palette: palette,
    size: field.size,
    gap: gap,
    child: GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: field.cells.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: field.size,
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
      ),
      itemBuilder: (context, index) {
        final cell = field.cells[index];
        final look = lookFor(field, index, hitIndex: hitIndex);
        return _GardenTile(
          palette: palette,
          look: look,
          nearby: cell.nearby,
          seed: index,
          interactive:
              !gameOver && (!cell.revealed || (cell.nearby > 0 && !cell.mine)),
          onTap: () => onTap(index),
          onFlag: () => onFlag(index),
        );
      },
    ),
  );
}

/// A tile. Holding a hidden or flagged tile shrinks it over the long-press
/// time, so players see that holding plants (or lifts) a flag.
class _GardenTile extends StatefulWidget {
  const _GardenTile({
    required this.palette,
    required this.look,
    required this.nearby,
    required this.seed,
    required this.interactive,
    required this.onTap,
    required this.onFlag,
  });

  final GardenPalette palette;
  final TileLook look;
  final int nearby;
  final int seed;
  final bool interactive;
  final VoidCallback onTap;
  final VoidCallback onFlag;

  /// Scale a held hidden or flagged tile shrinks to.
  static const double heldScale = 0.86;

  @override
  State<_GardenTile> createState() => _GardenTileState();
}

class _GardenTileState extends State<_GardenTile> {
  bool _held = false;

  String get _label => switch (widget.look) {
    TileLook.covered => 'Hidden tile',
    TileLook.flagged => 'Flag',
    TileLook.wrongFlag => 'Wrong flag',
    TileLook.soil => widget.nearby == 0 ? 'Empty' : '${widget.nearby}',
    TileLook.mole || TileLook.moleHit || TileLook.flaggedMole => 'Mole',
    TileLook.flower => 'Flower',
  };

  bool get _holdable =>
      widget.interactive &&
      (widget.look == TileLook.covered || widget.look == TileLook.flagged);

  void _hold(bool held) {
    if (_held != held) setState(() => _held = held);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    final held = _held && _holdable;
    return Semantics(
      label: _label,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedScale(
            key: const ValueKey('tile-hold'),
            scale: held ? _GardenTile.heldScale : 1,
            // Shrinks over the long-press time, springs back quickly.
            duration: held
                ? kLongPressTimeout
                : const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: CustomPaint(
              painter: GardenTilePainter(
                palette: widget.palette,
                look: widget.look,
                nearby: widget.nearby,
                seed: widget.seed,
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              mouseCursor: widget.interactive
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              hoverColor: const Color(0x2EFFFFFF),
              splashColor: widget.palette.sparkle.withValues(alpha: 0.35),
              highlightColor: const Color(0x14FFFFFF),
              onTapDown: (_) => _hold(true),
              onTapCancel: () => _hold(false),
              onTap: () {
                _hold(false);
                widget.onTap();
              },
              onLongPress: () {
                _hold(false);
                widget.onFlag();
              },
              onSecondaryTap: widget.onFlag,
            ),
          ),
        ],
      ),
    );
  }
}
