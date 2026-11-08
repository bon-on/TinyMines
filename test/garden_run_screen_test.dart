import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/mine_field.dart';
import 'package:tiny_mines/platform/game_platform.dart';
import 'package:tiny_mines/src/game/garden_run.dart';
import 'package:tiny_mines/src/meta/garden_progress_store.dart';
import 'package:tiny_mines/src/ui/garden_cards.dart';

import 'support/fake_stopwatch.dart';

class _Seen extends TutorialStore {
  @override
  Future<bool> hasSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

class _RecordingPlatform extends NoopGamePlatform {
  _RecordingPlatform() : super(allowsResultRegistration: false);
  final List<String> events = <String>[];
  @override
  void gameplayStart() => events.add('start');
  @override
  void gameplayStop() => events.add('stop');
}

Finder get _tiles =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));

Finder _hudStage(int stage) => find.descendant(
  of: find.byType(GardenRunHud),
  matching: find.text('Stage $stage'),
);

Finder _hintCount(int count) =>
    find.descendant(of: find.byType(Badge), matching: find.text('$count'));

Finder get _bigHearts => find.descendant(
  of: find.byKey(const ValueKey('board-hearts')),
  matching: find.byIcon(Icons.favorite_rounded),
);

Finder get _fullHearts => find.descendant(
  of: find.byKey(const ValueKey('run-hearts')),
  matching: find.byIcon(Icons.favorite_rounded),
);

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(800, 1400),
  GardenProgressStore? store,
  GamePlatform? platform,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(1),
        progressStore: store ?? MemoryGardenProgressStore(),
        tutorialStore: _Seen(),
        stopwatch: FakeStopwatch(),
        now: () => DateTime(2026, 11, 2, 9),
        platform: platform ?? const NoopGamePlatform(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _startRun(WidgetTester tester) async {
  final wide = find.text('Start Garden Run');
  final button = wide.evaluate().isNotEmpty
      ? wide
      : find.textContaining('Garden Run -');
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// Mirrors the screen's board generation (same seed, same call order) so the
/// test knows where the moles are.
class _Garden {
  final math.Random random = math.Random(1);

  /// Reference board for [stage], dug at [first].
  MineField stage(int stage, int first) {
    final config = GardenRun.stage(stage);
    return MineField(
      size: config.size,
      mineCount: config.mines,
      random: random,
      requireLogicalSolution: config.fairStart,
      survivable: true,
    )..reveal(first);
  }
}

/// Digs every safe tile of the board shown on screen, starting at [first].
Future<void> _clear(WidgetTester tester, MineField reference, int first) async {
  final replay =
      MineField(
        size: reference.size,
        mineCount: reference.mineCount,
        survivable: true,
      )..plantMinesAt([
        for (var i = 0; i < reference.cells.length; i++)
          if (reference.cells[i].mine) i,
      ]);
  final order = [
    first,
    for (var i = 0; i < reference.cells.length; i++)
      if (i != first) i,
  ];
  for (final i in order) {
    if (reference.cells[i].mine || replay.cells[i].revealed) continue;
    replay.reveal(i);
    await tester.tap(_tiles.at(i));
    await tester.pump();
  }
}

Future<void> _tap(WidgetTester tester, int index) async {
  await tester.tap(_tiles.at(index));
  await tester.pump();
}

List<int> _moles(MineField field) => [
  for (var i = 0; i < field.cells.length; i++)
    if (field.cells[i].mine) i,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a run starts on a 5x5 board with three hearts', (tester) async {
    await _pump(tester);
    expect(_tiles, findsNWidgets(36));
    await _startRun(tester);
    expect(_tiles, findsNWidgets(25));
    expect(_hudStage(1), findsOneWidget);
    expect(_fullHearts, findsNWidgets(3));
    expect(find.text('Run 0:00'), findsOneWidget);
  });

  testWidgets('a dug mole costs a heart, shows a mole and play continues', (
    tester,
  ) async {
    final store = MemoryGardenProgressStore();
    await _pump(tester, store: store);
    await _startRun(tester);
    final ref = _Garden().stage(1, 12);
    await _tap(tester, 12);
    final mole = _moles(ref).first;
    await _tap(tester, mole);
    expect(_fullHearts, findsNWidgets(2));
    expect(find.textContaining('lost a heart (2 left)'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GridView),
        matching: find.bySemanticsLabel('Mole'),
      ),
      findsOneWidget,
    );
    // The board is still live: a safe tile can be dug and the summary is closed.
    final safe = [
      for (var i = 0; i < 25; i++)
        if (!ref.cells[i].mine && !ref.cells[i].revealed) i,
    ];
    await _tap(tester, safe.first);
    expect(find.text('Run over!'), findsNothing);
    // Digging the exploded mole again does nothing.
    await _tap(tester, mole);
    expect(_fullHearts, findsNWidgets(2));
    expect(store.saveCount, 0);
  });

  testWidgets('the last heart ends the run: summary, XP once, records only', (
    tester,
  ) async {
    final store = MemoryGardenProgressStore();
    final platform = _RecordingPlatform();
    await _pump(tester, store: store, platform: platform);
    await _startRun(tester);
    expect(platform.events, ['start']);
    final ref = _Garden().stage(1, 12);
    await _tap(tester, 12);
    for (final mole in _moles(ref)) {
      await _tap(tester, mole);
    }
    await tester.pumpAndSettle();
    expect(find.text('Run over!'), findsOneWidget);
    expect(find.text('Garden Run - stage 1 reached'), findsOneWidget);
    expect(find.text('New best stage!'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);
    expect(find.text('CLEARED'), findsOneWidget);
    expect(find.text('New Run'), findsOneWidget);
    expect(find.text('Classic board'), findsOneWidget);
    expect(platform.events, ['start', 'stop']);

    final saved = store.value;
    expect(saved.totalXp, 10);
    expect(saved.runsPlayed, 1);
    expect(saved.bestRunStage, 1);
    expect(saved.bestTimes, isEmpty);
    expect(saved.wins, isEmpty);
    expect(saved.plays, isEmpty);
    expect(saved.daily, isEmpty);
    expect(saved.streak, 0);
    expect(store.saveCount, 1);

    // Closing the card and leaving the run must not pay out a second time.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Run over!'), findsNothing);
    expect(find.text('New Run'), findsOneWidget);
    await tester.tap(find.text('Easy 6x6'));
    await tester.pumpAndSettle();
    expect(store.value.totalXp, 10);
    expect(store.value.runsPlayed, 1);
    expect(store.saveCount, 1);
    expect(platform.events, ['start', 'stop', 'start']);
  });

  testWidgets('Enter on the summary starts a fresh run', (tester) async {
    await _pump(tester);
    await _startRun(tester);
    final ref = _Garden().stage(1, 12);
    await _tap(tester, 12);
    for (final mole in _moles(ref)) {
      await _tap(tester, mole);
    }
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Run over!'), findsNothing);
    expect(_hudStage(1), findsOneWidget);
    expect(_fullHearts, findsNWidgets(3));
    expect(_tiles, findsNWidgets(25));
  });

  testWidgets('a cleared stage starts the next one by itself, no ad stop', (
    tester,
  ) async {
    final store = MemoryGardenProgressStore();
    final platform = _RecordingPlatform();
    await _pump(tester, store: store, platform: platform);
    await _startRun(tester);
    final garden = _Garden();
    final ref = garden.stage(1, 12);
    await _clear(tester, ref, 12);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Stage 1 cleared!'), findsOneWidget);
    expect(find.text('Next stage'), findsOneWidget);
    expect(_tiles, findsNWidgets(25));
    // Gameplay is not stopped between stages and nothing is saved yet.
    expect(platform.events, ['start']);
    expect(store.saveCount, 0);

    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();
    expect(_tiles, findsNWidgets(36));
    expect(_hudStage(2), findsOneWidget);
    expect(find.text('Stage 1 cleared!'), findsNothing);
    expect(platform.events, ['start']);

    // Leaving mid-run ends it: 1 cleared board = 15 + 10 XP, stage 2 reached.
    await tester.tap(find.text('Normal 9x9'));
    await tester.pumpAndSettle();
    expect(_tiles, findsNWidgets(81));
    expect(store.value.totalXp, 25);
    expect(store.value.runsPlayed, 1);
    expect(store.value.bestRunStage, 2);
    expect(store.value.plays, isEmpty);
    expect(store.value.bestTimes, isEmpty);
    expect(store.saveCount, 1);
    expect(platform.events, ['start']);
  });

  testWidgets('Next stage skips the pause', (tester) async {
    await _pump(tester);
    await _startRun(tester);
    final ref = _Garden().stage(1, 12);
    await _clear(tester, ref, 12);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Next stage'));
    await tester.pump();
    expect(_tiles, findsNWidgets(36));
    // The pending auto-advance must not skip a second stage.
    await tester.pump(const Duration(seconds: 3));
    expect(_tiles, findsNWidgets(36));
    expect(_hudStage(2), findsOneWidget);
  });

  testWidgets('hints are shared by the run and cost no time', (tester) async {
    await _pump(tester);
    await _startRun(tester);
    await _tap(tester, 12);
    expect(_hintCount(3), findsOneWidget);
    await tester.tap(find.byIcon(Icons.lightbulb));
    await tester.pump();
    expect(_hintCount(2), findsOneWidget);
    expect(find.text('0:00'), findsWidgets);
  });

  testWidgets('a run without a dig earns nothing', (tester) async {
    final store = MemoryGardenProgressStore();
    await _pump(tester, store: store);
    await _startRun(tester);
    await tester.tap(find.text('Easy 6x6'));
    await tester.pumpAndSettle();
    expect(store.value.totalXp, 0);
    expect(store.value.runsPlayed, 0);
    expect(store.value.bestRunStage, 0);
    expect(store.saveCount, 0);
  });

  for (final loseHeart in [true, false]) {
    testWidgets(
      loseHeart
          ? 'boss stage heals a lost heart; hints grow every third clear'
          : 'boss stage at full hearts says nothing about a heart',
      (tester) async {
        final store = MemoryGardenProgressStore();
        await _pump(tester, store: store);
        await _startRun(tester);
        final garden = _Garden();
        final firsts = {1: 12, 2: 14, 3: 24, 4: 27, 5: 27};
        final ref1 = garden.stage(1, firsts[1]!);
        if (loseHeart) {
          await _tap(tester, firsts[1]!);
          await _tap(tester, _moles(ref1).first);
          expect(_fullHearts, findsNWidgets(2));
        }
        await _clear(tester, ref1, firsts[1]!);
        await tester.pump(const Duration(seconds: 3));
        for (var stage = 2; stage <= 5; stage++) {
          expect(_hudStage(stage), findsOneWidget);
          expect(
            find.byKey(const ValueKey('boss-tag')),
            stage == 5 ? findsOneWidget : findsNothing,
          );
          final ref = garden.stage(stage, firsts[stage]!);
          await _clear(tester, ref, firsts[stage]!);
          await tester.pump(const Duration(milliseconds: 100));
          if (stage == 3) {
            // Third clear: one more hint (3 -> 4).
            expect(_hintCount(4), findsOneWidget);
          }
          if (stage < 5) await tester.pump(const Duration(seconds: 3));
        }
        expect(
          find.text(
            loseHeart
                ? 'Boss garden cleared! +1 heart.'
                : 'Boss garden cleared!',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('+1 heart'),
          loseHeart ? findsOneWidget : findsNothing,
        );
        expect(_fullHearts, findsNWidgets(3));
        expect(store.saveCount, 0);
      },
    );
  }

  testWidgets('a mole shows the Heart lost overlay and the big hearts update', (
    tester,
  ) async {
    await _pump(tester);
    await _startRun(tester);
    expect(_bigHearts, findsNWidgets(3));
    final ref = _Garden().stage(1, 12);
    await _tap(tester, 12);
    expect(find.textContaining('Heart lost!'), findsNothing);
    await _tap(tester, _moles(ref).first);
    // Rules apply at once; the effect trails behind.
    expect(_bigHearts, findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Heart lost! 2 left'), findsOneWidget);
    // Input is not blocked while the effect plays.
    final safe = [
      for (var i = 0; i < 25; i++)
        if (!ref.cells[i].mine && !ref.cells[i].revealed) i,
    ];
    expect(find.text('Heart lost! 2 left'), findsOneWidget);
    final hidden = find.bySemanticsLabel('Hidden tile').evaluate().length;
    await _tap(tester, safe.first);
    expect(tester.takeException(), isNull);
    // The dig went through while the overlay was still up.
    expect(find.text('Heart lost! 2 left'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Hidden tile').evaluate().length,
      lessThan(hidden),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.textContaining('Heart lost!'), findsNothing);
    expect(find.text('Run over!'), findsNothing);
  });

  testWidgets('the last heart still breaks visibly before the summary', (
    tester,
  ) async {
    await _pump(tester);
    await _startRun(tester);
    final ref = _Garden().stage(1, 12);
    await _tap(tester, 12);
    final moles = _moles(ref);
    for (final mole in moles) {
      await _tap(tester, mole);
    }
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Heart lost! 0 left'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Run over!'), findsOneWidget);
  });

  group('layout', () {
    for (final size in const [
      Size(1280, 720),
      Size(1366, 768),
      Size(390, 844),
    ]) {
      testWidgets('the hearts row sits centered above the board at $size', (
        tester,
      ) async {
        await _pump(tester, size: size);
        await _startRun(tester);
        final ref = _Garden().stage(1, 12);
        for (var round = 0; round < 2; round++) {
          expect(tester.takeException(), isNull);
          final row = tester.getRect(
            find.byKey(const ValueKey('board-hearts')),
          );
          final grid = tester.getRect(find.byType(GridView));
          expect(row.bottom, lessThanOrEqualTo(grid.top));
          expect(row.top, greaterThanOrEqualTo(0));
          expect((row.center.dx - grid.center.dx).abs(), lessThan(1));
          expect(row.height, greaterThanOrEqualTo(36));
          expect(_bigHearts, findsNWidgets(3 - round));
          if (round == 0) {
            await _tap(tester, 12);
            await _tap(tester, _moles(ref).first);
            await tester.pump(const Duration(milliseconds: 300));
            // The overlay and shake must not overflow either.
            expect(tester.takeException(), isNull);
            expect(find.text('Heart lost! 2 left'), findsOneWidget);
          }
        }
        await tester.pumpAndSettle();
      });

      testWidgets('a 12x12 run board and its summary fit at $size', (
        tester,
      ) async {
        await _pump(tester, size: size);
        await _startRun(tester);
        expect(tester.takeException(), isNull);

        final garden = _Garden();
        const first = 5 * 12 + 5;
        for (var stage = 1; stage <= 10; stage++) {
          final side = GardenRun.stage(stage).size;
          final start = stage == 10 ? first : (side ~/ 2) * side + side ~/ 2;
          final ref = garden.stage(stage, start);
          if (stage == 10) {
            expect(_tiles, findsNWidgets(144));
            expect(find.byKey(const ValueKey('boss-tag')), findsOneWidget);
            expect(tester.takeException(), isNull);
            final grid = tester.getRect(find.byType(GridView));
            expect(grid.bottom, lessThanOrEqualTo(size.height));
            expect(grid.right, lessThanOrEqualTo(size.width));
            final cell = tester.getSize(_tiles.first);
            expect(cell.width, greaterThanOrEqualTo(24));
            expect(cell.height, greaterThanOrEqualTo(24));
            expect((cell.width - cell.height).abs(), lessThan(0.5));
            // End the run on the boss board.
            await _tap(tester, start);
            for (final mole in _moles(ref).take(3)) {
              await _tap(tester, mole);
            }
            break;
          }
          await _clear(tester, ref, start);
          await tester.pump(const Duration(seconds: 3));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpAndSettle();
        expect(find.text('Run over!'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('View board'));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('View board')).bottom,
          lessThanOrEqualTo(size.height),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });
}
