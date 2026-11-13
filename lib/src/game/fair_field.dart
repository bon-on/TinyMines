import 'dart:math' as math;

import 'mine_logic.dart';

/// Result of [FairField.generate].
class FairLayout {
  const FairLayout(
    this.mines, {
    required this.verified,
    required this.attempts,
  });

  /// Mole cell indexes.
  final List<int> mines;

  /// The solver opened every safe cell from the first cell without guessing.
  final bool verified;
  final int attempts;
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
    return FairLayout(last, verified: false, attempts: attempts);
  }
}
