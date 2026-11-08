import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/mine_field.dart';
import 'package:tiny_mines/platform/game_platform.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/meta/garden_progress_store.dart';

import 'support/fake_stopwatch.dart';

class _Store extends TutorialStore {
  _Store({this.seen = false, this.failRead = false, this.failWrite = false});
  bool seen;
  final bool failRead;
  final bool failWrite;
  int writes = 0;

  @override
  Future<bool> hasSeen() async {
    if (failRead) throw StateError('read failed');
    return seen;
  }

  @override
  Future<void> markSeen() async {
    writes += 1;
    if (failWrite) throw StateError('write failed');
    seen = true;
  }
}

Finder get _tiles =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));
Finder get _strip => find.byKey(const ValueKey('onboarding-strip'));
Finder get _cta => find.byKey(const ValueKey('garden-run-cta'));

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(800, 1400),
  TutorialStore? tutorial,
  GardenProgress progress = const GardenProgress.initial(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(1),
        progressStore: MemoryGardenProgressStore(progress),
        tutorialStore: tutorial ?? _Store(),
        stopwatch: FakeStopwatch(),
        now: () => DateTime(2026, 11, 2, 9),
        platform: const NoopGamePlatform(allowsResultRegistration: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Same seed and call order as the screen's first Easy board.
MineField _easy() => MineField(
  size: 6,
  mineCount: 5,
  random: math.Random(1),
  requireLogicalSolution: true,
)..reveal(0);

Future<void> _winEasy(WidgetTester tester) async {
  final reference = _easy();
  final replay = MineField(
    size: 6,
    mineCount: 5,
    random: math.Random(1),
    requireLogicalSolution: true,
  );
  for (var i = 0; i < 36; i++) {
    if (reference.cells[i].mine || replay.cells[i].revealed) continue;
    replay.reveal(i);
    await tester.tap(_tiles.at(i));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tips follow the first dig and the first flag', (tester) async {
    await _pump(tester);
    expect(find.text('Start anywhere - your first dig is safe.'), findsOne);
    expect(find.text('Tap any patch to dig.'), findsOne);
    await tester.tap(_tiles.at(0));
    await tester.pump();
    expect(find.text('A number counts the moles touching it.'), findsOne);
    final mine = _easy().cells.indexWhere((c) => c.mine);
    await tester.longPress(_tiles.at(mine));
    await tester.pump();
    expect(find.text('Nice flag!'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the first finished board ends the tips and stores the flag', (
    tester,
  ) async {
    final store = _Store();
    await _pump(tester, tutorial: store);
    final mine = _easy().cells.indexWhere((c) => c.mine);
    await tester.tap(_tiles.at(0));
    await tester.pump();
    expect(store.seen, isFalse);
    await tester.tap(_tiles.at(mine));
    await tester.pumpAndSettle();
    expect(store.seen, isTrue);
    expect(_strip, findsNothing);
  });

  testWidgets('a read failure shows tips; a write failure is harmless', (
    tester,
  ) async {
    final store = _Store(failRead: true, failWrite: true);
    await _pump(tester, tutorial: store);
    expect(_strip, findsOneWidget);
    await tester.tap(find.byTooltip('Hide tips'));
    await tester.pumpAndSettle();
    expect(_strip, findsNothing);
    expect(store.writes, 1);
    expect(tester.takeException(), isNull);
    await tester.tap(_tiles.at(0));
    await tester.pump();
    expect(find.text('Moves'), findsOne);
  });

  for (final size in const [Size(390, 844), Size(1280, 720)]) {
    testWidgets('Try Garden Run is promoted before the first run at $size', (
      tester,
    ) async {
      await _pump(tester, size: size);
      expect(_cta, findsOneWidget);
      expect(find.text('Try Garden Run'), findsOneWidget);
      expect(find.text('3 hearts, bigger gardens'), findsOneWidget);
      await tester.tap(_cta);
      await tester.pumpAndSettle();
      expect(_tiles, findsNWidgets(25), reason: 'stage 1 is 5x5');
      expect(_cta, findsNothing);
    });
  }

  testWidgets('a played run brings back the best-stage entry', (tester) async {
    final played = GardenProgress.fromJson({
      'runsPlayed': 1,
      'bestRunStage': 4,
    });
    await _pump(tester, size: const Size(390, 844), progress: played);
    expect(_cta, findsNothing);
    expect(find.text('Garden Run - best stage 4'), findsOneWidget);
  });

  testWidgets('the first regular win offers Try Garden Run', (tester) async {
    await _pump(tester, tutorial: _Store(seen: true));
    await _winEasy(tester);
    expect(find.text('Garden cleared!'), findsOneWidget);
    expect(find.byKey(const ValueKey('next-goal')), findsOneWidget);
    expect(find.text('Play your first Garden Run'), findsOneWidget);
    final inSummary = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: _cta,
    );
    expect(inSummary, findsOneWidget);
    await tester.tap(inSummary);
    await tester.pumpAndSettle();
    expect(find.text('Garden cleared!'), findsNothing);
    expect(_tiles, findsNWidgets(25));
  });

  for (final size in const [
    Size(390, 844),
    Size(1280, 720),
    Size(1366, 768),
    Size(844, 390),
  ]) {
    testWidgets('tips and call to action fit without overflow at $size', (
      tester,
    ) async {
      await _pump(tester, size: size);
      expect(_strip, findsOneWidget);
      expect(_cta, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(_tiles.at(0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final strip = tester.getRect(_strip);
      expect(strip.bottom, lessThanOrEqualTo(size.height));
      expect(strip.right, lessThanOrEqualTo(size.width));
    });
  }
}
