import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/garden_palette.dart';
import '../art/garden_tile_art.dart';
import '../game/difficulty.dart';
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
