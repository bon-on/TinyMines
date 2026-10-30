import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/mine_field.dart';

/// 4x4 field with mines at (0,0) and (3,3).
MineField _fieldWithCornerMines() =>
    MineField(size: 4, mineCount: 2)..plantMinesAt(const [0, 15]);

void main() {
  test('first reveal never hits a mine or its neighbors', () {
    for (var seed = 0; seed < 50; seed++) {
      final field = MineField(size: 6, mineCount: 5, random: math.Random(seed));
      expect(field.reveal(14), RevealOutcome.safe);
      expect(field.cells.where((c) => c.mine).length, 5);
      for (final index in [14, ...field.neighbors(14)]) {
        expect(field.cells[index].mine, isFalse);
      }
    }
  });

  test('tapping a flag before the first reveal does not plant mines', () {
    final field = MineField(size: 6, mineCount: 5, random: math.Random(3));
    field.toggleFlag(0);
    expect(field.reveal(0), RevealOutcome.none);
    expect(field.armed, isFalse);

    expect(field.reveal(35), RevealOutcome.safe);
    for (final index in [35, ...field.neighbors(35)]) {
      expect(field.cells[index].mine, isFalse);
    }
  });

  test('chord reveals the unflagged neighbors when flags match', () {
    final field = _fieldWithCornerMines();
    field.reveal(5);
    expect(field.cells[5].nearby, 1);
    expect(field.cells[1].revealed, isFalse);

    expect(field.chord(5), RevealOutcome.none, reason: 'no flag yet');
    field.toggleFlag(0);
    expect(field.chord(5), RevealOutcome.safe);

    for (final index in [1, 2, 4, 6, 8, 9, 10]) {
      expect(field.cells[index].revealed, isTrue, reason: 'cell $index');
    }
    expect(field.cells[0].revealed, isFalse);
  });

  test('chord with a wrong flag explodes', () {
    final field = _fieldWithCornerMines();
    field.reveal(5);
    field.toggleFlag(1);

    expect(field.chord(5), RevealOutcome.exploded);
    expect(field.lost, isTrue);
  });

  test('flags cannot go on revealed cells and block reveals', () {
    final field = _fieldWithCornerMines();
    field.reveal(5);
    expect(field.toggleFlag(5), isFalse);

    expect(field.toggleFlag(1), isTrue);
    expect(field.reveal(1), RevealOutcome.none);
    expect(field.flags, 1);
  });

  test('hint candidate is a safe unrevealed tile', () {
    expect(
      MineField(size: 4, mineCount: 2).hintCandidate(),
      isNull,
      reason: 'mines are not planted before the first reveal',
    );

    final field = _fieldWithCornerMines();

    field.reveal(5);
    final hint = field.hintCandidate();
    expect(hint, isNotNull);
    expect(field.cells[hint!].mine, isFalse);
    expect(field.cells[hint].revealed, isFalse);
  });

  test('revealing every safe tile wins', () {
    final field = _fieldWithCornerMines();
    for (var i = 1; i < 15; i++) {
      field.reveal(i);
    }
    expect(field.won, isTrue);
    expect(field.lost, isFalse);
  });
}
