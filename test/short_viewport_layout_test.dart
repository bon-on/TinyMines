import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/mine_field.dart';
import 'package:tiny_mines/platform/game_platform.dart';
import 'package:tiny_mines/src/game/garden_run.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/meta/garden_progress_store.dart';
import 'package:tiny_mines/src/ui/garden_board.dart';
import 'package:tiny_mines/src/ui/garden_ui.dart';

import 'support/fake_stopwatch.dart';

// feature-short-viewport-layout: the board comes first in small portal
// iframes (GamePix "Small" preview 620x349, 640x480 minimum) and short phones.

class _Tutorial extends TutorialStore {
  _Tutorial(this.seen);
  bool seen;
  @override
  Future<bool> hasSeen() async => seen;
  @override
  Future<void> markSeen() async => seen = true;
}

/// Window size -> smallest board side (px) accepted in every state.
const List<(Size, double)> _minBoard = [
  (Size(620, 349), 240),
  (Size(600, 338), 230),
  (Size(560, 315), 210),
  (Size(640, 480), 280),
  (Size(667, 375), 260),
  (Size(844, 390), 250),
  (Size(932, 430), 280),
  (Size(360, 640), 260),
  (Size(390, 844), 320),
  (Size(320, 568), 200),
  (Size(1280, 720), 420),
  (Size(1366, 768), 460),
];

enum _State { firstRun, easy, hard, run }

Finder get _board => find.byKey(const ValueKey('garden-board'));
Finder get _tiles =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));

Future<void> _pump(WidgetTester tester, Size size, {bool first = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(1),
        progressStore: MemoryGardenProgressStore(
          first
              ? const GardenProgress.initial()
              : GardenProgress.fromJson({'runsPlayed': 1, 'bestRunStage': 3}),
        ),
        tutorialStore: _Tutorial(!first),
        stopwatch: FakeStopwatch(),
        now: () => DateTime(2026, 11, 2, 9),
        platform: const NoopGamePlatform(allowsResultRegistration: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _startRun(WidgetTester tester) async {
  final cta = find.byKey(const ValueKey('garden-run-cta'));
  final wide = find.text('Start Garden Run');
  final button = cta.evaluate().isNotEmpty
      ? cta
      : wide.evaluate().isNotEmpty
      ? wide
      : find.textContaining('Garden Run -');
  await tester.tap(button.first);
  await tester.pumpAndSettle();
}

/// Controls the board must never cover.
List<Finder> get _controls => [
  find.byKey(const ValueKey('dig-mode')),
  find.byKey(const ValueKey('flag-mode')),
  find.byType(DifficultyPicker),
  find.byType(GardenIconButton),
  find.byKey(const ValueKey('onboarding-strip')),
  find.byKey(const ValueKey('status-line')),
  find.byKey(const ValueKey('garden-run-cta')),
  find.byKey(const ValueKey('board-hearts')),
  find.byType(LevelBadge),
];

void _expectBoardClear(WidgetTester tester, Size size) {
  final board = tester.getRect(_board);
  expect(board.left, greaterThanOrEqualTo(0));
  expect(board.top, greaterThanOrEqualTo(0));
  expect(board.right, lessThanOrEqualTo(size.width + 0.01));
  expect(board.bottom, lessThanOrEqualTo(size.height + 0.01));
  for (final finder in _controls) {
    for (final element in finder.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget).first);
      final overlap = rect.intersect(board);
      expect(
        overlap.width <= 0.5 || overlap.height <= 0.5,
        isTrue,
        reason: '${element.widget.runtimeType} $rect overlaps board $board',
      );
      // Every control is fully on screen.
      expect(rect.left, greaterThanOrEqualTo(-0.01));
      expect(rect.top, greaterThanOrEqualTo(-0.01));
      expect(rect.right, lessThanOrEqualTo(size.width + 0.01));
      expect(rect.bottom, lessThanOrEqualTo(size.height + 0.01));
    }
  }
}

/// Cell side of a [cells] x [cells] grid in a grid box of [grid] px (3 px
/// gaps, as boards wider than 10 use).
double _cellFor(double grid, int cells) => (grid - (cells - 1) * 3) / cells;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('screenLayoutFor picks the layout per window', () {
    for (final size in const [
      Size(620, 349),
      Size(600, 338),
      Size(560, 315),
      Size(640, 480),
      Size(667, 375),
    ]) {
      expect(screenLayoutFor(size), ScreenLayout.compact, reason: '$size');
    }
    for (final size in const [
      Size(844, 390),
      Size(932, 430),
      Size(1280, 720),
      Size(1366, 768),
    ]) {
      expect(screenLayoutFor(size), ScreenLayout.wide, reason: '$size');
    }
    for (final size in const [
      Size(360, 640),
      Size(390, 844),
      Size(320, 568),
      Size(800, 800),
    ]) {
      expect(screenLayoutFor(size), ScreenLayout.stacked, reason: '$size');
    }
  });

  for (final (size, minSide) in _minBoard) {
    for (final state in _State.values) {
      testWidgets('${state.name} at $size: board first, no overlap', (
        tester,
      ) async {
        await _pump(tester, size, first: state == _State.firstRun);
        if (state == _State.firstRun) {
          expect(
            find.byKey(const ValueKey('onboarding-strip')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('garden-run-cta')), findsOneWidget);
        }
        if (state == _State.hard) {
          await tester.tap(find.text('Hard 12x12'));
          await tester.pumpAndSettle();
          expect(_tiles, findsNWidgets(144));
        }
        if (state == _State.run) {
          await _startRun(tester);
          expect(find.byKey(const ValueKey('board-hearts')), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        final board = tester.getRect(_board);
        expect(board.height, greaterThanOrEqualTo(minSide));
        _expectBoardClear(tester, size);
        if (state == _State.hard) {
          expect(tester.getSize(_tiles.first).width, greaterThanOrEqualTo(14));
        }
        if (state == _State.run) {
          // Every Garden Run stage uses this board box; at 12x12 (stage 10
          // on) the cells stay tappable.
          final grid = tester.getRect(find.byType(GridView));
          expect(_cellFor(grid.width, 12), greaterThanOrEqualTo(14));
        }
        // The first visible tile digs on tap.
        await tester.tap(_tiles.first);
        await tester.pump();
        expect(
          tester.widget<GardenBoard>(find.byType(GardenBoard)).field.armed,
          isTrue,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in const [Size(620, 349), Size(560, 315), Size(320, 568)]) {
    testWidgets('Dig/Flag and the menus work at $size', (tester) async {
      await _pump(tester, size);
      final flag = find.byKey(const ValueKey('flag-mode'));
      await tester.tap(flag);
      await tester.pump();
      expect(tester.getSemantics(flag), isSemantics(isSelected: true));
      await tester.tap(_tiles.first);
      await tester.pump();
      final field = tester.widget<GardenBoard>(find.byType(GardenBoard)).field;
      expect(field.cells.first.flagged, isTrue);
      expect(field.armed, isFalse);
      await tester.tap(find.byKey(const ValueKey('dig-mode')));
      await tester.pump();

      // Garden overlay.
      final garden = find.byTooltip('Garden');
      await tester.tap(
        garden.evaluate().isNotEmpty ? garden : find.text('Garden').first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // How to play, on a fresh screen.
      await _pump(tester, size);
      await tester.tap(find.byTooltip('How to play'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the result card fits at $size', (tester) async {
      await _pump(tester, size);
      // Same seed and call order as the screen's first Easy board.
      final reference = MineField(
        size: 6,
        mineCount: 5,
        random: math.Random(1),
        requireLogicalSolution: true,
      )..reveal(0);
      await tester.tap(_tiles.at(0));
      await tester.pump();
      final mole = [
        for (var i = 0; i < 36; i++)
          if (reference.cells[i].mine) i,
      ].first;
      await tester.tap(_tiles.at(mole));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = find.text('New Field');
      expect(button, findsOneWidget);
      final rect = tester.getRect(button);
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      expect(rect.top, greaterThanOrEqualTo(0));
      // The XP gained is visible above the pinned actions.
      final xp = tester.getRect(find.textContaining(RegExp(r'^\+\d+ XP$')));
      expect(xp.bottom, lessThanOrEqualTo(rect.top));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('New Field'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in const [Size(620, 349), Size(560, 315), Size(320, 568)]) {
    testWidgets('a real 12x12 Garden Run board fits at $size', (tester) async {
      await _pump(tester, size);
      await _startRun(tester);
      final random = math.Random(1);
      for (var stage = 1; stage <= 9; stage++) {
        final config = GardenRun.stage(stage);
        final side = config.size;
        final start = (side ~/ 2) * side + side ~/ 2;
        final reference = MineField(
          size: side,
          mineCount: config.mines,
          random: random,
          requireLogicalSolution: config.fairStart,
          survivable: true,
        )..reveal(start);
        final replay =
            MineField(size: side, mineCount: config.mines, survivable: true)
              ..plantMinesAt([
                for (var i = 0; i < reference.cells.length; i++)
                  if (reference.cells[i].mine) i,
              ]);
        for (final i in [
          start,
          for (var i = 0; i < reference.cells.length; i++)
            if (i != start) i,
        ]) {
          if (reference.cells[i].mine || replay.cells[i].revealed) continue;
          replay.reveal(i);
          await tester.tap(_tiles.at(i));
          await tester.pump();
        }
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(_tiles, findsNWidgets(144));
      expect(find.byKey(const ValueKey('boss-tag')), findsOneWidget);
      final cell = tester.getSize(_tiles.first);
      expect(cell.width, greaterThanOrEqualTo(14));
      _expectBoardClear(tester, size);
      await tester.tap(_tiles.at(5 * 12 + 5));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
