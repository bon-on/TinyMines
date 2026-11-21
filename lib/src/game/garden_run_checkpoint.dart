import '../../mine_field.dart';
import 'garden_run.dart';
import 'garden_tools.dart';

/// An active board or the reward choice immediately before the next board.
class GardenRunCheckpoint {
  const GardenRunCheckpoint({
    required this.run,
    required this.bankedMs,
    required this.stageMs,
    required this.heals,
    required this.moves,
    required this.flagMode,
    required this.board,
    required this.offer,
  });

  final GardenRunState run;
  final int bankedMs;
  final int stageMs;
  final int heals;
  final int moves;
  final bool flagMode;
  final String? board;
  final List<GardenTool> offer;

  Map<String, Object?> toJson() => {
    'version': 1,
    'stage': run.stage,
    'hearts': run.hearts,
    'hints': run.hints,
    'clovers': run.clovers,
    'cans': run.cans,
    'bankedMs': bankedMs,
    'stageMs': stageMs,
    'heals': heals,
    'moves': moves,
    'flagMode': flagMode,
    'board': board,
    'offer': [for (final tool in offer) tool.name],
  };

  static GardenRunCheckpoint? fromJson(Object? json) {
    if (json is! Map || json['version'] != 1) return null;
    int? read(String key, int min, int max) {
      final value = json[key];
      return value is int && value >= min && value <= max ? value : null;
    }

    final stage = read('stage', 1, 1 << 30);
    final hearts = read('hearts', 1, GardenRun.maxHearts);
    final hints = read('hints', 0, GardenTools.maxHints);
    final clovers = read('clovers', 0, GardenTools.maxCharges);
    final cans = read('cans', 0, GardenTools.maxCharges);
    final bankedMs = read('bankedMs', 0, 281474976710656);
    final stageMs = read('stageMs', 0, 281474976710656);
    final heals = read('heals', 0, GardenRun.bossStages.length);
    final moves = read('moves', 0, 1 << 30);
    final flagMode = json['flagMode'];
    final board = json['board'];
    final names = json['offer'];
    if (stage == null ||
        hearts == null ||
        hints == null ||
        clovers == null ||
        cans == null ||
        bankedMs == null ||
        stageMs == null ||
        heals == null ||
        moves == null ||
        flagMode is! bool ||
        (board != null && board is! String) ||
        names is! List ||
        names.length > GardenTools.offerSize) {
      return null;
    }
    final run = GardenRunState(
      stage: stage,
      cleared: stage - 1,
      hearts: hearts,
      hints: hints,
      clovers: clovers,
      cans: cans,
    );
    final offer = [
      for (final name in names)
        ...GardenTool.values.where((tool) => tool.name == name),
    ];
    if (offer.length != names.length ||
        offer.toSet().length != offer.length ||
        offer.any((tool) => !GardenTools.eligible(tool, run)) ||
        (board == null && (stage == 1 || offer.isEmpty)) ||
        (board != null && offer.isNotEmpty)) {
      return null;
    }
    final checkpoint = GardenRunCheckpoint(
      run: run,
      bankedMs: bankedMs,
      stageMs: stageMs,
      heals: heals,
      moves: moves,
      flagMode: flagMode,
      board: board as String?,
      offer: List.unmodifiable(offer),
    );
    if (board != null) {
      final field = checkpoint._newBoard();
      if (!checkpoint.restoreBoard(field) || (stage == 1 && !field.armed)) {
        return null;
      }
    }
    return checkpoint;
  }

  MineField _newBoard() {
    final config = run.config;
    return MineField(
      size: config.size,
      mineCount: config.mines,
      survivable: true,
    );
  }

  bool restoreBoard(MineField field) =>
      board == null || field.restoreGardenBoard(board!);
}
