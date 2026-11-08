/// Garden plot collection (feature-garden-collection): eight decorated plots
/// in two sets, earned by Garden Run stages and scored daily clears. Plots
/// are derived from saved counters, so nothing per plot is stored.
library;

/// A group of plots with a one-time XP bonus when all are earned.
enum PlotSet {
  runPath(id: 'run', label: 'Run Path', bonusXp: 100),
  dailyBeds(id: 'daily', label: 'Daily Beds', bonusXp: 150);

  const PlotSet({required this.id, required this.label, required this.bonusXp});

  /// Stored in `rewardedSets`; never rename.
  final String id;
  final String label;
  final int bonusXp;

  List<GardenPlot> get plots => [
    for (final plot in GardenPlot.values)
      if (plot.set == this) plot,
  ];

  static PlotSet? fromId(Object? id) {
    for (final set in values) {
      if (set.id == id) return set;
    }
    return null;
  }
}

enum GardenPlot {
  sprouts(PlotSet.runPath, 'Sprout bed', 2),
  tulips(PlotSet.runPath, 'Tulip row', 3),
  roseArch(PlotSet.runPath, 'Rose arch', 5),
  sunflowers(PlotSet.runPath, 'Sunflower patch', 7),
  mushrooms(PlotSet.dailyBeds, 'Mushroom ring', 1),
  lilyPond(PlotSet.dailyBeds, 'Lily pond', 2),
  berryBush(PlotSet.dailyBeds, 'Berry bush', 4),
  birdBath(PlotSet.dailyBeds, 'Bird bath', 7);

  const GardenPlot(this.set, this.label, this.requirement);

  final PlotSet set;
  final String label;

  /// Garden Run stage to reach (Run Path) or scored daily clears (Daily Beds).
  final int requirement;

  bool get isRunPlot => set == PlotSet.runPath;

  bool isEarned({required int bestRunStage, required int dailyClears}) =>
      isRunPlot ? bestRunStage >= requirement : dailyClears >= requirement;

  /// How far away the plot is: stages or daily clears still missing.
  int remaining({required int bestRunStage, required int dailyClears}) {
    final have = isRunPlot ? bestRunStage : dailyClears;
    return requirement > have ? requirement - have : 0;
  }

  /// What earns it, e.g. "Reach stage 5 in Garden Run".
  String get requirementText => isRunPlot
      ? 'Reach stage $requirement in Garden Run'
      : requirement == 1
      ? 'Clear a daily garden'
      : 'Clear $requirement daily gardens';

  /// Next step from the current counters, e.g. "Clear 2 more daily gardens".
  String goalText({required int dailyClears}) {
    if (isRunPlot) return requirementText;
    final left = requirement - dailyClears;
    if (left <= 0) return requirementText;
    if (dailyClears == 0) return requirementText;
    return left == 1
        ? 'Clear 1 more daily garden'
        : 'Clear $left more daily gardens';
  }
}

/// Collection helpers over the two saved counters.
class GardenPlots {
  const GardenPlots._();

  static int get total => GardenPlot.values.length;

  static List<GardenPlot> earned({
    required int bestRunStage,
    required int dailyClears,
  }) => [
    for (final plot in GardenPlot.values)
      if (plot.isEarned(bestRunStage: bestRunStage, dailyClears: dailyClears))
        plot,
  ];

  /// The closest plot not yet earned (ties: Run Path first, then table
  /// order); null when the collection is complete.
  static GardenPlot? next({
    required int bestRunStage,
    required int dailyClears,
  }) {
    GardenPlot? best;
    var bestLeft = 0;
    for (final plot in GardenPlot.values) {
      final left = plot.remaining(
        bestRunStage: bestRunStage,
        dailyClears: dailyClears,
      );
      if (left == 0) continue;
      if (best == null || left < bestLeft) {
        best = plot;
        bestLeft = left;
      }
    }
    return best;
  }

  static bool isSetComplete(
    PlotSet set, {
    required int bestRunStage,
    required int dailyClears,
  }) => set.plots.every(
    (p) => p.isEarned(bestRunStage: bestRunStage, dailyClears: dailyClears),
  );
}
