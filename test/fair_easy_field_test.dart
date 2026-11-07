import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/fair_easy_field.dart';
import 'package:tiny_mines/mine_field.dart';
import 'package:tiny_mines/src/meta/daily_challenge.dart';

class _IdentityRandom implements math.Random {
  int calls = 0;
  @override
  int nextInt(int max) {
    calls++;
    return max - 1;
  }

  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0.5;
}

List<int> _mines(MineField field) => [
  for (var i = 0; i < field.cells.length; i++)
    if (field.cells[i].mine) i,
];

// An independent player of the real MineField API. This driver never reads a
// covered cell's nearby count or any cell's mine bit, and does not call the
// generator's proof solver. Every conclusion is made from visible constraints.
bool _finishFromVisibleClues(MineField field) {
  for (var turn = 0; turn < field.cells.length; turn++) {
    if (field.won) return true;
    final covered = <int>{};
    for (var i = 0; i < field.cells.length; i++) {
      if (!field.cells[i].revealed && !field.cells[i].flagged) covered.add(i);
    }
    final groups = <({Set<int> cells, int count})>[
      (cells: covered, count: field.mineCount - field.flags),
    ];
    for (var i = 0; i < field.cells.length; i++) {
      if (!field.cells[i].revealed) continue;
      final around = field.neighbors(i).toList();
      final unknown = around.where(covered.contains).toSet();
      if (unknown.isNotEmpty) {
        groups.add((
          cells: unknown,
          count:
              field.cells[i].nearby -
              around.where((n) => field.cells[n].flagged).length,
        ));
      }
    }
    final open = <int>{};
    final flags = <int>{};
    void conclude(Set<int> cells, int count) {
      if (count == 0) open.addAll(cells);
      if (count == cells.length) flags.addAll(cells);
    }

    for (final g in groups) {
      conclude(g.cells, g.count);
    }
    for (var i = 0; i < groups.length; i++) {
      for (var j = 0; j < groups.length; j++) {
        final a = groups[i], b = groups[j];
        if (a.cells.length < b.cells.length && b.cells.containsAll(a.cells)) {
          conclude(b.cells.difference(a.cells), b.count - a.count);
        }
      }
    }
    expect(open.intersection(flags), isEmpty);
    if (open.isEmpty && flags.isEmpty) return false;
    for (final index in flags) {
      expect(field.toggleFlag(index), isTrue);
    }
    for (final index in open) {
      if (field.won) break;
      final result = field.reveal(index);
      expect(result, isNot(RevealOutcome.exploded));
    }
    expect(field.lost, isFalse);
  }
  return field.won;
}

void main() {
  test(
    'reproduced ambiguous Easy seeds are replaced by logic-solvable fields',
    () {
      for (final seed in [0, 5, 17]) {
        final old = MineField(size: 6, mineCount: 5, random: math.Random(seed));
        old.reveal(21);
        expect(FairEasyField.solvable(_mines(old), 21), isFalse);
        final fair = MineField(
          size: 6,
          mineCount: 5,
          random: math.Random(seed),
          requireLogicalSolution: true,
        );
        fair.reveal(21);
        expect(fair.won, isFalse);
        expect(_finishFromVisibleClues(fair), isTrue);
      }
    },
  );

  test(
    '100 seeds for every first cell retain exact mine count and safe opening',
    () {
      for (var start = 0; start < 36; start++) {
        for (var seed = 0; seed < 100; seed++) {
          final field = MineField(
            size: 6,
            mineCount: 5,
            random: math.Random(seed),
            requireLogicalSolution: true,
          );
          expect(field.reveal(start), RevealOutcome.safe);
          expect(_mines(field).length, 5);
          expect(field.cells[start].nearby, 0);
          expect(
            field.neighbors(start).any((n) => field.cells[n].mine),
            isFalse,
          );
          expect(field.won, isFalse, reason: 'leave play after the opening');
          expect(FairEasyField.solvable(_mines(field), start), isTrue);
          expect(
            field.flags,
            0,
            reason: 'proof never changes the actual field',
          );
        }
      }
    },
  );

  test(
    'independent visible-clue player finishes 20 seeds at every opening',
    () {
      for (var start = 0; start < 36; start++) {
        for (var seed = 0; seed < 20; seed++) {
          final field = MineField(
            size: 6,
            mineCount: 5,
            random: math.Random(seed),
            requireLogicalSolution: true,
          );
          field.reveal(start);
          expect(
            _finishFromVisibleClues(field),
            isTrue,
            reason: 'start=$start seed=$seed',
          );
        }
      }
    },
  );

  test('adversarial RNG stops at fixed bound and uses verified fallback', () {
    final rng = _IdentityRandom();
    expect(FairEasyField.solvable([2, 3, 4, 5, 8], 0), isFalse);
    final field = MineField(
      size: 6,
      mineCount: 5,
      random: rng,
      requireLogicalSolution: true,
    );
    field.reveal(0);
    expect(rng.calls, FairEasyField.maxAttempts * 31);
    expect(_mines(field), [22, 32, 33, 34, 35]);
    expect(_finishFromVisibleClues(field), isTrue);
  });

  test(
    'all 36 emergency layouts are safe, nonterminal and independently solved',
    () {
      for (var start = 0; start < 36; start++) {
        final placement = FairEasyField.fallback(start);
        expect(placement.toSet().length, 5);
        expect(
          placement.any({start, ...FairEasyField.neighbors(start)}.contains),
          isFalse,
        );
        final field = MineField(size: 6, mineCount: 5)..plantMinesAt(placement);
        field.reveal(start);
        expect(field.won, isFalse);
        expect(_finishFromVisibleClues(field), isTrue);
        placement.clear();
        expect(FairEasyField.fallback(start).length, 5);
      }
    },
  );

  test('visible subset numbers prove safe cells without covered truth', () {
    final clues = List<int?>.filled(36, null);
    clues[0] = 1;
    clues[1] = 1;
    final moves = FairEasyField.deduce(clues, {});
    expect(moves.safe, containsAll([2, 8]));
    expect(moves.mines, isEmpty);
    final ambiguous = List<int?>.filled(36, null)..[0] = 1;
    final noGuess = FairEasyField.deduce(ambiguous, {});
    expect(noGuess.safe, isEmpty);
    expect(noGuess.mines, isEmpty);
  });

  test('accepted first candidate preserves exact old seeded placement', () {
    for (final start in [0, 1, 7, 14, 21, 35]) {
      var checked = false;
      for (var seed = 0; seed < 30; seed++) {
        final old = MineField(size: 6, mineCount: 5, random: math.Random(seed));
        old.reveal(start);
        if (!FairEasyField.solvable(_mines(old), start)) continue;
        final fair = MineField(
          size: 6,
          mineCount: 5,
          random: math.Random(seed),
          requireLogicalSolution: true,
        );
        fair.reveal(start);
        expect(_mines(fair), _mines(old));
        checked = true;
        break;
      }
      expect(checked, isTrue);
    }
  });

  test(
    'policy is opt-in; default Normal, Hard and dated daily remain unchanged',
    () {
      expect(
        () => MineField(size: 9, mineCount: 12, requireLogicalSolution: true),
        throwsArgumentError,
      );
      for (final (size, count, start) in [
        (6, 5, 21),
        (9, 12, 40),
        (12, 26, 78),
      ]) {
        final field = MineField(
          size: size,
          mineCount: count,
          random: math.Random(42),
        );
        field.reveal(start);
        final blocked = {start, ...field.neighbors(start)};
        final expected = [
          for (var i = 0; i < size * size; i++)
            if (!blocked.contains(i)) i,
        ]..shuffle(math.Random(42));
        expect(_mines(field), (expected.take(count).toList()..sort()));
        expect(field.requireLogicalSolution, isFalse);
      }
      final (daily, start) = DailyChallenge.build(DateTime(2026, 11, 5));
      expect(daily.requireLogicalSolution, isFalse);
      expect(daily.size, 9);
      expect(daily.mineCount, 12);
      expect(daily.cells[start].revealed, isTrue);
    },
  );

  test('pre-opening flags and normal mine loss are preserved', () {
    final field = MineField(
      size: 6,
      mineCount: 5,
      random: math.Random(0),
      requireLogicalSolution: true,
    );
    field.toggleFlag(0);
    expect(field.reveal(0), RevealOutcome.none);
    expect(field.armed, isFalse);
    field.reveal(21);
    expect(field.cells[0].flagged, isTrue);
    final mine = _mines(field).firstWhere((i) => !field.cells[i].flagged);
    expect(field.reveal(mine), RevealOutcome.exploded);
    expect(field.lost, isTrue);
  });
}
