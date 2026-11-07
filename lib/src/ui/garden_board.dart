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

/// The board: a wooden planter frame around a grid of garden tiles, with
/// the effects layer on top. Each tile is an [InkWell] in a [GridView].
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
  });

  final MineField field;
  final GardenPalette palette;
  final BoardFx fx;
  final double gap;
  final int? hitIndex;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onFlag;

  /// Outer size of the framed board.
  final double dimension;

  /// Frame thickness for a board of [dimension].
  static double frameFor(double dimension) => (dimension * 0.028).clamp(6, 14);

  @override
  Widget build(BuildContext context) {
    final frame = frameFor(dimension);
    final gameOver = field.lost || field.won;
    return Container(
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
          color: Color.lerp(palette.boardFrame, Colors.black, 0.25)!,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 18,
            offset: Offset(0, 8),
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
          child: BoardFxLayer(
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
                      !gameOver &&
                      (!cell.revealed || (cell.nearby > 0 && !cell.mine)),
                  onTap: () => onTap(index),
                  onFlag: () => onFlag(index),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GardenTile extends StatelessWidget {
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

  String get _label => switch (look) {
    TileLook.covered => 'Hidden tile',
    TileLook.flagged => 'Flag',
    TileLook.wrongFlag => 'Wrong flag',
    TileLook.soil => nearby == 0 ? 'Empty' : '$nearby',
    TileLook.mole || TileLook.moleHit || TileLook.flaggedMole => 'Mole',
    TileLook.flower => 'Flower',
  };

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    return Semantics(
      label: _label,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: GardenTilePainter(
              palette: palette,
              look: look,
              nearby: nearby,
              seed: seed,
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              mouseCursor: interactive
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              hoverColor: const Color(0x2EFFFFFF),
              splashColor: palette.sparkle.withValues(alpha: 0.35),
              highlightColor: const Color(0x14FFFFFF),
              onTap: onTap,
              onLongPress: onFlag,
              onSecondaryTap: onFlag,
            ),
          ),
        ],
      ),
    );
  }
}
