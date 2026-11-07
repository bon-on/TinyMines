import 'dart:math' as math;

/// Bounded generation policy for regular Easy gardens only.
///
/// The solver may inspect a number only after virtually opening its cell. It
/// never chooses a move by inspecting whether a covered cell contains a mine.
class FairEasyField {
  const FairEasyField._();

  static const int size = 6;
  static const int mineCount = 5;
  static const int maxAttempts = 48;

  static Iterable<int> neighbors(int index) sync* {
    final row = index ~/ size;
    final col = index % size;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final r = row + dr;
        final c = col + dc;
        if (r >= 0 && r < size && c >= 0 && c < size) {
          yield r * size + c;
        }
      }
    }
  }

  static List<int> generate(int start, math.Random random) {
    RangeError.checkValueInInterval(start, 0, size * size - 1, 'start');
    final blocked = {start, ...neighbors(start)};
    final candidates = [
      for (var i = 0; i < size * size; i++)
        if (!blocked.contains(i)) i,
    ];
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      candidates.shuffle(random);
      final mines = candidates.take(mineCount).toList();
      if (solvable(mines, start)) return mines;
    }
    return fallback(start);
  }

  /// A deterministic emergency placement, independent of an unreliable RNG.
  /// Return a copy so callers cannot alter the verified catalog.
  static List<int> fallback(int start) {
    RangeError.checkValueInInterval(start, 0, size * size - 1, 'start');
    final mines = _fallbacks[start];
    if (!solvable(mines, start)) {
      throw StateError('Invalid Easy fallback for opening $start');
    }
    return List<int>.of(mines);
  }

  /// True only when the initial flood leaves play to do and visible-clue
  /// deductions alone can finish the board, without a guess or a hint.
  static bool solvable(Iterable<int> mineIndexes, int start) {
    if (start < 0 || start >= size * size) return false;
    final mines = mineIndexes.toSet();
    if (mines.length != mineCount ||
        mines.any((i) => i < 0 || i >= size * size) ||
        mines.contains(start) ||
        neighbors(start).any(mines.contains)) {
      return false;
    }
    final clues = List<int?>.filled(size * size, null);
    final marked = <int>{};
    void reveal(int index) {
      final queue = [index];
      while (queue.isNotEmpty) {
        final cell = queue.removeLast();
        if (clues[cell] != null) continue;
        final nearby = neighbors(cell).where(mines.contains).length;
        clues[cell] = nearby;
        if (nearby == 0) {
          queue.addAll(neighbors(cell).where((n) => clues[n] == null));
        }
      }
    }

    reveal(start);
    if (clues.whereType<int>().length == size * size - mineCount) return false;
    // Each successful pass assigns at least one of the 36 cells.
    for (var pass = 0; pass < size * size; pass++) {
      final moves = deduce(clues, marked);
      if (moves.safe.isEmpty && moves.mines.isEmpty) return false;
      if (moves.safe.any(mines.contains) ||
          moves.mines.any((i) => !mines.contains(i))) {
        return false;
      }
      marked.addAll(moves.mines);
      for (final safe in moves.safe) {
        reveal(safe);
      }
      if (clues.whereType<int>().length == size * size - mineCount) return true;
    }
    return false;
  }

  /// Deductions from information a player can see: opened numbers, already
  /// established mines and the displayed total mine count. Covered-cell mine
  /// locations are deliberately not an argument.
  static ({Set<int> safe, Set<int> mines}) deduce(
    List<int?> clues,
    Set<int> knownMines,
  ) {
    final constraints = <({Set<int> cells, int count})>[];
    final covered = <int>{
      for (var i = 0; i < clues.length; i++)
        if (clues[i] == null && !knownMines.contains(i)) i,
    };
    constraints.add((cells: covered, count: mineCount - knownMines.length));
    for (var i = 0; i < clues.length; i++) {
      if (clues[i] == null) continue;
      final around = neighbors(i).toSet();
      final unknown = around.intersection(covered);
      if (unknown.isNotEmpty) {
        constraints.add((
          cells: unknown,
          count: clues[i]! - around.intersection(knownMines).length,
        ));
      }
    }
    final safe = <int>{};
    final mines = <int>{};
    void apply(Set<int> cells, int count) {
      if (cells.isEmpty) return;
      if (count == 0) safe.addAll(cells);
      if (count == cells.length) mines.addAll(cells);
    }

    for (final constraint in constraints) {
      apply(constraint.cells, constraint.count);
    }
    for (final smaller in constraints) {
      for (final larger in constraints) {
        if (smaller.cells.length >= larger.cells.length ||
            !larger.cells.containsAll(smaller.cells)) {
          continue;
        }
        apply(
          larger.cells.difference(smaller.cells),
          larger.count - smaller.count,
        );
      }
    }
    return (safe: safe, mines: mines);
  }

  // One solver-verified, non-terminal opening per first cell. These are
  // deterministic emergency choices, independent of the supplied RNG.
  static const List<List<int>> _fallbacks = [
    [34, 22, 35, 32, 33],
    [13, 26, 18, 19, 20],
    [34, 10, 16, 28, 0],
    [12, 17, 16, 27, 15],
    [17, 26, 34, 23, 6],
    [25, 24, 9, 35, 20],
    [26, 3, 25, 10, 9],
    [17, 3, 9, 11, 19],
    [18, 20, 30, 24, 32],
    [31, 5, 12, 23, 11],
    [30, 13, 32, 27, 20],
    [20, 8, 21, 6, 24],
    [34, 1, 21, 27, 30],
    [10, 23, 3, 16, 4],
    [2, 4, 18, 10, 30],
    [17, 18, 34, 23, 35],
    [8, 20, 6, 7, 31],
    [3, 14, 8, 9, 6],
    [0, 14, 35, 30, 15],
    [10, 27, 4, 31, 3],
    [0, 1, 28, 6, 7],
    [19, 11, 30, 2, 35],
    [2, 18, 6, 4, 8],
    [35, 18, 25, 5, 12],
    [9, 22, 20, 0, 35],
    [11, 27, 21, 1, 4],
    [10, 15, 18, 7, 8],
    [1, 12, 8, 3, 7],
    [10, 2, 31, 4, 9],
    [20, 14, 3, 4, 18],
    [21, 16, 20, 32, 5],
    [5, 34, 20, 9, 19],
    [5, 13, 29, 8, 0],
    [23, 8, 22, 7, 5],
    [18, 20, 21, 11, 13],
    [6, 33, 20, 0, 5],
  ];
}
