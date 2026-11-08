import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/garden_palette.dart';
import '../art/garden_tile_art.dart';
import '../game/difficulty.dart';
import '../meta/garden_plots.dart';
import '../meta/garden_progress.dart';
import '../meta/next_goal.dart';
import '../share/result_copy.dart';
import '../share/result_text.dart';
import 'garden_cards.dart';
import 'garden_ui.dart';

/// Facts shown on the end-of-run card.
class RunReport {
  const RunReport({
    required this.won,
    required Difficulty this.difficulty,
    required this.seconds,
    required this.outcome,
    this.daily = false,
    this.practice = false,
    this.dailyDay,
  }) : stageReached = null,
       stagesCleared = 0,
       heartsLeft = 0;

  /// End of a Garden Run: [seconds] is the whole run, [won] means at least
  /// one board was cleared.
  const RunReport.garden({
    required this.stageReached,
    required this.stagesCleared,
    required this.seconds,
    required this.outcome,
    this.heartsLeft = 0,
  }) : won = stagesCleared > 0,
       difficulty = null,
       daily = false,
       practice = false,
       dailyDay = null;

  final bool won;

  /// The board's preset; null for a Garden Run.
  final Difficulty? difficulty;
  final int seconds;
  final bool daily;
  final bool practice;
  final RunOutcome outcome;

  /// Garden Run only: the stage the run ended on and the boards cleared.
  final int? stageReached;
  final int stagesCleared;

  /// Garden Run only: hearts left when the run ended.
  final int heartsLeft;

  /// Daily boards: the day key (YYYY-MM-DD) of the board.
  final String? dailyDay;

  bool get garden => stageReached != null;
}

/// End-of-run card: result, time, best, "New best!", XP with the level bar,
/// unlocked themes and the daily streak. It appears after a short pause so
/// the blast or bloom on the board can be seen; the board gets no input
/// while it is up. Enter plays again, Escape closes it.
class RunSummaryOverlay extends StatefulWidget {
  const RunSummaryOverlay({
    super.key,
    required this.report,
    required this.palette,
    required this.onPlayAgain,
    required this.onClose,
    this.onNext,
    this.nextLabel,
    this.onPractice,
    this.onShown,
    this.onTryGardenRun,
    this.shareLink,
    this.copier = const ResultCopier(),
    this.delay = const Duration(milliseconds: 750),
  });

  final RunReport report;
  final GardenPalette palette;
  final VoidCallback onPlayAgain;
  final VoidCallback onClose;

  /// Next harder difficulty (or, after a Garden Run, the normal board); null
  /// hides the button.
  final VoidCallback? onNext;
  final String? nextLabel;
  final VoidCallback? onPractice;

  /// Called once when the card has popped in (for the reward sound).
  final VoidCallback? onShown;

  /// Shows the "Try Garden Run" call to action (regular win before the
  /// first run); null hides it.
  final VoidCallback? onTryGardenRun;

  /// Link appended to the copied result; null copies text only.
  final String? shareLink;
  final ResultCopier copier;
  final Duration delay;

  @override
  State<RunSummaryOverlay> createState() => _RunSummaryOverlayState();
}

class _RunSummaryOverlayState extends State<RunSummaryOverlay>
    with SingleTickerProviderStateMixin {
  static const int _bodyMs = 1700;
  late final int _delayMs = widget.delay.inMilliseconds;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _delayMs + _bodyMs),
  )..forward();
  final FocusNode _focus = FocusNode(debugLabel: 'run-summary');
  final FocusNode _playAgainFocus = FocusNode(debugLabel: 'play-again');
  bool _shownReported = false;

  /// "Copied!" / "Could not copy" shown on the copy button for a moment.
  String? _copyNote;
  Timer? _copyTimer;
  bool _copying = false;

  Future<void> _copy() async {
    if (_copying) return;
    _copying = true;
    var ok = false;
    try {
      ok = await widget.copier.copyText(
        resultShareText(widget.report, link: widget.shareLink),
      );
    } catch (_) {
      ok = false;
    }
    _copying = false;
    if (!mounted) return;
    _copyTimer?.cancel();
    setState(() => _copyNote = ok ? 'Copied!' : 'Could not copy');
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copyNote = null);
    });
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_checkShown);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playAgainFocus.requestFocus();
    });
  }

  void _checkShown() {
    if (_shownReported || _phase(0, 0.2) < 1) return;
    _shownReported = true;
    widget.onShown?.call();
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _controller.dispose();
    _focus.dispose();
    _playAgainFocus.dispose();
    super.dispose();
  }

  /// Progress (0..1) through [begin]..[end] of the card's own timeline
  /// (after the delay), as fractions of its body length.
  double _phase(double begin, double end, [Curve curve = Curves.easeOutCubic]) {
    final ms = _controller.value * (_delayMs + _bodyMs) - _delayMs;
    final t = ((ms / _bodyMs - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final isEnter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (!isEnter && key != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    // Let a focused button activate its own action (including practice).
    if (isEnter && !_focus.hasPrimaryFocus) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    if (isEnter) {
      widget.onPlayAgain();
    } else {
      widget.onClose();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final appear = _phase(0, 0.2, Curves.easeOutBack);
          return Stack(
            children: [
              ModalBarrier(
                dismissible: false,
                color: Color.fromRGBO(16, 26, 20, 0.55 * _phase(0, 0.15)),
              ),
              if (_phase(0, 0.01) > 0)
                SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Opacity(
                          opacity: _phase(0, 0.1),
                          child: Transform.scale(
                            scale: 0.85 + 0.15 * appear,
                            child: Material(
                              type: MaterialType.transparency,
                              child: GardenPanel(
                                palette: palette,
                                radius: 28,
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  18,
                                  22,
                                  16,
                                ),
                                // Actions stay pinned under the scrolling
                                // details so they are visible on short
                                // screens (844x390) without scrolling.
                                child: LayoutBuilder(
                                  builder: (context, box) {
                                    final short = box.maxHeight < 480;
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: SingleChildScrollView(
                                            child: _content(
                                              palette,
                                              short: short,
                                            ),
                                          ),
                                        ),
                                        _actions(palette, short: short),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _content(GardenPalette palette, {required bool short}) {
    final report = widget.report;
    final outcome = report.outcome;
    final garden = report.garden;
    final title = garden
        ? 'Run over!'
        : report.won
        ? (report.daily ? 'Daily garden cleared!' : 'Garden cleared!')
        : 'Bonk! A mole!';
    final subtitle = garden
        ? 'Garden Run - stage ${report.stageReached} reached'
        : report.practice
        ? 'Daily practice - unscored'
        : report.daily
        ? 'Daily Garden'
        : report.difficulty!.title;
    final best = garden || report.difficulty == null
        ? null
        : outcome.progress.bestTime(report.difficulty!);
    final level = outcome.progress;
    // Bar fills from the old XP to the new XP.
    final barT = _phase(0.3, 0.75);
    final before = outcome.progress.totalXp - outcome.xpGained;
    final shownXp = before + (outcome.xpGained * barT).round();
    final shown = GardenProgress.fromJson({'totalXp': shownXp});
    final textPrimary = palette.textPrimary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.6 + 0.4 * _phase(0.05, 0.3, Curves.elasticOut),
          child: TileArt(
            palette: palette,
            look: report.won ? TileLook.flower : TileLook.moleHit,
            size: short ? 44 : 76,
            seed: 4,
          ),
        ),
        SizedBox(height: short ? 2 : 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: short ? 22 : 26,
            fontWeight: FontWeight.w900,
            color: report.won ? textPrimary : palette.danger,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        if (garden)
          Row(
            children: [
              Expanded(
                child: StatTile(
                  palette: palette,
                  label: 'STAGE',
                  value: '${report.stageReached}',
                  large: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  palette: palette,
                  label: 'CLEARED',
                  value: '${report.stagesCleared}',
                  large: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  palette: palette,
                  label: 'TIME',
                  value: formatTime(report.seconds),
                  large: true,
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: StatTile(
                  palette: palette,
                  label: 'TIME',
                  value: report.won ? formatTime(report.seconds) : '--',
                  large: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  palette: palette,
                  label: report.daily ? 'STREAK' : 'BEST',
                  value: report.daily
                      ? '${outcome.streak} d'
                      : (best == null ? '--' : formatTime(best)),
                  large: true,
                ),
              ),
            ],
          ),
        if (outcome.isNewBest) ...[
          const SizedBox(height: 10),
          Transform.scale(
            scale: _phase(0.2, 0.4, Curves.elasticOut),
            child: _Pill(
              text: garden ? 'New best stage!' : 'New best!',
              color: palette.flowerCenter,
              textColor: const Color(0xFF3B2A05),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            LevelBadge(palette: palette, level: shown.level, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '+${(outcome.xpGained * barT).round()} XP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: palette.accent,
                          ),
                        ),
                      ),
                      Text(
                        '${shown.xpIntoLevel} / ${shown.xpForNextLevel}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GardenProgressBar(
                    palette: palette,
                    value: shown.xpIntoLevel / shown.xpForNextLevel,
                    height: 12,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (outcome.leveledUp && barT >= 1) ...[
          const SizedBox(height: 10),
          _Pill(
            text: 'Level up! Lv ${level.level}',
            color: palette.accent,
            textColor: palette.onAccent,
          ),
        ],
        for (final theme in outcome.newlyUnlockedThemes)
          if (barT >= 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _Pill(
                text: 'New theme: ${theme.label}',
                color: palette.petal,
                textColor: const Color(0xFF3B1830),
              ),
            ),
        for (final plot in outcome.newPlots)
          if (barT >= 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _Pill(
                text:
                    'New plot: ${plot.label} '
                    '(${outcome.progress.earnedPlots.length}/${GardenPlots.total})',
                color: palette.flowerCenter,
                textColor: const Color(0xFF3B2A05),
              ),
            ),
        for (final set in outcome.completedSets)
          if (barT >= 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _Pill(
                text: 'Set complete: ${set.label} +${set.bonusXp} XP',
                color: palette.accent,
                textColor: palette.onAccent,
              ),
            ),
        if (outcome.dailyRecorded) ...[
          const SizedBox(height: 10),
          Text(
            'Daily streak: ${outcome.streak} day${outcome.streak == 1 ? '' : 's'}. Come back tomorrow!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: palette.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 14),
        NextGoalBlock(palette: palette, goals: nextGoals(outcome.progress)),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _actions(GardenPalette palette, {required bool short}) {
    final report = widget.report;
    final garden = report.garden;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: short ? 8 : 12),
        if (widget.onPractice != null) ...[
          if (!short) ...[
            Text(
              report.practice
                  ? 'No XP or records. Your original daily result is unchanged.'
                  : 'Retry this board for practice. Your daily result stays saved.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          GardenButton(
            palette: palette,
            label: 'Practice same board',
            icon: Icons.school_rounded,
            primary: false,
            onPressed: widget.onPractice,
          ),
          const SizedBox(height: 10),
        ],
        if (widget.onTryGardenRun != null) ...[
          GardenRunCta(
            palette: palette,
            compact: true,
            onStart: widget.onTryGardenRun,
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: GardenButton(
                palette: palette,
                label: garden ? 'New Run' : 'New Field',
                icon: Icons.refresh_rounded,
                focusNode: _playAgainFocus,
                onPressed: widget.onPlayAgain,
              ),
            ),
            if (widget.onNext != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: GardenButton(
                  palette: palette,
                  label:
                      widget.nextLabel ??
                      'Next: ${report.difficulty!.next!.label}',
                  primary: false,
                  onPressed: widget.onNext,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            if (!report.practice)
              TextButton.icon(
                key: const ValueKey('copy-result'),
                onPressed: _copy,
                style: TextButton.styleFrom(
                  foregroundColor: palette.textSecondary,
                ),
                icon: Icon(
                  _copyNote == 'Copied!'
                      ? Icons.check_rounded
                      : Icons.content_copy_rounded,
                  size: 18,
                ),
                label: Text(
                  _copyNote ?? 'Copy result',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            TextButton(
              onPressed: widget.onClose,
              style: TextButton.styleFrom(
                foregroundColor: palette.textSecondary,
              ),
              child: const Text(
                'View board',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Next goal" box: the closest goal with its numbers and a bar, then up to
/// two more goals as one short line each (feature-next-goal-share).
class NextGoalBlock extends StatelessWidget {
  const NextGoalBlock({super.key, required this.palette, required this.goals});

  final GardenPalette palette;
  final List<NextGoal> goals;

  static IconData iconFor(GoalKind kind) => switch (kind) {
    GoalKind.level => Icons.trending_up_rounded,
    GoalKind.plot => Icons.yard_rounded,
    GoalKind.run => Icons.favorite_rounded,
    GoalKind.theme => Icons.palette_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return const SizedBox.shrink();
    final top = goals.first;
    final dim = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: palette.textSecondary,
    );
    return Container(
      key: const ValueKey('next-goal'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: palette.textSecondary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconFor(top.kind),
                  size: 20,
                  color: palette.onAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PanelCaption('Next goal', palette: palette),
                    Text(
                      top.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      top.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dim,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GardenProgressBar(palette: palette, value: top.fraction, height: 8),
          for (final goal in goals.skip(1))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    iconFor(goal.kind),
                    size: 14,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${goal.title} - ${goal.detail}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dim,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          color: textColor,
        ),
      ),
    );
  }
}
