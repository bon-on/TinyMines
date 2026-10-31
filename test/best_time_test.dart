import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/best_times.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/mine_field.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({'tutorial_seen_v1': true}),
  );
  registerHintedWin();

  test('BestTimes keeps only the fastest time per difficulty', () async {
    const store = BestTimes();
    expect(await store.load('easy'), isNull);
    expect(await store.record('easy', 90), isTrue);
    expect(await store.record('easy', 120), isFalse);
    expect(await store.record('easy', 75), isTrue);
    expect(await store.load('easy'), 75);
    expect(await store.load('hard'), isNull);
  });

  test('wrongFlags lists flags on safe tiles only after a loss', () {
    final field = MineField(size: 3, mineCount: 1)..plantMinesAt([0]);
    field.toggleFlag(0);
    field.toggleFlag(8);
    expect(field.wrongFlags, isEmpty);
    field.cells[0].flagged = false;
    field.reveal(0);
    expect(field.lost, isTrue);
    expect(field.wrongFlags, [8]);
  });

  testWidgets('HUD shows the stored best time per difficulty', (tester) async {
    SharedPreferences.setMockInitialValues({
      'best_time_easy': 65,
      'tutorial_seen_v1': true,
    });
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: TinyMinesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Best'), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);

    await tester.tap(find.text('Hard 12x12'));
    await tester.pumpAndSettle();
    expect(find.text('--'), findsOneWidget);
    expect(find.text('26'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in const [Size(390, 844), Size(1280, 720)]) {
    testWidgets('Hard board fits without overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const TinyMinesApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hard 12x12'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final grid = tester.getRect(find.byType(GridView));
      expect(grid.width, lessThanOrEqualTo(560));
      expect(grid.bottom, lessThanOrEqualTo(size.height));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

void registerHintedWin() {
  testWidgets('a hinted win stores the best time including the penalty', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Learn the mine layout the screen will get from the same seed.
    final probe = MineField(size: 6, mineCount: 5, random: math.Random(1))
      ..plantMines(0);
    await tester.pumpWidget(
      MaterialApp(home: TinyMinesScreen(random: math.Random(1))),
    );
    final tiles = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(InkWell),
    );
    await tester.tap(tiles.at(0));
    await tester.pump();
    await tester.tap(find.byTooltip('Reveal one safe tile (+10s)'));
    await tester.pump();
    for (var i = 0; i < 36; i++) {
      if (probe.cells[i].mine) continue;
      await tester.tap(tiles.at(i), warnIfMissed: false);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('Field cleared in 0:10'), findsOneWidget);
    expect(await const BestTimes().load('easy'), 10);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
