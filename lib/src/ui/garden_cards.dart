import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/garden_palette.dart';
import '../art/garden_tile_art.dart';
import '../art/plot_art.dart';
import '../game/difficulty.dart';
import '../game/garden_run.dart';
import '../meta/garden_plots.dart';
import '../meta/garden_progress.dart';
import '../meta/garden_theme.dart';
import 'garden_ui.dart';

/// Level badge, XP bar and the XP needed for the next level.
class LevelCard extends StatelessWidget {
  const LevelCard({super.key, required this.palette, required this.progress});

  final GardenPalette palette;
  final GardenProgress progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        LevelBadge(palette: palette, level: progress.level, size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PanelCaption('Garden level', palette: palette),
              const SizedBox(height: 6),
              GardenProgressBar(
                palette: palette,
                value: progress.xpIntoLevel / progress.xpForNextLevel,
              ),
              const SizedBox(height: 4),
              Text(
                '${progress.xpIntoLevel} / ${progress.xpForNextLevel} XP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Four theme swatches; locked ones show their required level.
class ThemePicker extends StatelessWidget {
  const ThemePicker({
    super.key,
    required this.palette,
    required this.progress,
    required this.onSelect,
  });

  final GardenPalette palette;
  final GardenProgress progress;
  final ValueChanged<GardenTheme> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final theme in GardenTheme.values) ...[
          if (theme.index > 0) const SizedBox(width: 6),
          Expanded(child: _swatch(theme)),
        ],
      ],
    );
  }

  Widget _swatch(GardenTheme theme) {
    final unlocked = progress.isThemeUnlocked(theme);
    final selected = progress.selectedTheme == theme;
    final themePalette = GardenPalette.of(theme);
    return Tooltip(
      message: unlocked
          ? '${theme.label} theme'
          : '${theme.label}: unlocks at Lv ${theme.requiredLevel}',
      child: Semantics(
        button: true,
        selected: selected,
        enabled: unlocked,
        child: GestureDetector(
          onTap: unlocked ? () => onSelect(theme) : null,
          child: MouseRegion(
            cursor: unlocked
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [themePalette.skyTop, themePalette.hillNear],
                ),
                border: Border.all(
                  color: selected ? palette.accent : palette.panelBorder,
                  width: selected ? 3 : 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          painter: GardenTilePainter(
                            palette: themePalette,
                            look: unlocked ? TileLook.flower : TileLook.covered,
                            seed: 3,
                          ),
                        ),
                        if (!unlocked)
                          const Center(
                            child: Icon(
                              Icons.lock_rounded,
                              color: Color(0xE6FFFFFF),
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      unlocked ? theme.label : 'Lv ${theme.requiredLevel}',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: themePalette.isNight
                            ? const Color(0xFFFFFFFF)
                            : themePalette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Daily garden status: play button, today's result and the streak.
class DailyCard extends StatelessWidget {
  const DailyCard({
    super.key,
    required this.palette,
    required this.progress,
    required this.today,
    required this.playing,
    required this.onPlay,
  });

  final GardenPalette palette;
  final GardenProgress progress;
  final DateTime today;

  /// The daily board is on the table right now.
  final bool playing;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final result = progress.dailyResult(today);
    final streak = progress.currentStreak(today);
    final String status;
    if (result != null) {
      status = result.won
          ? 'Cleared in ${formatTime(result.seconds)}'
          : 'A mole won today';
    } else if (playing) {
      status = 'In progress';
    } else {
      status = 'One board a day';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: PanelCaption(
                'Daily garden - ${formatDay(today)}',
                palette: palette,
              ),
            ),
            Icon(
              Icons.local_fire_department_rounded,
              size: 18,
              color: streak > 0 ? palette.flagCloth : palette.textSecondary,
            ),
            const SizedBox(width: 2),
            Text(
              '$streak day${streak == 1 ? '' : 's'}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          status,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        GardenButton(
          palette: palette,
          label: result != null
              ? 'Practice daily'
              : (playing ? 'Playing daily' : 'Play daily'),
          icon: result != null
              ? Icons.check_rounded
              : Icons.calendar_today_rounded,
          height: 42,
          onPressed: !playing ? onPlay : null,
        ),
      ],
    );
  }
}

/// Entry card for Garden Run: what it is, the best stage and a start button.
class GardenRunCard extends StatelessWidget {
  const GardenRunCard({
    super.key,
    required this.palette,
    required this.progress,
    required this.playing,
    required this.onStart,
  });

  final GardenPalette palette;
  final GardenProgress progress;

  /// A run is on the table right now (the button restarts it).
  final bool playing;

  /// Null while the saved progress is still loading.
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final best = progress.bestRunStage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: PanelCaption('Garden Run', palette: palette)),
            Icon(Icons.favorite_rounded, size: 16, color: palette.danger),
            const SizedBox(width: 3),
            Text(
              best > 0 ? 'Best stage $best' : 'No run yet',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Clear bigger and bigger gardens on ${GardenRun.startHearts} hearts.',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        GardenButton(
          palette: palette,
          label: playing ? 'Restart run' : 'Start Garden Run',
          icon: playing ? Icons.refresh_rounded : Icons.play_arrow_rounded,
          height: 44,
          onPressed: onStart,
        ),
      ],
    );
  }
}

/// Highlighted "Try Garden Run" call to action, shown until the first run is
/// played (feature-first-run-onboarding). Tapping it starts a run.
class GardenRunCta extends StatelessWidget {
  const GardenRunCta({
    super.key,
    required this.palette,
    required this.onStart,
    this.compact = false,
  });

  static const String title = 'Try Garden Run';
  static const String subtitle = '3 hearts, bigger gardens';

  final GardenPalette palette;

  /// Null while the saved progress is still loading.
  final VoidCallback? onStart;

  /// One-row variant for the narrow layout.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final base = palette.danger;
    final radius = BorderRadius.circular(compact ? 22 : 20);
    final heart = Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.favorite_rounded,
          size: compact ? 36 : 44,
          color: const Color(0xFFFFFFFF),
        ),
        Text(
          '${GardenRun.startHearts}',
          style: TextStyle(
            fontSize: compact ? 13 : 16,
            fontWeight: FontWeight.w900,
            color: base,
          ),
        ),
      ],
    );
    const white = Color(0xFFFFFFFF);
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            maxLines: 1,
            style: TextStyle(
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.w900,
              color: white,
            ),
          ),
        ),
        Text(
          subtitle,
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xE6FFFFFF),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          const Text(
            'A mole costs a heart, not the run. Boss gardens heal.',
            style: TextStyle(
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: Color(0xD9FFFFFF),
            ),
          ),
        ],
      ],
    );
    final play = Container(
      width: compact ? 34 : 40,
      height: compact ? 34 : 40,
      decoration: const BoxDecoration(color: white, shape: BoxShape.circle),
      child: Icon(
        Icons.play_arrow_rounded,
        color: base,
        size: compact ? 24 : 28,
      ),
    );
    return Semantics(
      button: true,
      label: '$title: $subtitle',
      excludeSemantics: true,
      child: Opacity(
        opacity: onStart == null ? 0.6 : 1,
        child: Material(
          key: const ValueKey('garden-run-cta'),
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(base, white, 0.18)!, base],
              ),
              border: Border.all(color: white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: onStart,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: compact ? 5 : 12,
                ),
                // Narrow side columns drop the play disc to keep the title.
                child: LayoutBuilder(
                  builder: (context, box) => Row(
                    children: [
                      heart,
                      const SizedBox(width: 10),
                      Expanded(child: texts),
                      if (box.maxWidth >= 240) ...[
                        const SizedBox(width: 8),
                        play,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large hearts row shown right above the board during a Garden Run.
class RunHeartsRow extends StatelessWidget {
  const RunHeartsRow({
    super.key,
    required this.palette,
    required this.hearts,
    this.size = 40,
  });

  /// Total height of the row.
  static const double height = 50;

  final GardenPalette palette;
  final int hearts;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Semantics(
        label: 'Hearts: $hearts of ${GardenRun.maxHearts}',
        child: Row(
          key: const ValueKey('board-hearts'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < GardenRun.maxHearts; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Icon(
                  i < hearts
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: size,
                  color: i < hearts
                      ? palette.danger
                      : palette.danger.withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Live status of a Garden Run: stage, hearts and the run clock. A boss stage
/// gets a highlighted tag.
class GardenRunHud extends StatelessWidget {
  const GardenRunHud({
    super.key,
    required this.palette,
    required this.stage,
    required this.hearts,
    required this.runSeconds,
  });

  final GardenPalette palette;
  final GardenStage stage;
  final int hearts;
  final int runSeconds;

  @override
  Widget build(BuildContext context) {
    final text = TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: 18,
      color: palette.textPrimary,
    );
    // Scales down instead of overflowing on the narrowest screens.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Stage ${stage.stage}', style: text),
          const SizedBox(width: 10),
          Semantics(
            label: 'Hearts: $hearts of ${GardenRun.maxHearts}',
            child: Row(
              key: const ValueKey('run-hearts'),
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < GardenRun.maxHearts; i++)
                  Icon(
                    i < hearts
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 30,
                    color: palette.danger,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('Run ${formatTime(runSeconds)}', style: text),
          if (stage.boss) ...[
            const SizedBox(width: 10),
            Container(
              key: const ValueKey('boss-tag'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: palette.flowerCenter,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'BOSS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Color(0xFF3B2A05),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One garden plot tile: in color when earned, a dim greyed outline with a
/// lock otherwise. The tooltip names the plot and what earns it.
class PlotTile extends StatelessWidget {
  const PlotTile({
    super.key,
    required this.palette,
    required this.plot,
    required this.earned,
    this.size = 56,
  });

  final GardenPalette palette;
  final GardenPlot plot;
  final bool earned;
  final double size;

  static const List<double> _grey = [
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 0.38, 0,
  ];

  @override
  Widget build(BuildContext context) {
    Widget art = CustomPaint(
      size: Size.square(size),
      painter: PlotPainter(plot: plot, palette: palette),
    );
    if (!earned) {
      art = Stack(
        alignment: Alignment.center,
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.matrix(_grey),
            child: art,
          ),
          Icon(
            Icons.lock_rounded,
            size: size * 0.32,
            color: palette.textSecondary,
          ),
        ],
      );
    }
    return Tooltip(
      message: earned
          ? '${plot.label} - earned'
          : '${plot.label}: ${plot.requirementText}',
      child: Semantics(
        label: earned
            ? '${plot.label}, earned'
            : '${plot.label}, locked: ${plot.requirementText}',
        child: Container(
          key: ValueKey('plot-${plot.name}'),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: earned
                ? palette.skyBottom.withValues(alpha: 0.55)
                : palette.textSecondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(size * 0.22),
            border: Border.all(
              color: earned ? palette.flowerCenter : palette.panelBorder,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.2),
            child: art,
          ),
        ),
      ),
    );
  }
}

/// "Garden plots N/8": both sets with their plots, the set bonus and the
/// next plot to earn (feature-garden-collection).
class GardenPlotsCard extends StatelessWidget {
  const GardenPlotsCard({
    super.key,
    required this.palette,
    required this.progress,
  });

  final GardenPalette palette;
  final GardenProgress progress;

  @override
  Widget build(BuildContext context) {
    final earned = progress.earnedPlots.toSet();
    final next = progress.nextPlot;
    final dim = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 12,
      color: palette.textSecondary,
    );
    return Column(
      key: const ValueKey('garden-plots'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: PanelCaption('Garden plots', palette: palette)),
            Text(
              '${earned.length}/${GardenPlots.total}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
        for (final set in PlotSet.values) ...[
          const SizedBox(height: 6),
          Text(
            progress.rewardedSets.contains(set.id)
                ? '${set.label} - complete'
                : '${set.label} - +${set.bonusXp} XP when complete',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: dim,
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, box) {
              final tile = ((box.maxWidth - 3 * 6) / 4).clamp(28.0, 60.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final plot in set.plots)
                    PlotTile(
                      palette: palette,
                      plot: plot,
                      earned: earned.contains(plot),
                      size: tile,
                    ),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 8),
        Text(
          next == null
              ? 'Collection complete!'
              : 'Next: ${next.label} - '
                    '${next.goalText(dailyClears: progress.dailyClears)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
            color: palette.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Best time and win count per difficulty, plus the best daily streak.
class RecordsCard extends StatelessWidget {
  const RecordsCard({super.key, required this.palette, required this.progress});

  final GardenPalette palette;
  final GardenProgress progress;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 14,
      color: palette.textPrimary,
    );
    final dim = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 12,
      color: palette.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelCaption('Records', palette: palette),
        const SizedBox(height: 6),
        for (final difficulty in Difficulty.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(child: Text(difficulty.label, style: style)),
                Text(
                  '${progress.wins[difficulty.name] ?? 0}/${progress.plays[difficulty.name] ?? 0} won',
                  style: dim,
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 52,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      progress.bestTime(difficulty) == null
                          ? '-:--'
                          : formatTime(progress.bestTime(difficulty)!),
                      maxLines: 1,
                      style: style,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            children: [
              Expanded(child: Text('Best streak', style: style)),
              Text(
                '${progress.bestStreak} day${progress.bestStreak == 1 ? '' : 's'}',
                style: style,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "My garden" sheet for narrow screens: level, themes, daily, records.
/// Blocks the board; Escape or Enter closes it.
class GardenOverlay extends StatefulWidget {
  const GardenOverlay({
    super.key,
    required this.palette,
    required this.progress,
    required this.today,
    required this.dailyPlaying,
    required this.onSelectTheme,
    required this.onPlayDaily,
    required this.onClose,
  });

  final GardenPalette palette;
  final GardenProgress progress;
  final DateTime today;
  final bool dailyPlaying;
  final ValueChanged<GardenTheme> onSelectTheme;
  final VoidCallback onPlayDaily;
  final VoidCallback onClose;

  @override
  State<GardenOverlay> createState() => _GardenOverlayState();
}

class _GardenOverlayState extends State<GardenOverlay> {
  final FocusNode _focus = FocusNode(debugLabel: 'garden-overlay');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    if (key != LogicalKeyboardKey.escape &&
        key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (key != LogicalKeyboardKey.escape && !_focus.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) widget.onClose();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Stack(
        children: [
          ModalBarrier(
            color: const Color(0x8C101A14),
            dismissible: true,
            onDismiss: widget.onClose,
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Material(
                    type: MaterialType.transparency,
                    child: GardenPanel(
                      palette: palette,
                      radius: 26,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'My Garden',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            LevelCard(
                              palette: palette,
                              progress: widget.progress,
                            ),
                            const SizedBox(height: 14),
                            PanelCaption('Themes', palette: palette),
                            const SizedBox(height: 6),
                            ThemePicker(
                              palette: palette,
                              progress: widget.progress,
                              onSelect: widget.onSelectTheme,
                            ),
                            const SizedBox(height: 14),
                            DailyCard(
                              palette: palette,
                              progress: widget.progress,
                              today: widget.today,
                              playing: widget.dailyPlaying,
                              onPlay: widget.onPlayDaily,
                            ),
                            const SizedBox(height: 14),
                            GardenPlotsCard(
                              palette: palette,
                              progress: widget.progress,
                            ),
                            const SizedBox(height: 14),
                            RecordsCard(
                              palette: palette,
                              progress: widget.progress,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              child: TextButton(
                                onPressed: widget.onClose,
                                style: TextButton.styleFrom(
                                  foregroundColor: palette.textSecondary,
                                ),
                                child: const Text(
                                  'Close',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
