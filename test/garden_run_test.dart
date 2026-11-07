import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/src/game/garden_run.dart';

void main() {
  group('stage table', () {
    test('stages 1 to 10 follow the fixed table', () {
      const expected = [
        (5, 3),
        (6, 5),
        (7, 7),
        (8, 10),
        (8, 11),
        (9, 12),
        (9, 14),
        (10, 17),
        (10, 19),
        (12, 26),
      ];
      for (var i = 0; i < expected.length; i++) {
        final stage = GardenRun.stage(i + 1);
        expect(stage.stage, i + 1);
        expect(
          (stage.size, stage.mines),
          expected[i],
          reason: 'stage ${i + 1}',
        );
      }
    });

    test('later stages add a mine each on the last size, capped at 22%', () {
      expect(GardenRun.stage(11).mines, 27);
      expect(GardenRun.stage(12).mines, 28);
      expect(GardenRun.stage(11).size, 12);
      // 12x12 holds at most floor(144 * 0.22) = 31 mines.
      expect(GardenRun.stage(15).mines, 31);
      expect(GardenRun.stage(16).mines, 31);
      expect(GardenRun.stage(500).mines, 31);
    });

    test('no stage exceeds the density cap and the table is monotonic', () {
      var previous = 0;
      for (var n = 1; n <= 60; n++) {
        final stage = GardenRun.stage(n);
        expect(stage.density, lessThanOrEqualTo(GardenRun.maxDensity));
        expect(stage.mines, greaterThanOrEqualTo(previous));
        previous = stage.mines;
      }
    });

    test('a stage number always maps to the same setup', () {
      for (var n = 1; n <= 30; n++) {
        final a = GardenRun.stage(n);
        final b = GardenRun.stage(n);
        expect((a.size, a.mines), (b.size, b.mines));
      }
      expect(GardenRun.stage(0).stage, 1);
      expect(GardenRun.stage(-4).size, 5);
    });

    test(
      'stages 5 and 10 are boss gardens; only 6x6/5 uses the fair start',
      () {
        expect(
          [
            for (var n = 1; n <= 12; n++)
              if (GardenRun.stage(n).boss) n,
          ],
          [5, 10],
        );
        expect(
          [
            for (var n = 1; n <= 12; n++)
              if (GardenRun.stage(n).fairStart) n,
          ],
          [2],
        );
      },
    );
  });

  group('hearts, hints and clears', () {
    test('a run starts with 3 hearts, 3 hints and stage 1', () {
      const run = GardenRunState();
      expect((run.stage, run.hearts, run.hints, run.cleared), (1, 3, 3, 0));
      expect(run.isOver, isFalse);
    });

    test('a mole costs a heart; the last one ends the run', () {
      var run = const GardenRunState();
      run = run.loseHearts();
      expect(run.hearts, 2);
      run = run.loseHearts().loseHearts();
      expect(run.hearts, 0);
      expect(run.isOver, isTrue);
      expect(const GardenRunState().loseHearts(9).hearts, 0);
    });

    test('hints are shared, finite and never negative', () {
      var run = const GardenRunState();
      for (var i = 0; i < 3; i++) {
        run = run.useHint();
      }
      expect(run.hints, 0);
      expect(run.canHint, isFalse);
      expect(run.useHint().hints, 0);
    });

    test('clearing advances the stage and counts the board', () {
      final run = const GardenRunState().clearStage();
      expect((run.stage, run.cleared), (2, 1));
    });

    test('boss stages restore one heart, never above the maximum', () {
      var run = const GardenRunState(stage: 5, hearts: 1);
      expect(run.clearStage().hearts, 2);
      run = const GardenRunState(stage: 5);
      expect(run.clearStage().hearts, GardenRun.maxHearts);
      // A regular stage heals nothing.
      expect(const GardenRunState(stage: 4, hearts: 1).clearStage().hearts, 1);
      expect(const GardenRunState(stage: 10, hearts: 2).clearStage().hearts, 3);
    });

    test('every third clear adds a hint, up to 5', () {
      var run = const GardenRunState();
      final hints = <int>[];
      for (var i = 0; i < 18; i++) {
        run = run.clearStage();
        hints.add(run.hints);
      }
      expect(hints.sublist(0, 6), [3, 3, 4, 4, 4, 5]);
      expect(hints.every((h) => h <= GardenRun.maxHints), isTrue);
      expect(hints.last, GardenRun.maxHints);
    });
  });

  group('xp', () {
    test('15 per cleared board plus 10 for taking part', () {
      expect(GardenRun.xpFor(stagesCleared: 0, participated: true), 10);
      expect(GardenRun.xpFor(stagesCleared: 1, participated: true), 25);
      expect(GardenRun.xpFor(stagesCleared: 7, participated: true), 115);
    });

    test('a run that never dug earns nothing', () {
      expect(GardenRun.xpFor(stagesCleared: 0, participated: false), 0);
      expect(GardenRun.xpFor(stagesCleared: 3, participated: false), 0);
    });
  });
}
