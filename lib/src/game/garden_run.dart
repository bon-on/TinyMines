import '../../fair_easy_field.dart';

/// Size and mine count of one Garden Run stage.
class GardenStage {
  const GardenStage({
    required this.stage,
    required this.size,
    required this.mines,
  });

  final int stage;
  final int size;
  final int mines;

  bool get boss => GardenRun.isBoss(stage);

  /// Stages the logical (no-guess) generator supports use it; the others use
  /// the regular generator.
  bool get fairStart =>
      size == FairEasyField.size && mines == FairEasyField.mineCount;

  double get density => mines / (size * size);

  /// Picker-style label, e.g. "8x8".
  String get sizeLabel => '${size}x$size';
}

/// Rules of Garden Run: the stage table, hearts, the shared hint budget and
/// the XP math. Pure so it can be unit tested without widgets.
class GardenRun {
  const GardenRun._();

  static const int startHearts = 3;
  static const int maxHearts = 3;
  static const int startHints = 3;
  static const int maxHints = 5;

  /// A clear count that is a multiple of this adds one hint.
  static const int stagesPerHint = 3;

  static const int xpPerStage = 15;
  static const int participationXp = 10;

  /// Mines never exceed this share of the board.
  static const double maxDensity = 0.22;

  static const List<int> bossStages = [5, 10];

  // (size, mines) for stages 1..10.
  static const List<(int, int)> _table = [
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

  static bool isBoss(int stage) => bossStages.contains(stage);

  /// Stage [number] (1-based; lower values count as stage 1). After the table
  /// the last board size gains one mine per stage, up to [maxDensity].
  static GardenStage stage(int number) {
    final n = number < 1 ? 1 : number;
    if (n <= _table.length) {
      final (size, mines) = _table[n - 1];
      return GardenStage(stage: n, size: size, mines: mines);
    }
    final (size, last) = _table.last;
    final cap = (size * size * maxDensity).floor();
    final mines = last + (n - _table.length);
    return GardenStage(stage: n, size: size, mines: mines > cap ? cap : mines);
  }

  /// XP granted once when a run ends. A run that never dug a patch earns none.
  static int xpFor({required int stagesCleared, required bool participated}) {
    if (!participated) return 0;
    return (stagesCleared < 0 ? 0 : stagesCleared) * xpPerStage +
        participationXp;
  }
}

/// Hearts, hints and progress of one run. Immutable; every change returns a
/// new state.
class GardenRunState {
  const GardenRunState({
    this.stage = 1,
    this.hearts = GardenRun.startHearts,
    this.hints = GardenRun.startHints,
    this.cleared = 0,
  });

  /// The stage being played (or the next one once a clear is recorded).
  final int stage;
  final int hearts;
  final int hints;

  /// Boards cleared in this run.
  final int cleared;

  bool get isOver => hearts <= 0;
  bool get canHint => hints > 0;
  GardenStage get config => GardenRun.stage(stage);

  GardenRunState _with({int? stage, int? hearts, int? hints, int? cleared}) {
    return GardenRunState(
      stage: stage ?? this.stage,
      hearts: hearts ?? this.hearts,
      hints: hints ?? this.hints,
      cleared: cleared ?? this.cleared,
    );
  }

  /// [count] mines were dug.
  GardenRunState loseHearts([int count = 1]) {
    final left = hearts - count;
    return _with(hearts: left < 0 ? 0 : left);
  }

  GardenRunState useHint() => canHint ? _with(hints: hints - 1) : this;

  /// The current stage was cleared: a boss stage heals one heart, every
  /// [GardenRun.stagesPerHint]th clear adds a hint, and the next stage is up.
  GardenRunState clearStage() {
    final total = cleared + 1;
    final healed = GardenRun.isBoss(stage) && hearts < GardenRun.maxHearts
        ? hearts + 1
        : hearts;
    final more =
        total % GardenRun.stagesPerHint == 0 && hints < GardenRun.maxHints
        ? hints + 1
        : hints;
    return _with(stage: stage + 1, hearts: healed, hints: more, cleared: total);
  }
}
