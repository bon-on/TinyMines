import 'dart:math' as math;

import 'mine_logic.dart';

/// Result of [FairField.generate].
class FairLayout {
  const FairLayout(
    this.mines, {
    required this.verified,
    required this.attempts,
    this.usedFallback = false,
  });

  /// Mole cell indexes.
  final List<int> mines;

  /// The solver opened every safe cell from the first cell without guessing.
  final bool verified;

  /// Number of randomly drawn candidates, before any fallback.
  final int attempts;

  /// Expert used a catalog layout after exhausting the random draws.
  final bool usedFallback;
}

/// Draws random mole layouts until one is guess-free (feature-expert-garden).
class FairField {
  const FairField._();

  /// Upper bound on draws. At the measured success rate of about 21% for
  /// 14x14/40 the chance of reaching it is below 1e-40.
  static const int maxAttempts = 400;

  static FairLayout generate({
    required int size,
    required int mineCount,
    required int start,
    required math.Random random,
    int attempts = maxAttempts,
  }) {
    final cells = size * size;
    RangeError.checkValueInInterval(start, 0, cells - 1, 'start');
    RangeError.checkValueInInterval(attempts, 1, 100000, 'attempts');
    final logic = MineLogic(size, mineCount);
    final blocked = {start, ...logic.neighbors(start)};
    final candidates = [
      for (var i = 0; i < cells; i++)
        if (!blocked.contains(i)) i,
    ];
    if (mineCount > candidates.length) {
      throw ArgumentError('Too many mines for a $size x $size board');
    }
    List<int> last = const [];
    for (var attempt = 1; attempt <= attempts; attempt++) {
      candidates.shuffle(random);
      last = candidates.take(mineCount).toList();
      if (logic.solvable(last.toSet(), start)) {
        return FairLayout(last, verified: true, attempts: attempt);
      }
    }
    if (size == _expertSize && mineCount == _expertMineCount) {
      final mines = _expertFallback(logic, start);
      return FairLayout(
        mines,
        verified: true,
        attempts: attempts,
        usedFallback: true,
      );
    }
    return FairLayout(last, verified: false, attempts: attempts);
  }

  static List<int> _expertFallback(MineLogic logic, int start) {
    for (final (mines, openings) in _expertLayouts) {
      for (var symmetry = 0; symmetry < 8; symmetry++) {
        // A reflection or transposition preserves the opening and clues.
        if (!openings.any((cell) => _transform(cell, symmetry) == start)) {
          continue;
        }
        final layout = [for (final mine in mines) _transform(mine, symmetry)];
        if (logic.solvable(layout.toSet(), start)) return layout;
      }
    }
    throw StateError('No verified Expert layout for opening $start');
  }

  static int _transform(int cell, int symmetry) {
    var row = cell ~/ _expertSize;
    var column = cell % _expertSize;
    if ((symmetry & 1) != 0) row = _expertSize - 1 - row;
    if ((symmetry & 2) != 0) column = _expertSize - 1 - column;
    if ((symmetry & 4) != 0) (row, column) = (column, row);
    return row * _expertSize + column;
  }
}

const _expertSize = 14;
const _expertMineCount = 40;

// Each entry contains mine positions and tested openings in row-major order.
// Together with their symmetries, they cover all 196 possible first digs.
const _expertLayouts = <(List<int>, List<int>)>[
  (
    [
      5, 8, 11, 16, 20, 22, 23, 24, 30, 34, 36, 38, 45, 46, 47, 51,
      57, 62, 70, 75, 80, 81, 90, 100, 104, 132, 134, 140, 152, 155,
      156, 171, 172, 173, 178, 183, 184, 188, 189, 192,
    ],
    [
      13, 27, 40, 41, 54, 55, 69, 78, 83, 92, 97, 102, 106, 107, 108,
      109, 110, 111, 116, 122, 123, 124, 125, 128, 129, 130, 136,
      144, 150, 180, 181, 194, 195,
    ],
  ),
  (
    [
      0, 1, 2, 6, 7, 8, 14, 16, 17, 29, 33, 41, 46, 47, 51, 56, 57,
      70, 72, 75, 77, 79, 85, 95, 99, 102, 103, 111, 133, 136, 141,
      142, 158, 160, 162, 170, 171, 181, 190, 191,
    ],
    [
      10, 11, 12, 13, 24, 25, 35, 39, 49, 53, 67, 68, 69, 83, 138,
      139, 152, 153, 164, 165, 179, 193,
    ],
  ),
  (
    [
      9, 17, 18, 21, 23, 24, 35, 37, 41, 47, 50, 55, 65, 66, 69, 76,
      83, 92, 99, 101, 107, 108, 123, 124, 127, 129, 136, 138, 139,
      140, 143, 146, 157, 164, 167, 171, 182, 183, 187, 193,
    ],
    [103, 104, 117, 118, 119, 134, 148, 162, 175, 176, 189, 190, 191],
  ),
];
