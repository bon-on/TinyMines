import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/mine_field.dart';
import 'package:tiny_mines/platform/game_platform.dart';
import 'package:tiny_mines/src/game/difficulty.dart';
import 'package:tiny_mines/src/meta/daily_challenge.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/meta/garden_progress_store.dart';
import 'package:tiny_mines/src/meta/garden_theme.dart';

import 'support/fake_stopwatch.dart';

class _Store extends TutorialStore {
  _Store({this.seen = true});
  bool seen;
  @override
  Future<bool> hasSeen() async => seen;
  @override
  Future<void> markSeen() async => seen = true;
}

/// Answers "seen" only when released (a slow storage read).
class _LateSeen extends TutorialStore {
  final Completer<void> release = Completer<void>();
  @override
  Future<bool> hasSeen() async {
    await release.future;
    return true;
  }

  @override
  Future<void> markSeen() async {}
}

/// Progress store whose load completes only when released.
class _SlowProgressStore extends MemoryGardenProgressStore {
  _SlowProgressStore(super.value);
  final Completer<void> release = Completer<void>();
  @override
  Future<GardenProgress> load() async {
    await release.future;
    return super.load();
  }
}

Finder get _tiles =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));

final DateTime _day = DateTime(2026, 11, 2, 9);

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(800, 1400),
  GardenProgressStore? store,
  TutorialStore? tutorial,
  Stopwatch? stopwatch,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(1),
        progressStore: store ?? MemoryGardenProgressStore(),
        tutorialStore: tutorial ?? _Store(),
        stopwatch: stopwatch,
        now: () => _day,
        platform: const NoopGamePlatform(allowsResultRegistration: false),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

MineField _easy() =>
    MineField(size: 6, mineCount: 5, random: math.Random(1))..reveal(0);

Future<void> _winEasy(WidgetTester tester) async {
  final reference = _easy();
  final replay = MineField(size: 6, mineCount: 5, random: math.Random(1));
  for (var i = 0; i < 36; i++) {
    if (reference.cells[i].mine || replay.cells[i].revealed) continue;
    replay.reveal(i);
    await tester.tap(_tiles.at(i));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _loseEasy(WidgetTester tester) async {
  final mine = _easy().cells.indexWhere((c) => c.mine);
  await tester.tap(_tiles.at(0));
  await tester.pump();
  await tester.tap(_tiles.at(mine));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('layout', () {
    for (final size in const [
      Size(1280, 720),
      Size(1366, 768),
      Size(390, 844),
      Size(360, 760),
      Size(844, 390),
      Size(800, 600),
    ]) {
      testWidgets('screen, summary and garden fit at $size', (tester) async {
        await _pump(tester, size: size);
        expect(tester.takeException(), isNull);
        for (final d in Difficulty.values) {
          await tester.tap(find.text(d.title));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final grid = tester.getRect(find.byType(GridView));
          expect(grid.width, lessThanOrEqualTo(560));
          expect(grid.bottom, lessThanOrEqualTo(size.height));
        }
        await tester.tap(find.text('Easy 6x6'));
        await tester.pumpAndSettle();
        await _loseEasy(tester);
        expect(find.text('Bonk! A mole!'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('View board'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (find.text('Garden').evaluate().isNotEmpty) {
          await tester.tap(find.text('Garden'));
          await tester.pumpAndSettle();
          expect(find.text('My Garden'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } else {
          // Wide: level, themes, daily and records sit in the side panels.
          expect(find.text('Records'.toUpperCase()), findsOneWidget);
          expect(find.text('Play daily'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });

  group('first click', () {
    testWidgets('the first tap always digs safely and starts the clock', (
      tester,
    ) async {
      for (final index in const [0, 14, 35]) {
        final watch = FakeStopwatch();
        await _pump(tester, stopwatch: watch);
        expect(watch.isRunning, isFalse);
        await tester.tap(_tiles.at(index));
        await tester.pump();
        expect(watch.isRunning, isTrue, reason: 'tile $index');
        expect(find.text('Moves'), findsOneWidget);
        expect(find.textContaining('mole!'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('a tap during a slow tutorial check is applied, not lost', (
      tester,
    ) async {
      final store = _LateSeen();
      final watch = FakeStopwatch();
      await _pump(tester, tutorial: store, stopwatch: watch, settle: false);
      await tester.pump();
      await tester.tap(_tiles.at(14), warnIfMissed: false);
      await tester.pump();
      expect(watch.isRunning, isFalse, reason: 'held until the check answers');
      store.release.complete();
      await tester.pumpAndSettle();
      expect(watch.isRunning, isTrue, reason: 'the held tap was applied');
      expect(find.text('How to play'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the first tap right after the tutorial closes counts', (
      tester,
    ) async {
      final watch = FakeStopwatch();
      await _pump(tester, tutorial: _Store(seen: false), stopwatch: watch);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(_tiles.at(20));
      await tester.pump();
      expect(watch.isRunning, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('run summary', () {
    testWidgets('a win shows New best, XP and saves the record', (
      tester,
    ) async {
      final store = MemoryGardenProgressStore();
      await _pump(tester, store: store, stopwatch: FakeStopwatch());
      await _winEasy(tester);
      expect(find.text('Garden cleared!'), findsOneWidget);
      expect(find.text('New best!'), findsOneWidget);
      expect(find.text('+30 XP'), findsOneWidget);
      expect(find.text('Next: Normal'), findsOneWidget);
      expect(store.value.bestTime(Difficulty.easy), 0);
      expect(store.value.totalXp, 30);
      // Enter plays again.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Garden cleared!'), findsNothing);
      expect(find.textContaining('Field cleared'), findsNothing);
      // An equal clear (fresh screen, same seed and store) is not a new best.
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, store: store, stopwatch: FakeStopwatch());
      await _winEasy(tester);
      expect(find.text('Garden cleared!'), findsOneWidget);
      expect(find.text('New best!'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Next moves to the harder board', (tester) async {
      await _pump(tester);
      await _winEasy(tester);
      await tester.tap(find.text('Next: Normal'));
      await tester.pumpAndSettle();
      expect(_tiles, findsNWidgets(81));
    });

    testWidgets('Escape closes the card and blocks nothing after', (
      tester,
    ) async {
      await _pump(tester);
      await _loseEasy(tester);
      expect(find.text('Bonk! A mole!'), findsOneWidget);
      // The card blocks the board.
      expect(find.text('New Field'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Bonk! A mole!'), findsNothing);
      expect(find.text('New Field'), findsOneWidget, reason: 'under the board');
      await tester.tap(find.text('New Field'));
      await tester.pumpAndSettle();
      expect(find.textContaining('mole!'), findsNothing);
    });

    testWidgets('a run finished before progress loads is merged, not lost', (
      tester,
    ) async {
      final store = _SlowProgressStore(
        GardenProgress.fromJson({
          'totalXp': 50,
          'bestTimes': {'hard': 99},
        }),
      );
      await _pump(tester, store: store, stopwatch: FakeStopwatch());
      await _winEasy(tester);
      expect(store.saveCount, 0, reason: 'never save before loading');
      store.release.complete();
      await tester.pumpAndSettle();
      expect(store.saveCount, 1);
      expect(store.value.totalXp, 80);
      expect(store.value.bestTime(Difficulty.hard), 99);
      expect(store.value.bestTime(Difficulty.easy), 0);
    });
  });

  group('themes and daily', () {
    testWidgets('only unlocked themes can be picked; choice is saved', (
      tester,
    ) async {
      final store = MemoryGardenProgressStore(
        GardenProgress.fromJson({'totalXp': 240}),
      );
      await _pump(tester, size: const Size(1280, 720), store: store);
      await tester.tap(find.text('Lv 6'));
      await tester.pumpAndSettle();
      expect(store.value.selectedTheme, GardenTheme.spring);
      await tester.tap(find.text('Autumn'));
      await tester.pumpAndSettle();
      expect(store.value.selectedTheme, GardenTheme.autumn);
    });

    testWidgets('the daily board is played once and keeps the streak', (
      tester,
    ) async {
      final store = MemoryGardenProgressStore(
        GardenProgress.fromJson({
          'streak': 2,
          'lastDailyDay': '2026-11-01',
          'bestStreak': 5,
        }),
      );
      final watch = FakeStopwatch();
      await _pump(
        tester,
        size: const Size(1280, 720),
        store: store,
        stopwatch: watch,
      );
      expect(find.text('2 days'), findsOneWidget);
      await tester.tap(find.text('Play daily'));
      await tester.pumpAndSettle();
      expect(_tiles, findsNWidgets(81));
      expect(find.text('In progress'), findsOneWidget);
      expect(watch.isRunning, isFalse, reason: 'clock waits for a move');

      // Lose on purpose: dig a mole.
      final (reference, _) = DailyChallenge.build(_day);
      final mine = reference.cells.indexWhere((c) => c.mine);
      await tester.tap(_tiles.at(mine));
      await tester.pumpAndSettle();
      expect(find.text('Bonk! A mole!'), findsOneWidget);
      expect(find.textContaining('Daily streak: 3 days'), findsOneWidget);
      expect(store.value.dailyResult(_day)?.won, isFalse);
      expect(store.value.streak, 3);
      await tester.tap(find.text('New Field'));
      await tester.pumpAndSettle();
      expect(find.text('Done for today'), findsOneWidget);
      await tester.tap(find.text('Done for today'));
      await tester.pumpAndSettle();
      expect(_tiles, findsNWidgets(36), reason: 'no second daily attempt');
      expect(find.text('3 days'), findsOneWidget);
    });
  });
}
