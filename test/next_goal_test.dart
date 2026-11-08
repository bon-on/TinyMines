import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/meta/next_goal.dart';

GardenProgress _p({int xp = 0, int best = 0}) =>
    GardenProgress.fromJson({'totalXp': xp, 'bestRunStage': best});

void main() {
  test('a new garden: first run first, then level, then Autumn', () {
    final goals = nextGoals(_p());
    expect(goals.map((g) => g.kind), [
      GoalKind.run,
      GoalKind.level,
      GoalKind.theme,
    ]);
    expect(goals[0].title, 'Play your first Garden Run');
    expect(goals[1].title, 'Reach garden Lv 2');
    expect(goals[1].detail, '100 XP to go');
    expect(goals[1].estimate, 2);
    expect(goals[2].title, 'Unlock the Autumn theme');
    expect(goals[2].detail, 'Lv 3 - 240 XP to go');
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
    const plot = NextGoal(
      kind: GoalKind.plot,
      title: 'Earn the Rose arch plot',
      detail: 'Reach stage 5 in Garden Run (2/8)',
      current: 2,
      target: 8,
      estimate: 1,
      runStage: 5,
    );
    final goals = nextGoals(_p(best: 4), extra: const [plot], limit: 5);
    expect(goals.where((g) => g.kind == GoalKind.run), isEmpty);
    expect(goals.first, same(plot));
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
