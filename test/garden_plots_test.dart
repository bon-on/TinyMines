import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/src/game/difficulty.dart';
import 'package:tiny_mines/src/meta/garden_plots.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/meta/garden_theme.dart';

RunResult _daily(String day, {bool won = true, bool practice = false}) =>
    RunResult(
      difficulty: Difficulty.normal,
      won: won,
      seconds: 90,
      revealedFraction: won ? 1 : 0.4,
      dailyDay: day,
      practice: practice,
    );

const _easyWin = RunResult(
  difficulty: Difficulty.easy,
  won: true,
  seconds: 40,
  revealedFraction: 1,
);

GardenRunResult _run(int stage) => GardenRunResult(
  stageReached: stage,
  stagesCleared: stage - 1,
  participated: true,
);

void main() {
  group('plot table', () {
    test('eight plots in two sets of four', () {
      expect(GardenPlots.total, 8);
      expect(PlotSet.runPath.plots.map((p) => p.requirement), [2, 3, 5, 7]);
      expect(PlotSet.dailyBeds.plots.map((p) => p.requirement), [1, 2, 4, 7]);
    });

    test('earned and next at zero, partial and full progress', () {
      expect(GardenPlots.earned(bestRunStage: 0, dailyClears: 0), isEmpty);
      expect(
        GardenPlots.next(bestRunStage: 0, dailyClears: 0),
        GardenPlot.mushrooms,
      );
      expect(GardenPlots.earned(bestRunStage: 5, dailyClears: 2), [
        GardenPlot.sprouts,
        GardenPlot.tulips,
        GardenPlot.roseArch,
        GardenPlot.mushrooms,
        GardenPlot.lilyPond,
      ]);
      // Tie (2 stages vs 2 clears): Run Path first.
      expect(
        GardenPlots.next(bestRunStage: 5, dailyClears: 2),
        GardenPlot.sunflowers,
      );
      expect(
        GardenPlots.earned(bestRunStage: 12, dailyClears: 9),
        hasLength(8),
      );
      expect(GardenPlots.next(bestRunStage: 12, dailyClears: 9), isNull);
    });

    test('requirement texts', () {
      expect(
        GardenPlot.roseArch.requirementText,
        'Reach stage 5 in Garden Run',
      );
      expect(GardenPlot.mushrooms.requirementText, 'Clear a daily garden');
      expect(GardenPlot.birdBath.requirementText, 'Clear 7 daily gardens');
      expect(
        GardenPlot.birdBath.goalText(dailyClears: 6),
        'Clear 1 more daily garden',
      );
    });
  });

  group('progress counters', () {
    test('a scored daily win counts once; loss, repeat, practice do not', () {
      var p = const GardenProgress.initial();
      var outcome = p.applyRun(_daily('2026-11-02'));
      p = outcome.progress;
      expect(p.dailyClears, 1);
      expect(outcome.newPlots, [GardenPlot.mushrooms]);

      outcome = p.applyRun(_daily('2026-11-02'));
      expect(identical(outcome.progress, p), isTrue, reason: 'repeat');
      outcome = p.applyRun(_daily('2026-11-02', practice: true));
      expect(identical(outcome.progress, p), isTrue, reason: 'practice');

      p = p.applyRun(_daily('2026-11-03', won: false)).progress;
      expect(p.dailyClears, 1, reason: 'a loss is recorded but not a clear');
      p = p.applyRun(_daily('2026-11-04')).progress;
      expect(p.dailyClears, 2);
      expect(p.earnedPlots, [GardenPlot.mushrooms, GardenPlot.lilyPond]);
    });

    test('Garden Run best stage earns run plots; empty runs nothing', () {
      var p = const GardenProgress.initial();
      final empty = p.applyGardenRun(
        const GardenRunResult(
          stageReached: 1,
          stagesCleared: 0,
          participated: false,
        ),
      );
      expect(identical(empty.progress, p), isTrue);
      final outcome = p.applyGardenRun(_run(3));
      expect(outcome.newPlots, [GardenPlot.sprouts, GardenPlot.tulips]);
      p = outcome.progress;
      expect(p.applyGardenRun(_run(2)).newPlots, isEmpty);
    });
  });

  group('set rewards', () {
    test('Run Path pays 100 XP once, also after a JSON round trip', () {
      var p = const GardenProgress.initial();
      p = p.applyGardenRun(_run(5)).progress;
      final xpBefore = p.totalXp;
      final outcome = p.applyGardenRun(_run(7));
      final runXp = 6 * 15 + 10;
      expect(outcome.completedSets, [PlotSet.runPath]);
      expect(outcome.xpGained, runXp + 100);
      expect(outcome.progress.totalXp, xpBefore + runXp + 100);
      expect(outcome.progress.rewardedSets, {'run'});

      final reloaded = GardenProgress.fromJson(
        jsonDecode(jsonEncode(outcome.progress.toJson())),
      );
      expect(reloaded.rewardedSets, {'run'});
      final again = reloaded.applyGardenRun(_run(8));
      expect(again.completedSets, isEmpty);
      expect(again.xpGained, 7 * 15 + 10);
    });

    test('a legacy save that already qualifies is paid at the next result', () {
      final legacy = GardenProgress.fromJson({
        'bestRunStage': 7,
        'daily': {
          for (final d in const [1, 2, 3, 4, 5, 6, 7])
            '2026-10-0$d': {'won': true, 'seconds': 80},
        },
      });
      expect(legacy.dailyClears, 7, reason: 'derived from the daily history');
      expect(legacy.rewardedSets, isEmpty);
      final outcome = legacy.applyRun(_easyWin);
      expect(outcome.completedSets, [PlotSet.runPath, PlotSet.dailyBeds]);
      expect(outcome.xpGained, 30 + 100 + 150);
      expect(outcome.newPlots, isEmpty, reason: 'already earned before');
      expect(outcome.leveledUp, isTrue);
      expect(outcome.newlyUnlockedThemes, contains(GardenTheme.autumn));
      expect(outcome.progress.applyRun(_easyWin).completedSets, isEmpty);
    });

    test('practice never pays a set bonus', () {
      final legacy = GardenProgress.fromJson({'bestRunStage': 7});
      final outcome = legacy.applyRun(_daily('2026-11-02', practice: true));
      expect(outcome.completedSets, isEmpty);
      expect(outcome.xpGained, 0);
    });
  });

  group('storage', () {
    test('old JSON without the new fields loads with defaults', () {
      final p = GardenProgress.fromJson({'totalXp': 50, 'bestRunStage': 3});
      expect(p.dailyClears, 0);
      expect(p.rewardedSets, isEmpty);
      expect(p.toJson()['dailyClears'], 0);
      expect(p.toJson()['rewardedSets'], isEmpty);
    });

    test('corrupt values fall back without breaking the load', () {
      final p = GardenProgress.fromJson({
        'dailyClears': 'many',
        'rewardedSets': ['run', 42, 'unknown', null, 'run'],
        'daily': {
          '2026-11-01': {'won': true, 'seconds': 10},
        },
      });
      expect(p.dailyClears, 1);
      expect(p.rewardedSets, {'run'});
      final q = GardenProgress.fromJson({'rewardedSets': 'run'});
      expect(q.rewardedSets, isEmpty);
    });

    test('a stored count above the history is kept', () {
      final p = GardenProgress.fromJson({'dailyClears': 12});
      expect(p.dailyClears, 12);
      final round = GardenProgress.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(round.dailyClears, 12);
    });
  });
}
