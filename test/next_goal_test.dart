import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/meta/next_goal.dart';

GardenProgress _p({int xp = 0, int best = 0}) =>
    GardenProgress.fromJson({'totalXp': xp, 'bestRunStage': best});

extension on GardenProgress {
  GardenProgress withDailyClears(int clears) =>
      GardenProgress.fromJson({...toJson(), 'dailyClears': clears});
}

void main() {
  test('a new garden: first run first, then the daily plot, then level', () {
    final goals = nextGoals(_p());
    expect(goals.map((g) => g.kind), [
      GoalKind.run,
      GoalKind.plot,
      GoalKind.level,
    ]);
    expect(goals[0].title, 'Play your first Garden Run');
    expect(goals[1].title, 'Earn the Mushroom ring plot');
    expect(goals[1].detail, 'Clear a daily garden - 0/8 plots');
    expect(goals[2].title, 'Reach garden Lv 2');
    expect(goals[2].detail, '100 XP to go');
    expect(goals[2].estimate, 2);
    final theme = nextGoals(_p(), limit: 9).last;
    expect(theme.title, 'Unlock the Autumn theme');
    expect(theme.detail, 'Lv 3 - 240 XP to go');
  });

  test('a theme opened by the next level joins the level goal', () {
    final progress = _p(xp: 100, best: 3);
    expect(progress.level, 2);
    final goals = nextGoals(progress, limit: 5);
    final level = goals.firstWhere((g) => g.kind == GoalKind.level);
    expect(level.detail, '140 XP to go - unlocks Autumn');
    expect(level.current, 0);
    expect(level.target, 140);
    final theme = goals.firstWhere((g) => g.kind == GoalKind.theme);
    expect(theme.title, 'Unlock the Winter theme');
    final run = goals.firstWhere((g) => g.kind == GoalKind.run);
    expect(run.title, 'Beat Garden Run stage 3');
    expect(run.detail, 'Reach stage 4');
  });

  test('level wins a tie with the run goal', () {
    final progress = _p(xp: 60, best: 2);
    // 40 XP missing -> 1 play; best stage -> 2 plays.
    final goals = nextGoals(progress);
    expect(goals.first.kind, GoalKind.level);
    expect(goals.first.fraction, closeTo(0.6, 1e-9));
  });

  test('a plot asking for the same stage replaces the run goal', () {
    // Stage 4 best: the Rose arch plot (stage 5) is one stage away.
    final goals = nextGoals(_p(best: 4), limit: 5);
    expect(goals.where((g) => g.kind == GoalKind.run), isEmpty);
    final plot = goals.firstWhere((g) => g.kind == GoalKind.plot);
    expect(plot.title, 'Earn the Rose arch plot');
    expect(plot.detail, 'Reach stage 5 in Garden Run - 2/8 plots');
    expect(plot.runStage, 5);
    expect(plot.estimate, 1);
  });

  test('daily plot goals count the clears still missing', () {
    final goal = plotGoal(_p(best: 9).withDailyClears(2))!;
    expect(goal.title, 'Earn the Berry bush plot');
    expect(goal.detail, 'Clear 2 more daily gardens - 6/8 plots');
    expect(goal.estimate, 2);
  });

  test('a finished collection has no plot goal', () {
    final done = GardenProgress.fromJson({'bestRunStage': 9, 'dailyClears': 7});
    expect(plotGoal(done), isNull);
    expect(nextGoals(done).where((g) => g.kind == GoalKind.plot), isEmpty);
  });

  test('every theme unlocked: no theme goal, still a level goal', () {
    final goals = nextGoals(_p(xp: 100000, best: 30), limit: 5);
    expect(goals.where((g) => g.kind == GoalKind.theme), isEmpty);
    expect(goals.where((g) => g.kind == GoalKind.level), hasLength(1));
    expect(goals.length, lessThanOrEqualTo(5));
  });

  test('xpToLevel adds whole levels after the current one', () {
    final progress = _p(xp: 0);
    expect(xpToLevel(progress, 2), 100);
    expect(xpToLevel(progress, 3), 240);
    expect(xpToLevel(progress, 6), 900);
  });
}
