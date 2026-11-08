import '../game/garden_run.dart';
import '../ui/garden_ui.dart' show formatTime;
import '../ui/run_summary_overlay.dart' show RunReport;

/// Plain ASCII result text for "Copy result" (feature-next-goal-share).
/// [link] is appended as the last line when the build has one.
String resultShareText(RunReport report, {String? link}) {
  final outcome = report.outcome;
  final progress = outcome.progress;
  final lines = <String>[];
  if (report.garden) {
    final cleared = report.stagesCleared;
    lines
      ..add('Tiny Mines - Garden Run')
      ..add(
        'Reached stage ${report.stageReached}, cleared $cleared '
        'garden${cleared == 1 ? '' : 's'} in ${formatTime(report.seconds)}',
      )
      ..add(
        'Hearts: ${report.heartsLeft}/${GardenRun.maxHearts} | '
        'Best stage: ${progress.bestRunStage}',
      );
  } else if (report.daily) {
    lines
      ..add('Tiny Mines - Daily Garden ${report.dailyDay ?? ''}'.trimRight())
      ..add(
        report.won
            ? 'Cleared in ${formatTime(report.seconds)}'
            : 'A mole won today.',
      )
      ..add('Streak: ${outcome.streak} day${outcome.streak == 1 ? '' : 's'}');
  } else {
    final difficulty = report.difficulty!;
    final best = progress.bestTime(difficulty);
    lines
      ..add('Tiny Mines - ${difficulty.title}')
      ..add(
        report.won
            ? 'Cleared in ${formatTime(report.seconds)}'
                  '${best == null ? '' : ' (best ${formatTime(best)})'}'
            : 'A mole won this time.',
      )
      ..add('Garden Lv ${progress.level}');
  }
  final url = link?.trim();
  if (url != null && url.isNotEmpty) lines.add(url);
  return lines.join('\n');
}
