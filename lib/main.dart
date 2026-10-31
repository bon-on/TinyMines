import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'best_times.dart';
import 'how_to_play.dart';
import 'mine_field.dart';
import 'platform/game_platform.dart';
import 'result_registration.dart';
import 'src/audio/sound_fx.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Right-click flags tiles, so suppress the browser context menu.
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  // Portal builds (CrazyGames) report gameplay events; others get a no-op.
  final platform = createGamePlatform();
  try {
    await platform.initialize();
  } catch (_) {
    // A broken portal SDK must never keep the game from starting.
  }
  runApp(TinyMinesApp(platform: platform));
}

class TinyMinesApp extends StatelessWidget {
  const TinyMinesApp({
    super.key,
    this.platform = const NoopGamePlatform(),
    this.soundFx,
  });

  final GamePlatform platform;

  /// Injectable sound effects; tests pass a recording one.
  final SoundFx? soundFx;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiny Mines',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101214),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8AA39B),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: TinyMinesScreen(platform: platform, soundFx: soundFx),
    );
  }
}

/// Seconds added to the clock for each hint, so hinted clears rank lower.
const int _hintPenaltySeconds = 10;

const List<TutorialStep> _tutorialSteps = [
  TutorialStep(
    Icons.grid_view,
    'Clear every safe tile without hitting a mine. A number counts the mines around it.',
  ),
  TutorialStep(
    Icons.flag,
    'Tap or click to reveal. Long press or right-click to flag a mine.',
  ),
  TutorialStep(
    Icons.lightbulb,
    'Tap a number with all its flags placed to clear the rest. Hints cost +${_hintPenaltySeconds}s.',
  ),
];

class TinyMinesScreen extends StatefulWidget {
  const TinyMinesScreen({
    super.key,
    this.random,
    this.bestTimes = const BestTimes(),
    this.tutorialStore = const TutorialStore(),
    this.platform = const NoopGamePlatform(),
    this.stopwatch,
    this.soundFx,
  });

  /// Sound effects and mute switch; defaults to the real player.
  final SoundFx? soundFx;

  /// Clock for the solve time; tests can inject a controllable one.
  final Stopwatch? stopwatch;

  /// Portal hooks (gameplay events, leaderboard policy); no-op by default.
  final GamePlatform platform;

  /// Mine placement source; tests pass a seeded generator.
  final math.Random? random;

  /// Local best-time storage; tests can substitute mock preferences.
  final BestTimes bestTimes;

  /// First-run tutorial flag storage; tests can substitute a fake.
  final TutorialStore tutorialStore;

  @override
  State<TinyMinesScreen> createState() => _TinyMinesScreenState();
}

class _TinyMinesScreenState extends State<TinyMinesScreen> {
  _Difficulty _difficulty = _Difficulty.easy;
  late MineField _field;
  int _moves = 0;
  // Elapsed time is measured by a stopwatch (paused while the tutorial is
  // open) so brief pauses never discard partial seconds; the periodic timer
  // only repaints the clock.
  late final Stopwatch _clock = widget.stopwatch ?? Stopwatch();
  int _hintPenalty = 0;
  int get _elapsedSeconds => _clock.elapsedMilliseconds ~/ 1000 + _hintPenalty;
  int _hints = 3;
  final Map<_Difficulty, int?> _bests = {};
  Timer? _timer;
  bool _tutorialOpen = false;
  int _tutorialSession = 0;
  // Gameplay events wait until the first-run tutorial check has answered.
  bool _tutorialChecked = false;
  bool _gameplayActive = false;
  late final SoundFx _sound =
      widget.soundFx ?? SoundFx(platform: widget.platform);

  bool get _lost => _field.lost;
  bool get _won => _field.won;

  @override
  void initState() {
    super.initState();
    _sound.addListener(_onSoundChanged);
    if (widget.soundFx == null) _sound.load();
    _restart();
    _loadBest(_difficulty);
    _maybeShowTutorial();
  }

  Future<void> _maybeShowTutorial() async {
    final session = _tutorialSession;
    var seen = false;
    try {
      seen = await widget.tutorialStore.hasSeen();
    } catch (_) {}
    if (!mounted) return;
    // Rebuild so the pointer gate in build() lifts even if nothing else does.
    setState(() => _tutorialChecked = true);
    // Ignore a stale answer if the player already opened it via "?".
    if (seen || session != _tutorialSession) {
      _syncGameplay();
      return;
    }
    _openTutorial();
  }

  /// Reports gameplay start/stop to the platform exactly on transitions:
  /// running only after the tutorial check, while no tutorial is open and the
  /// field is not finished.
  void _syncGameplay() {
    final wantActive = _tutorialChecked && !_tutorialOpen && !_lost && !_won;
    if (wantActive == _gameplayActive) return;
    _gameplayActive = wantActive;
    try {
      if (wantActive) {
        widget.platform.gameplayStart();
      } else {
        widget.platform.gameplayStop();
      }
    } catch (_) {}
  }

  void _openTutorial() {
    _tutorialSession++;
    _stopTimer();
    setState(() => _tutorialOpen = true);
    _syncGameplay();
  }

  void _closeTutorial() {
    if (!_tutorialOpen) return;
    setState(() => _tutorialOpen = false);
    _syncGameplay();
    if (_field.armed && !_lost && !_won) _startTimer();
    widget.tutorialStore.markSeen();
  }

  void _onSoundChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sound.removeListener(_onSoundChanged);
    if (widget.soundFx == null) _sound.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadBest(_Difficulty difficulty) async {
    final best = await widget.bestTimes.load(difficulty.name);
    if (!mounted) return;
    setState(() => _bests[difficulty] = best);
  }

  Future<void> _recordBest(_Difficulty difficulty, int seconds) async {
    if (await widget.bestTimes.record(difficulty.name, seconds)) {
      if (!mounted) return;
      setState(() => _bests[difficulty] = seconds);
    }
  }

  void _restart() {
    _stopTimer();
    _clock.reset();
    _hintPenalty = 0;
    _field = MineField(
      size: _difficulty.size,
      mineCount: _difficulty.mines,
      random: widget.random,
    );
    _moves = 0;
    _hints = _difficulty.hints;
    setState(() {});
    _syncGameplay();
  }

  void _startTimer() {
    _clock.start();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _lost || _won) return;
      setState(() {});
    });
  }

  void _stopTimer() {
    _clock.stop();
    _timer?.cancel();
    _timer = null;
  }

  void _tapCell(int index) {
    if (_lost || _won) return;
    final wasArmed = _field.armed;
    final outcome = _field.cells[index].revealed
        ? _field.chord(index)
        : _field.reveal(index);
    if (outcome == RevealOutcome.none) return;
    if (!wasArmed) _startTimer();
    _moves++;
    _afterReveal();
  }

  void _afterReveal() {
    _sound.play(
      _lost
          ? Sfx.boom
          : _won
          ? Sfx.win
          : Sfx.reveal,
    );
    if (_lost || _won) _stopTimer();
    setState(() {});
    _syncGameplay();
    if (_won) {
      _recordBest(_difficulty, _elapsedSeconds);
      if (!widget.platform.allowsResultRegistration) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          offerResultRegistration(
            context,
            gameId: 'tiny-mines',
            metric: 'time',
            value: _elapsedSeconds,
            displayValue: _formatTime(_elapsedSeconds),
          );
        }
      });
    }
  }

  void _toggleFlag(int index) {
    if (!_field.toggleFlag(index)) return;
    _sound.play(Sfx.flag);
    setState(() {});
  }

  void _selectDifficulty(_Difficulty difficulty) {
    if (_difficulty == difficulty) return;
    _difficulty = difficulty;
    _restart();
    _loadBest(difficulty);
  }

  void _useHint() {
    if (_hints == 0) return;
    final candidate = _field.hintCandidate();
    if (candidate == null) return;
    _hints--;
    _hintPenalty += _hintPenaltySeconds;
    _field.reveal(candidate);
    _afterReveal();
  }

  @override
  Widget build(BuildContext context) {
    final wrongFlags = _field.wrongFlags.toSet();
    final status = _lost
        ? 'Mine hit. Try a cleaner sweep.'
        : _won
        ? 'Field cleared in ${_formatTime(_elapsedSeconds)}.'
        : 'Tap to reveal. Long press or right-click to flag. Tap a number to clear around it.';
    return Stack(
      children: [
        // Taps are ignored until the first-run check has answered, so the
        // tutorial cannot open on top of a half-started game.
        AbsorbPointer(
          absorbing: !_tutorialChecked,
          // Keep keyboard focus (Tab, Enter) out of the game under the card.
          child: ExcludeFocus(
            excluding: _tutorialOpen || !_tutorialChecked,
            child: _buildGame(context, wrongFlags, status),
          ),
        ),
        if (_tutorialOpen)
          Positioned.fill(
            child: HowToPlayOverlay(
              steps: _tutorialSteps,
              onClose: _closeTutorial,
            ),
          ),
      ],
    );
  }

  Widget _buildGame(BuildContext context, Set<int> wrongFlags, String status) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: [
                  _Header(
                    flags: _field.flags,
                    hints: _hints,
                    seconds: _elapsedSeconds,
                    moves: _moves,
                    best: _bests[_difficulty],
                    mines: _difficulty.mines,
                    onRestart: _restart,
                    onHelp: _openTutorial,
                    soundMuted: _sound.userMuted,
                    onToggleSound: _sound.toggle,
                    onHint: _field.armed && !_lost && !_won && _hints > 0
                        ? _useHint
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _DifficultyPicker(
                    difficulty: _difficulty,
                    onChanged: _selectDifficulty,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boardSize = math.min(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        return Center(
                          child: SizedBox.square(
                            dimension: boardSize,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _field.cells.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: _difficulty.size,
                                    crossAxisSpacing: _difficulty.gap,
                                    mainAxisSpacing: _difficulty.gap,
                                  ),
                              itemBuilder: (context, index) {
                                return _MineTile(
                                  cell: _field.cells[index],
                                  gameOver: _lost || _won,
                                  wrongFlag: wrongFlags.contains(index),
                                  onTap: () => _tapCell(index),
                                  onFlag: () => _toggleFlag(index),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD1D9E0),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_lost || _won) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _restart,
                      icon: const Icon(Icons.refresh),
                      label: const Text('New Field'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Difficulty {
  easy('Easy', 6, 5, 3),
  normal('Normal', 9, 12, 3),
  hard('Hard', 12, 26, 4);

  const _Difficulty(this.label, this.size, this.mines, this.hints);

  final String label;
  final int size;
  final int mines;
  final int hints;

  double get gap => size > 10 ? 3 : 4;
}

class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.difficulty, required this.onChanged});

  final _Difficulty difficulty;
  final ValueChanged<_Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_Difficulty>(
      segments: [
        for (final option in _Difficulty.values)
          ButtonSegment<_Difficulty>(
            value: option,
            label: Text('${option.label} ${option.size}x${option.size}'),
          ),
      ],
      selected: {difficulty},
      onSelectionChanged: (selected) => onChanged(selected.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF34413D);
          }
          return const Color(0xFF181C1F);
        }),
        foregroundColor: WidgetStateProperty.all(const Color(0xFFE4ECE8)),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.flags,
    required this.hints,
    required this.seconds,
    required this.moves,
    required this.best,
    required this.mines,
    required this.onRestart,
    required this.onHelp,
    required this.soundMuted,
    required this.onToggleSound,
    required this.onHint,
  });

  final int flags;
  final int hints;
  final int seconds;
  final int moves;
  final int? best;
  final int mines;
  final VoidCallback onRestart;
  final VoidCallback onHelp;
  final bool soundMuted;
  final VoidCallback onToggleSound;
  final VoidCallback? onHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tiny Mines',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              onPressed: onHelp,
              tooltip: 'How to play',
              icon: const Icon(Icons.help_outline),
            ),
            IconButton(
              onPressed: onToggleSound,
              tooltip: soundMuted ? 'Sound off' : 'Sound on',
              icon: Icon(
                soundMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              ),
            ),
            IconButton(
              onPressed: onHint,
              tooltip: 'Reveal one safe tile (+${_hintPenaltySeconds}s)',
              icon: Badge(
                label: Text('$hints'),
                isLabelVisible: hints > 0,
                child: const Icon(Icons.lightbulb),
              ),
            ),
            IconButton(
              onPressed: onRestart,
              tooltip: 'Restart',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _Metric(label: 'Mines', value: '$mines'),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _Metric(label: 'Flags', value: '$flags'),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _Metric(label: 'Time', value: _formatTime(seconds)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _Metric(label: 'Moves', value: '$moves'),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _Metric(
                label: 'Best',
                value: best == null ? '--' : _formatTime(best!),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _formatTime(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  return '$minutes:${remaining.toString().padLeft(2, '0')}';
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1B2023),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF95A2AF)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MineTile extends StatelessWidget {
  const _MineTile({
    required this.cell,
    required this.gameOver,
    required this.wrongFlag,
    required this.onTap,
    required this.onFlag,
  });

  final MineCell cell;
  final bool gameOver;
  final bool wrongFlag;
  final VoidCallback onTap;
  final VoidCallback onFlag;

  @override
  Widget build(BuildContext context) {
    final content = cell.revealed
        ? cell.mine
              ? Icons.close
              : null
        : cell.flagged
        ? Icons.flag
        : null;
    final interactive = !cell.revealed || cell.nearby > 0;
    return Material(
      color: wrongFlag
          ? const Color(0xFF4A2A2C)
          : cell.revealed
          ? const Color(0xFF252B2E)
          : const Color(0xFF65756F),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        mouseCursor: interactive && !gameOver
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        hoverColor: const Color(0x33FFFFFF),
        onTap: onTap,
        onLongPress: onFlag,
        onSecondaryTap: onFlag,
        child: LayoutBuilder(
          builder: (context, box) {
            final side = math.min(box.maxWidth, box.maxHeight);
            return Center(
              child: wrongFlag
                  ? Semantics(
                      label: 'Wrong flag',
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.flag,
                            color: const Color(0xFF95A2AF),
                            size: side * 0.55,
                          ),
                          Icon(
                            Icons.close,
                            color: const Color(0xFFE5484D),
                            size: side * 0.8,
                          ),
                        ],
                      ),
                    )
                  : content != null
                  ? Container(
                      width: side * 0.68,
                      height: side * 0.68,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5484D),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        content,
                        color: const Color(0xFFFFFFFF),
                        size: side * 0.45,
                      ),
                    )
                  : Text(
                      cell.revealed && cell.nearby > 0 ? '${cell.nearby}' : '',
                      style: TextStyle(
                        color: _numberColor(cell.nearby),
                        fontSize: side * 0.55,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  Color _numberColor(int nearby) {
    return switch (nearby) {
      1 => const Color(0xFF7DD3FC),
      2 => const Color(0xFFA7F3D0),
      3 => const Color(0xFFFDE68A),
      4 => const Color(0xFFFCA5A5),
      5 => const Color(0xFFF0ABFC),
      6 => const Color(0xFF5EEAD4),
      _ => Colors.white,
    };
  }
}
