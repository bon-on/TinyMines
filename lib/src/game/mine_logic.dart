/// Guess-free solver for square minefields (feature-expert-garden).
///
/// It plays like a careful player: it opens the start cell, then only uses
/// what is visible (opened numbers, deduced mines and the shown total mine
/// count). The covered cells' real contents are only read when a cell is
/// opened, to produce its number. A board is guess-free when this solver
/// opens every safe cell.
class MineLogic {
  MineLogic(this.size, this.mineCount)
    : _neighbors = List<List<int>>.generate(size * size, (index) {
        final row = index ~/ size;
        final col = index % size;
        return [
          for (var dr = -1; dr <= 1; dr++)
            for (var dc = -1; dc <= 1; dc++)
              if ((dr != 0 || dc != 0) &&
                  row + dr >= 0 &&
                  row + dr < size &&
                  col + dc >= 0 &&
                  col + dc < size)
                (row + dr) * size + col + dc,
        ];
      });

  final int size;
  final int mineCount;
  final List<List<int>> _neighbors;

  /// Largest frontier component that is enumerated exhaustively.
  static const int maxComponentCells = 28;

  /// Search nodes allowed per component before it is skipped.
  static const int maxNodes = 60000;

  List<int> neighbors(int index) => _neighbors[index];

  /// True when [mines] (cell indexes) can be fully solved from opening
  /// [start] without guessing. [start] and its neighbours must be mine free.
  bool solvable(Set<int> mines, int start) {
    final cells = size * size;
    if (start < 0 || start >= cells) return false;
    if (mines.length != mineCount ||
        mines.any((i) => i < 0 || i >= cells) ||
        mines.contains(start) ||
        _neighbors[start].any(mines.contains)) {
      return false;
    }
    return _Run(this, mines).solve(start);
  }
}

class _Constraint {
  _Constraint(this.cells, this.remaining);
  final List<int> cells;
  final int remaining;
}

class _Run {
  _Run(this.logic, Set<int> mines)
    : size = logic.size,
      isMine = List<bool>.generate(
        logic.size * logic.size,
        mines.contains,
        growable: false,
      ),
      // 0 covered, 1 opened, 2 known mine
      state = List<int>.filled(logic.size * logic.size, 0),
      nearby = List<int>.filled(logic.size * logic.size, 0) {
    for (var i = 0; i < isMine.length; i++) {
      var count = 0;
      for (final n in logic.neighbors(i)) {
        if (isMine[n]) count++;
      }
      nearby[i] = count;
    }
  }

  final MineLogic logic;
  final int size;
  final List<bool> isMine;
  final List<int> state;
  final List<int> nearby;
  int opened = 0;
  int knownMines = 0;

  int get safeTotal => size * size - logic.mineCount;

  void open(int start) {
    final stack = [start];
    while (stack.isNotEmpty) {
      final cell = stack.removeLast();
      if (state[cell] != 0) continue;
      state[cell] = 1;
      opened++;
      if (nearby[cell] == 0) {
        for (final n in logic.neighbors(cell)) {
          if (state[n] == 0) {
            stack.add(n);
          }
        }
      }
    }
  }

  bool solve(int start) {
    open(start);
    // The opening must leave play to do: not an instantly solved board.
    if (opened == safeTotal) return false;
    while (opened < safeTotal) {
      if (!_step()) return false;
    }
    return true;
  }

  List<_Constraint> _constraints() {
    final result = <_Constraint>[];
    for (var i = 0; i < state.length; i++) {
      if (state[i] != 1 || nearby[i] == 0) continue;
      final unknown = <int>[];
      var mines = 0;
      for (final n in logic.neighbors(i)) {
        if (state[n] == 0) {
          unknown.add(n);
        } else if (state[n] == 2) {
          mines++;
        }
      }
      if (unknown.isNotEmpty) {
        result.add(_Constraint(unknown, nearby[i] - mines));
      }
    }
    return result;
  }

  /// Applies one round of deductions; false when nothing could be deduced.
  bool _step() {
    final constraints = _constraints();
    final safe = <int>{};
    final mines = <int>{};

    void apply(List<int> cells, int remaining) {
      if (remaining == 0) safe.addAll(cells);
      if (remaining == cells.length) mines.addAll(cells);
    }

    for (final c in constraints) {
      apply(c.cells, c.remaining);
    }
    if (safe.isEmpty && mines.isEmpty) {
      _subsets(constraints, apply);
    }
    if (safe.isEmpty && mines.isEmpty) {
      final covered = <int>[
        for (var i = 0; i < state.length; i++)
          if (state[i] == 0) i,
      ];
      apply(covered, logic.mineCount - knownMines);
    }
    if (safe.isEmpty && mines.isEmpty) {
      _enumerate(constraints, safe, mines);
    }
    if (safe.isEmpty && mines.isEmpty) return false;
    for (final cell in mines) {
      if (!isMine[cell]) throw StateError('Solver marked a safe cell');
      if (state[cell] == 0) {
        state[cell] = 2;
        knownMines++;
      }
    }
    for (final cell in safe) {
      if (isMine[cell]) throw StateError('Solver opened a mine');
      open(cell);
    }
    return true;
  }

  void _subsets(
    List<_Constraint> constraints,
    void Function(List<int> cells, int remaining) apply,
  ) {
    final byCell = <int, List<int>>{};
    for (var i = 0; i < constraints.length; i++) {
      for (final cell in constraints[i].cells) {
        (byCell[cell] ??= <int>[]).add(i);
      }
    }
    for (var a = 0; a < constraints.length; a++) {
      final small = constraints[a];
      final candidates = <int>{};
      for (final cell in small.cells) {
        candidates.addAll(byCell[cell]!);
      }
      for (final b in candidates) {
        final large = constraints[b];
        if (a == b || large.cells.length <= small.cells.length) continue;
        final largeSet = large.cells.toSet();
        if (!small.cells.every(largeSet.contains)) continue;
        final smallSet = small.cells.toSet();
        apply([
          for (final cell in large.cells)
            if (!smallSet.contains(cell)) cell,
        ], large.remaining - small.remaining);
      }
    }
  }

  /// Exhaustive search per frontier component: a cell that is a mine (or
  /// safe) in every consistent assignment is deduced.
  void _enumerate(
    List<_Constraint> constraints,
    Set<int> safe,
    Set<int> mines,
  ) {
    if (constraints.isEmpty) return;
    // Components of constraints that share covered cells.
    final parent = List<int>.generate(constraints.length, (i) => i);
    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    final owner = <int, int>{};
    for (var i = 0; i < constraints.length; i++) {
      for (final cell in constraints[i].cells) {
        final other = owner[cell];
        if (other == null) {
          owner[cell] = i;
        } else {
          parent[find(i)] = find(other);
        }
      }
    }
    final groups = <int, List<int>>{};
    for (var i = 0; i < constraints.length; i++) {
      (groups[find(i)] ??= <int>[]).add(i);
    }
    for (final group in groups.values) {
      _enumerateGroup([for (final i in group) constraints[i]], safe, mines);
    }
  }

  void _enumerateGroup(List<_Constraint> group, Set<int> safe, Set<int> mines) {
    final cellSet = <int>{for (final c in group) ...c.cells};
    if (cellSet.length > MineLogic.maxComponentCells) return;
    // Order cells so that constraints close early (walk along the frontier).
    final order = <int>[];
    final seen = <int>{};
    final byCell = <int, List<int>>{};
    for (var i = 0; i < group.length; i++) {
      for (final cell in group[i].cells) {
        (byCell[cell] ??= <int>[]).add(i);
      }
    }
    for (final start in cellSet) {
      if (seen.contains(start)) continue;
      final queue = [start];
      seen.add(start);
      for (var q = 0; q < queue.length; q++) {
        final cell = queue[q];
        order.add(cell);
        for (final ci in byCell[cell]!) {
          for (final n in group[ci].cells) {
            if (seen.add(n)) queue.add(n);
          }
        }
      }
    }
    final index = {for (var i = 0; i < order.length; i++) order[i]: i};
    final assigned = List<int>.filled(group.length, 0);
    final left = [for (final c in group) c.cells.length];
    final value = List<int>.filled(order.length, 0);
    final canMine = List<bool>.filled(order.length, false);
    final canSafe = List<bool>.filled(order.length, false);
    var nodes = 0;
    var solutions = 0;
    var aborted = false;

    bool ok(int cell) {
      for (final ci in byCell[order[cell]]!) {
        final c = group[ci];
        if (assigned[ci] > c.remaining) return false;
        if (assigned[ci] + left[ci] < c.remaining) return false;
      }
      return true;
    }

    void dfs(int at) {
      if (aborted) return;
      if (++nodes > MineLogic.maxNodes) {
        aborted = true;
        return;
      }
      if (at == order.length) {
        solutions++;
        for (var i = 0; i < order.length; i++) {
          if (value[i] == 1) {
            canMine[i] = true;
          } else {
            canSafe[i] = true;
          }
        }
        return;
      }
      for (final v in const [0, 1]) {
        value[at] = v;
        for (final ci in byCell[order[at]]!) {
          left[ci]--;
          assigned[ci] += v;
        }
        if (ok(at)) dfs(at + 1);
        for (final ci in byCell[order[at]]!) {
          left[ci]++;
          assigned[ci] -= v;
        }
        if (aborted) return;
      }
    }

    dfs(0);
    if (aborted || solutions == 0) return;
    for (var i = 0; i < order.length; i++) {
      if (!canMine[i]) safe.add(order[i]);
      if (!canSafe[i]) mines.add(order[i]);
    }
    // `index` keeps the cell order stable for debugging.
    assert(index.length == order.length);
  }
}
