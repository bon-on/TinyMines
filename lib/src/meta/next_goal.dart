import 'garden_plots.dart';
import 'garden_progress.dart';
import 'garden_theme.dart';

/// What a goal is about; also its tie-break order (lower first).
enum GoalKind { level, run, plot, theme }

/// One reachable target shown on the result card (feature-next-goal-share).
class NextGoal {
  const NextGoal({
    required this.kind,
    required this.title,
    required this.detail,
    required this.current,
    required this.target,
    required this.estimate,
    this.runStage,
  });

  final GoalKind kind;

  /// Short headline, e.g. "Reach garden Lv 3".
  final String title;

  /// The numbers, e.g. "60 XP to go - unlocks Autumn".
  final String detail;

  /// Progress bar position: [current] of [target].
  final int current;
  final int target;

  /// Rough number of plays still needed; the smallest goal is highlighted.
  final int estimate;

  /// The Garden Run stage this goal asks for, if any.
  final int? runStage;

  double get fraction => target <= 0 ? 1 : (current / target).clamp(0.0, 1.0);
}

/// Average XP of one play, used only to compare XP goals with other goals.
const int averageXpPerPlay = 50;

int _plays(int xp) =>
    xp <= 0 ? 1 : (xp + averageXpPerPlay - 1) ~/ averageXpPerPlay;

/// XP still needed to reach [level] from [progress].
int xpToLevel(GardenProgress progress, int level) {
  var xp = progress.xpForNextLevel - progress.xpIntoLevel;
  for (var l = progress.level + 1; l < level; l++) {
    xp += GardenProgress.xpToAdvance(l);
  }
  return xp;
}

/// The closest unearned garden plot (feature-garden-collection) as a goal;
/// null when the collection is complete.
NextGoal? plotGoal(GardenProgress progress) {
  final plot = progress.nextPlot;
  if (plot == null) return null;
  final earned = progress.earnedPlots.length;
  return NextGoal(
    kind: GoalKind.plot,
    title: 'Earn the ${plot.label} plot',
    detail:
        '${plot.goalText(dailyClears: progress.dailyClears)} - '
        '$earned/${GardenPlots.total} plots',
    current: earned,
    target: GardenPlots.total,
    estimate: plot.remaining(
      bestRunStage: progress.bestRunStage,
      dailyClears: progress.dailyClears,
    ),
    runStage: plot.isRunPlot ? plot.requirement : null,
  );
}

/// Goals for [progress], closest first (ties: level, run, plot, theme):
/// the next level, a farther theme, the closest garden plot and the Garden
/// Run target. A run target that a plot goal already asks for is dropped.
List<NextGoal> nextGoals(GardenProgress progress, {int limit = 3}) {
  final goals = <NextGoal>[];
  final level = progress.level;
  final missing = progress.xpForNextLevel - progress.xpIntoLevel;
  GardenTheme? themeAtNext;
  for (final theme in GardenTheme.values) {
    if (theme.requiredLevel == level + 1) themeAtNext = theme;
  }
  goals.add(
    NextGoal(
      kind: GoalKind.level,
      title: 'Reach garden Lv ${level + 1}',
      detail: themeAtNext == null
          ? '$missing XP to go'
          : '$missing XP to go - unlocks ${themeAtNext.label}',
      current: progress.xpIntoLevel,
      target: progress.xpForNextLevel,
      estimate: _plays(missing),
    ),
  );
  for (final theme in GardenTheme.values) {
    if (progress.isThemeUnlocked(theme) || theme == themeAtNext) continue;
    final xp = xpToLevel(progress, theme.requiredLevel);
    goals.add(
      NextGoal(
        kind: GoalKind.theme,
        title: 'Unlock the ${theme.label} theme',
        detail: 'Lv ${theme.requiredLevel} - $xp XP to go',
        current: progress.totalXp,
        target: progress.totalXp + xp,
        estimate: _plays(xp),
      ),
    );
    break;
  }
  final plot = plotGoal(progress);
  final extras = [?plot];
  final best = progress.bestRunStage;
  final runTarget = best + 1;
  final duplicate = extras.any((g) => g.runStage == runTarget);
  if (best == 0) {
    goals.add(
      const NextGoal(
        kind: GoalKind.run,
        title: 'Play your first Garden Run',
        detail: '3 hearts, bigger gardens',
        current: 0,
        target: 1,
        estimate: 1,
      ),
    );
  } else if (!duplicate) {
    goals.add(
      NextGoal(
        kind: GoalKind.run,
        title: 'Beat Garden Run stage $best',
        detail: 'Reach stage $runTarget',
        current: best,
        target: runTarget,
        estimate: 2,
        runStage: runTarget,
      ),
    );
  }
  goals.addAll(extras);
  goals.sort((a, b) {
    final byEstimate = a.estimate.compareTo(b.estimate);
    return byEstimate != 0 ? byEstimate : a.kind.index.compareTo(b.kind.index);
  });
  return goals.take(limit).toList();
}
