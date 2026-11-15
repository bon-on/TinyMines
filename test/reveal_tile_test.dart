import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/mine_field.dart';

void main() {
  test('revealTile opens one safe tile without cascading', () {
    final field = MineField(size: 8, mineCount: 6, random: math.Random(4));
    expect(field.revealTile(0), isFalse, reason: 'not armed yet');
    field.reveal(27);
    final center = field.hintCandidate();
    expect(center, isNotNull);
    final before = field.cells.where((c) => c.revealed).length;
    expect(field.revealTile(center!), isTrue);
    expect(field.cells.where((c) => c.revealed).length, before + 1);
    expect(field.revealTile(center), isFalse, reason: 'already open');
  });

  test('revealTile never opens a mole or a flagged tile', () {
    final field = MineField(size: 8, mineCount: 6, random: math.Random(4));
    field.reveal(27);
    final mole = field.cells.indexWhere((c) => c.mine);
    expect(field.revealTile(mole), isFalse);
    expect(field.cells[mole].revealed, isFalse);
    final hidden = field.cells.indexWhere((c) => !c.mine && !c.revealed);
    field.toggleFlag(hidden);
    expect(field.revealTile(hidden), isFalse);
  });
}
