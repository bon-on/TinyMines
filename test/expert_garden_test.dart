import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/mine_field.dart';
import 'package:tiny_mines/src/game/difficulty.dart';
import 'package:tiny_mines/src/game/fair_field.dart';
import 'package:tiny_mines/src/game/mine_logic.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/ui/garden_cards.dart';
import 'package:tiny_mines/src/meta/daily_challenge.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({'tutorial_seen_v1': true}),
  );

  group('Difficulty', () {
    test('Expert is a larger preset after Hard', () {
      expect(Difficulty.expert.size, 14);
      expect(Difficulty.expert.mines, 40);
      expect(Difficulty.expert.hints, 4);
      expect(Difficulty.expert.title, 'Expert 14x14');
      expect(Difficulty.hard.next, Difficulty.expert);
      expect(Difficulty.expert.next, isNull);
      expect(Difficulty.values.where((d) => d.guessFree), [Difficulty.expert]);
      expect(Difficulty.fromName('expert'), Difficulty.expert);
    });

    test('the other presets keep their rules', () {
      expect(
        [
          for (final d in [Difficulty.easy, Difficulty.normal, Difficulty.hard])
            (d.size, d.mines, d.hints),
        ],
        [(6, 5, 3), (9, 12, 3), (12, 26, 4)],
      );
      expect(GardenProgress.winXp(Difficulty.expert), 300);
      expect(GardenProgress.winXp(Difficulty.hard), 150);
      expect(DailyChallenge.difficulty, Difficulty.normal);
    });
  });

  group('MineLogic', () {
    test('solves a hand-made board and rejects an instantly solved one', () {
      // 3x3, moles at 7 and 8: opening the top-left corner floods the top
      // rows and every remaining cell follows from the numbers.
      expect(MineLogic(3, 2).solvable({7, 8}, 0), isTrue);
      // A single mole in a far corner: the opening floods the whole board,
      // so there is nothing left to play and the layout is rejected.
      expect(MineLogic(4, 1).solvable({15}, 0), isFalse);
    });

    test('it does not accept every layout', () {
      final logic = MineLogic(6, 5);
      final random = math.Random(3);
      var accepted = 0;
      const trials = 300;
      for (var t = 0; t < trials; t++) {
        final start = random.nextInt(36);
        final blocked = {start, ...logic.neighbors(start)};
        final candidates = [
          for (var i = 0; i < 36; i++)
            if (!blocked.contains(i)) i,
        ]..shuffle(random);
        if (logic.solvable(candidates.take(5).toSet(), start)) accepted++;
      }
      expect(accepted, inInclusiveRange(trials ~/ 3, trials - 10));
    });

    test('rejects wrong mine counts and cells next to the start', () {
      final logic = MineLogic(6, 5);
      expect(logic.solvable({1, 2, 3, 4}, 35), isFalse);
      expect(logic.solvable({0, 7, 14, 21, 28}, 1), isFalse);
      expect(logic.solvable({0, 7, 14, 21, 28}, 99), isFalse);
    });

    test('never marks a safe cell or opens a mole on random boards', () {
      // The solver throws StateError if it ever does.
      final random = math.Random(11);
      for (final (size, mines) in const [(6, 5), (9, 12), (12, 26), (14, 40)]) {
        final logic = MineLogic(size, mines);
        var solved = 0;
        for (var t = 0; t < 150; t++) {
          final start = random.nextInt(size * size);
          final blocked = {start, ...logic.neighbors(start)};
          final candidates = [
            for (var i = 0; i < size * size; i++)
              if (!blocked.contains(i)) i,
          ]..shuffle(random);
          if (logic.solvable(candidates.take(mines).toSet(), start)) solved++;
        }
        expect(solved, greaterThan(0), reason: '$size x $size/$mines');
      }
    });
  });

  group('FairField', () {
    test('Expert layouts are guess-free for many seeds and openings', () {
      final logic = MineLogic(14, 40);
      var totalAttempts = 0;
      for (var seed = 0; seed < 60; seed++) {
        final random = math.Random(seed);
        final start = random.nextInt(14 * 14);
        final layout = FairField.generate(
          size: 14,
          mineCount: 40,
          start: start,
          random: random,
        );
        totalAttempts += layout.attempts;
        expect(layout.verified, isTrue, reason: 'seed $seed');
        expect(layout.mines.toSet(), hasLength(40));
        expect(layout.mines, isNot(contains(start)));
        expect(layout.mines.any(logic.neighbors(start).contains), isFalse);
        expect(logic.solvable(layout.mines.toSet(), start), isTrue);
      }
      // About one draw in five works; a runaway search would show here.
      expect(totalAttempts / 60, lessThan(25));
    });

    test('generation is deterministic for a seeded random', () {
      List<int> mines() => FairField.generate(
        size: 14,
        mineCount: 40,
        start: 90,
        random: math.Random(5),
      ).mines;
      expect(mines(), mines());
    });

    test('when the draws run out the last layout is returned unverified', () {
      // Find a seed whose first draw is not guess-free (about 4 in 5).
      for (var seed = 0; seed < 50; seed++) {
        final layout = FairField.generate(
          size: 14,
          mineCount: 40,
          start: 90,
          random: math.Random(seed),
          attempts: 1,
        );
        if (layout.verified) continue;
        expect(layout.attempts, 1);
        expect(layout.mines.toSet(), hasLength(40));
        expect(layout.mines, isNot(contains(90)));
        final logic = MineLogic(14, 40);
        expect(layout.mines.any(logic.neighbors(90).contains), isFalse);
        return;
      }
      fail('every first draw was verified, which should be very unlikely');
    });

    test('needs at least one draw', () {
      expect(
        () => FairField.generate(
          size: 14,
          mineCount: 40,
          start: 90,
          random: math.Random(5),
          attempts: 0,
        ),
        throwsRangeError,
      );
    });

    test('rejects impossible requests', () {
      expect(
        () => FairField.generate(
          size: 3,
          mineCount: 20,
          start: 4,
          random: math.Random(1),
        ),
        throwsArgumentError,
      );
      expect(
        () => FairField.generate(
          size: 3,
          mineCount: 1,
          start: 99,
          random: math.Random(1),
        ),
        throwsRangeError,
      );
    });
  });

  group('MineField', () {
    test('guessFree boards plant verified Expert layouts', () {
      for (var seed = 0; seed < 20; seed++) {
        final field = MineField(
          size: 14,
          mineCount: 40,
          random: math.Random(seed),
          guessFree: true,
        )..reveal(97);
        expect(field.guessFreeVerified, isTrue);
        expect(field.cells.where((c) => c.mine), hasLength(40));
        expect(field.cells[97].mine, isFalse);
        expect(field.won, isFalse, reason: 'the opening alone must not win');
      }
    });

    test('regular boards do not use the guess-free path', () {
      final field = MineField(size: 12, mineCount: 26, random: math.Random(1))
        ..reveal(0);
      expect(field.guessFree, isFalse);
      expect(field.guessFreeVerified, isNull);
      final (daily, _) = DailyChallenge.build(DateTime(2026, 11, 13));
      expect(daily.guessFree, isFalse);
      expect(daily.guessFreeVerified, isNull);
    });
  });

  group('progress', () {
    test('an Expert win is recorded under expert and pays 300 XP', () {
      const start = GardenProgress.initial();
      final outcome = start.applyRun(
        const RunResult(
          difficulty: Difficulty.expert,
          won: true,
          seconds: 400,
          revealedFraction: 1,
        ),
      );
      final p = outcome.progress;
      expect(p.bestTime(Difficulty.expert), 400);
      expect(p.wins['expert'], 1);
      expect(p.plays['expert'], 1);
      expect(p.bestTime(Difficulty.hard), isNull);
      expect(outcome.xpGained, greaterThanOrEqualTo(300));
      // The save round trips with the Expert records.
      final back = GardenProgress.fromJson(p.toJson());
      expect(back.bestTime(Difficulty.expert), 400);
      expect(back.wins['expert'], 1);
    });

    test('old saves without Expert load with empty records', () {
      final progress = GardenProgress.fromJson({
        'bestTimes': {'easy': 60},
        'wins': {'easy': 2},
        'plays': {'easy': 3},
      });
      expect(progress.bestTime(Difficulty.expert), isNull);
      expect(progress.wins['expert'], isNull);
      expect(progress.bestTime(Difficulty.easy), 60);
    });
  });

  group('screen', () {
    for (final size in const [
      Size(360, 640),
      Size(390, 844),
      Size(844, 390),
      Size(1280, 720),
      Size(1366, 768),
    ]) {
      testWidgets('Expert fits $size with readable tiles', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const TinyMinesApp());
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .byWidgetPredicate(
                (w) =>
                    w is Text &&
                    (w.data == 'Expert 14x14' || w.data == 'Expert'),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final tiles = find.descendant(
          of: find.byType(GridView),
          matching: find.byType(InkWell),
        );
        expect(tiles, findsNWidgets(196));
        expect(tester.getSize(tiles.first).width, greaterThanOrEqualTo(16));
        expect(
          tester.getRect(find.byType(GridView)).bottom,
          lessThanOrEqualTo(size.height),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('Records lists the Expert row', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const TinyMinesApp());
      await tester.pumpAndSettle();
      final rows = find.descendant(
        of: find.byType(RecordsCard),
        matching: find.byType(Row),
      );
      expect(rows, findsWidgets);
      expect(
        find.descendant(
          of: find.byType(RecordsCard),
          matching: find.text('Expert'),
        ),
        findsOneWidget,
      );
      for (final label in ['Easy', 'Normal', 'Hard']) {
        expect(
          find.descendant(
            of: find.byType(RecordsCard),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
