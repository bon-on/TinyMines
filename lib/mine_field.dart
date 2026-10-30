import 'dart:math' as math;

class MineCell {
  bool mine = false;
  bool revealed = false;
  bool flagged = false;
  int nearby = 0;
}

enum RevealOutcome { none, safe, exploded }

/// Board rules for Tiny Mines, kept free of widgets so they can be unit tested.
class MineField {
  MineField({required this.size, required this.mineCount, math.Random? random})
    : _random = random ?? math.Random(),
      cells = List.generate(size * size, (_) => MineCell());

  final int size;
  final int mineCount;
  final math.Random _random;
  final List<MineCell> cells;
  bool _armed = false;

  bool get armed => _armed;
  bool get lost => cells.any((cell) => cell.mine && cell.revealed);
  bool get won => cells.where((c) => !c.mine).every((c) => c.revealed);
  int get flags => cells.where((cell) => cell.flagged).length;

  /// Indexes of flags placed on safe tiles; shown as mistakes after a loss.
  List<int> get wrongFlags => lost
      ? [
          for (var i = 0; i < cells.length; i++)
            if (cells[i].flagged && !cells[i].mine) i,
        ]
      : const [];

  Iterable<int> neighbors(int index) sync* {
    final row = index ~/ size;
    final col = index % size;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = row + dr;
        final nc = col + dc;
        if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
          yield nr * size + nc;
        }
      }
    }
  }

  /// Places mines away from [safeIndex] and its neighbors.
  void plantMines(int safeIndex) {
    final blocked = {safeIndex, ...neighbors(safeIndex)};
    final candidates = [
      for (var i = 0; i < cells.length; i++)
        if (!blocked.contains(i)) i,
    ]..shuffle(_random);
    plantMinesAt(candidates.take(mineCount));
  }

  /// Places mines at fixed positions. Used by [plantMines] and by tests.
  void plantMinesAt(Iterable<int> indexes) {
    for (final index in indexes) {
      cells[index].mine = true;
    }
    for (var i = 0; i < cells.length; i++) {
      cells[i].nearby = neighbors(i).where((n) => cells[n].mine).length;
    }
    _armed = true;
  }

  RevealOutcome reveal(int index) {
    if (lost || won) return RevealOutcome.none;
    final cell = cells[index];
    if (cell.flagged || cell.revealed) return RevealOutcome.none;
    if (!_armed) plantMines(index);

    if (cell.mine) {
      for (final mineCell in cells.where((c) => c.mine)) {
        mineCell.revealed = true;
      }
      return RevealOutcome.exploded;
    }

    final queue = <int>[index];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      final currentCell = cells[current];
      if (currentCell.revealed || currentCell.flagged) continue;
      currentCell.revealed = true;
      if (currentCell.nearby == 0) {
        for (final next in neighbors(current)) {
          final nextCell = cells[next];
          if (!nextCell.revealed && !nextCell.flagged && !nextCell.mine) {
            queue.add(next);
          }
        }
      }
    }
    return RevealOutcome.safe;
  }

  /// Reveals every unflagged neighbor of a revealed number once the player
  /// has placed that many flags around it. Wrong flags can still explode.
  RevealOutcome chord(int index) {
    final cell = cells[index];
    if (lost || won || !cell.revealed || cell.nearby == 0) {
      return RevealOutcome.none;
    }
    final around = neighbors(index).toList();
    final flagged = around.where((n) => cells[n].flagged).length;
    if (flagged != cell.nearby) return RevealOutcome.none;

    var outcome = RevealOutcome.none;
    for (final next in around) {
      if (cells[next].flagged || cells[next].revealed) continue;
      final result = reveal(next);
      if (result == RevealOutcome.exploded) return result;
      if (result == RevealOutcome.safe) outcome = RevealOutcome.safe;
    }
    return outcome;
  }

  bool toggleFlag(int index) {
    if (lost || won) return false;
    final cell = cells[index];
    if (cell.revealed) return false;
    cell.flagged = !cell.flagged;
    return true;
  }

  /// The safest unrevealed tile to show as a hint, or null when none is left.
  int? hintCandidate() {
    if (!_armed || lost || won) return null;
    final candidates = [
      for (var i = 0; i < cells.length; i++)
        if (!cells[i].mine && !cells[i].revealed && !cells[i].flagged) i,
    ];
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => cells[a].nearby.compareTo(cells[b].nearby));
    return candidates.first;
  }
}
