import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'how_to_play.dart';
import 'mine_field.dart';
import 'platform/game_platform.dart';
import 'result_registration.dart';
import 'src/art/garden_palette.dart';
import 'src/art/garden_scenery.dart';
import 'src/art/garden_tile_art.dart';
import 'src/audio/sound_fx.dart';
import 'src/game/difficulty.dart';
import 'src/meta/daily_challenge.dart';
import 'src/meta/garden_progress.dart';
import 'src/meta/garden_progress_store.dart';
import 'src/meta/garden_theme.dart';
import 'src/ui/board_fx.dart';
import 'src/ui/garden_board.dart';
import 'src/ui/garden_cards.dart';
import 'src/ui/garden_ui.dart';
import 'src/ui/run_summary_overlay.dart';

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
        brightness: Brightness.light,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: GardenPalette.spring.skyBottom,
        colorScheme: ColorScheme.fromSeed(
          seedColor: GardenPalette.spring.accent,
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
    'Dig up every safe patch without waking a mole. A pebble counts the moles around it.',
    art: TileLook.soil,
    nearby: 2,
  ),
  TutorialStep(
    Icons.flag,
    'Tap or click to dig. Long press or right-click to plant a flag on a mole.',
    art: TileLook.flagged,
  ),
  TutorialStep(
    Icons.lightbulb,
    'Tap a pebble with all its flags placed to dig the rest. Hints cost +${_hintPenaltySeconds}s.',
  ),
];

class TinyMinesScreen extends StatefulWidget {
  const TinyMinesScreen({
    super.key,
    this.random,
    this.progressStore = const GardenProgressStore(),
    this.tutorialStore = const TutorialStore(),
    this.platform = const NoopGamePlatform(),
    this.stopwatch,
    this.soundFx,
    this.now,
  });

  /// Sound effects, music and mute switch; defaults to the real player.
  final SoundFx? soundFx;

  /// Clock for the solve time; tests can inject a controllable one.
  final Stopwatch? stopwatch;

  /// Portal hooks (gameplay events, leaderboard policy); no-op by default.
  final GamePlatform platform;

  /// Mine placement source; tests pass a seeded generator.
  final math.Random? random;

  /// Saved progress (best times, XP, theme, daily); tests use a memory one.
  final GardenProgressStore progressStore;

  /// First-run tutorial flag storage; tests can substitute a fake.
  final TutorialStore tutorialStore;

  /// Wall clock for the daily board; tests pin a date.
  final DateTime Function()? now;

  @override
  State<TinyMinesScreen> createState() => _TinyMinesScreenState();
}

class _TinyMinesScreenState extends State<TinyMinesScreen> {
  Difficulty _difficulty = Difficulty.easy;
  late MineField _field;
  int _moves = 0;
  // Elapsed time is measured by a stopwatch (paused while an overlay is
  // open) so brief pauses never discard partial seconds; the periodic timer
  // only repaints the clock.
  late final Stopwatch _clock = widget.stopwatch ?? Stopwatch();
  int _hintPenalty = 0;
  int get _elapsedSeconds => _clock.elapsedMilliseconds ~/ 1000 + _hintPenalty;
  int _hints = 3;
  Timer? _timer;
  bool _tutorialOpen = false;
  int _tutorialSession = 0;
  // Gameplay events wait until the first-run tutorial check has answered.
  bool _tutorialChecked = false;
  bool _gameplayActive = false;
  late final SoundFx _sound =
      widget.soundFx ?? SoundFx(platform: widget.platform);
  late final AppLifecycleListener _lifecycle;
  final BoardFx _fx = BoardFx();

  /// The player made a move on this board (the clock runs from then).
  bool _runStarted = false;

  /// Daily board in play: its day key; null for a regular board.
  String? _dailyDay;

  /// The mole that ended the run, drawn startled.
  int? _hitIndex;

  /// A board tap made while the tutorial check was pending:
  /// (cell, isFlag). Applied once the check answers "seen".
  (int, bool)? _pendingTap;

  GardenProgress _progress = const GardenProgress.initial();
  bool _progressLoaded = false;
  // Runs finished (or themes picked) before the stored progress loaded; they
  // are merged into it once it arrives so nothing is overwritten.
  final List<RunResult> _pendingRuns = <RunResult>[];
  bool _themeTouched = false;

  RunReport? _report;
  bool _summaryOpen = false;
  bool _gardenOpen = false;

  bool get _lost => _field.lost;
  bool get _won => _field.won;
  bool get _over => _lost || _won;
  GardenPalette get _palette => GardenPalette.of(_progress.selectedTheme);
  DateTime get _today => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _sound.addListener(_onSoundChanged);
    if (widget.soundFx == null) _sound.load();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) => _sound.setAppVisible(
        state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive,
      ),
    );
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    widget.platform.setAudioMuteListener(_sound.refreshMute);
    _sound.startMusic();
    _restart();
    unawaited(_loadProgress());
    _maybeShowTutorial();
  }

  Future<void> _loadProgress() async {
    GardenProgress loaded;
    try {
      loaded = await widget.progressStore.load();
    } catch (_) {
      loaded = const GardenProgress.initial();
    }
    if (!mounted) return;
    final dirty = _pendingRuns.isNotEmpty || _themeTouched;
    var merged = loaded;
    for (final run in _pendingRuns) {
      merged = merged.applyRun(run).progress;
    }
    if (_themeTouched) merged = merged.withTheme(_progress.selectedTheme);
    _pendingRuns.clear();
    setState(() {
      _progress = merged;
      _progressLoaded = true;
    });
    if (dirty) unawaited(_saveProgress());
  }

  Future<void> _saveProgress() async {
    try {
      await widget.progressStore.save(_progress);
    } catch (_) {}
  }

  bool _onHardwareKey(KeyEvent event) {
    _sound.onUserInput();
    return false;
  }

  Future<void> _maybeShowTutorial() async {
    final session = _tutorialSession;
    var seen = false;
    try {
      seen = await widget.tutorialStore.hasSeen();
    } catch (_) {}
    if (!mounted) return;
    // Rebuild so the control gate in build() lifts even if nothing else does.
    setState(() => _tutorialChecked = true);
    // Ignore a stale answer if the player already opened it via "?".
    if (seen || session != _tutorialSession) {
      _syncGameplay();
      _applyPendingTap();
      return;
    }
    _pendingTap = null;
    _openTutorial();
  }

  /// A returning player may tap the board before the first-run check has
  /// answered; that tap used to be dropped silently ("first click ignored").
  void _applyPendingTap() {
    final pending = _pendingTap;
    _pendingTap = null;
    if (pending == null || _tutorialOpen) return;
    final (index, flag) = pending;
    if (flag) {
      _toggleFlag(index);
    } else {
      _tapCell(index);
    }
  }

  bool get _overlayOpen => _tutorialOpen || _gardenOpen;

  /// Reports gameplay start/stop to the platform exactly on transitions:
  /// running only after the tutorial check, while no overlay is open and the
  /// field is not finished.
  void _syncGameplay() {
    final wantActive = _tutorialChecked && !_overlayOpen && !_over;
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
    _resumeClock();
    widget.tutorialStore.markSeen();
  }

  void _openGarden() {
    _stopTimer();
    setState(() => _gardenOpen = true);
    _syncGameplay();
  }

  void _closeGarden() {
    if (!_gardenOpen) return;
    setState(() => _gardenOpen = false);
    _syncGameplay();
    _resumeClock();
  }

  void _resumeClock() {
    if (_runStarted && !_over && !_overlayOpen) _startTimer();
  }

  void _onSoundChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    widget.platform.setAudioMuteListener(null);
    _lifecycle.dispose();
    _sound.removeListener(_onSoundChanged);
    _sound.stopMusic();
    if (widget.soundFx == null) _sound.dispose();
    _timer?.cancel();
    _fx.dispose();
    super.dispose();
  }

  void _resetRunState() {
    _stopTimer();
    _clock.reset();
    _hintPenalty = 0;
    _moves = 0;
    _runStarted = false;
    _hitIndex = null;
    _report = null;
    _summaryOpen = false;
    _fx.clear();
  }

  /// New regular board at the current difficulty (leaves the daily board).
  void _restart() {
    _resetRunState();
    _dailyDay = null;
    _field = MineField(
      size: _difficulty.size,
      mineCount: _difficulty.mines,
      random: widget.random,
    );
    _hints = _difficulty.hints;
    setState(() {});
    _syncGameplay();
  }

  void _startDaily() {
    final today = _today;
    if (_progress.dailyResult(today) != null) return;
    _resetRunState();
    _gardenOpen = false;
    final (field, start) = DailyChallenge.build(today);
    _field = field;
    _dailyDay = DailyChallenge.dayKey(today);
    _hints = DailyChallenge.difficulty.hints;
    _fx.reveal(
      _wave(start, [
        for (var i = 0; i < field.cells.length; i++)
          if (field.cells[i].revealed) i,
      ]),
    );
    setState(() {});
    _syncGameplay();
  }

  void _startTimer() {
    _clock.start();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _over) return;
      setState(() {});
    });
  }

  void _stopTimer() {
    _clock.stop();
    _timer?.cancel();
    _timer = null;
  }

  Difficulty get _boardDifficulty =>
      _dailyDay != null ? DailyChallenge.difficulty : _difficulty;

  List<bool> _revealedSnapshot() => [
    for (final cell in _field.cells) cell.revealed,
  ];

  int _distance(int a, int b) {
    final size = _field.size;
    return math.max((a ~/ size - b ~/ size).abs(), (a % size - b % size).abs());
  }

  /// Cells with delays rippling out from [origin].
  List<TimedCell> _wave(int origin, Iterable<int> cells, {int stepMs = 34}) {
    final list = cells.toList();
    if (list.isEmpty) return const [];
    final far = list.map((c) => _distance(origin, c)).reduce(math.max);
    final step = far == 0 ? 0 : math.min(stepMs, 620 ~/ far);
    return [
      for (final c in list) (cell: c, delayMs: _distance(origin, c) * step),
    ];
  }

  void _tapCell(int index) {
    if (!_tutorialChecked) {
      _pendingTap = (index, false);
      return;
    }
    if (_over) return;
    final before = _revealedSnapshot();
    final outcome = _field.cells[index].revealed
        ? _field.chord(index)
        : _field.reveal(index);
    if (outcome == RevealOutcome.none) return;
    if (!_runStarted) {
      _runStarted = true;
      _startTimer();
    }
    _moves++;
    _afterReveal(index, before);
  }

  void _afterReveal(int origin, List<bool> before) {
    _sound.play(
      _lost
          ? Sfx.boom
          : _won
          ? Sfx.win
          : Sfx.reveal,
    );
    if (_over) _stopTimer();
    final dug = [
      for (var i = 0; i < _field.cells.length; i++)
        if (_field.cells[i].revealed && !before[i] && !_field.cells[i].mine) i,
    ];
    if (_lost) {
      _hitIndex = _findHit(origin);
      final hit = _hitIndex ?? origin;
      _fx.reveal(_wave(origin, dug));
      _fx.blast(hit, [
        for (var i = 0; i < _field.cells.length; i++)
          if (_field.cells[i].mine && i != hit && !_field.cells[i].flagged)
            (cell: i, delayMs: 260 + math.min(1100, _distance(hit, i) * 90)),
      ]);
    } else {
      _fx.reveal(_wave(origin, dug));
      if (_won) {
        _fx.bloom([
          for (var i = 0; i < _field.cells.length; i++)
            if (_field.cells[i].mine)
              (
                cell: i,
                delayMs: 200 + math.min(900, _distance(origin, i) * 70),
              ),
        ]);
      }
    }
    setState(() {});
    _syncGameplay();
    if (_over) _finishRun();
  }

  /// The mole that was dug: the tapped cell, or for a chord the unflagged
  /// mine around it.
  int? _findHit(int origin) {
    if (_field.cells[origin].mine) return origin;
    for (final n in _field.neighbors(origin)) {
      if (_field.cells[n].mine && !_field.cells[n].flagged) return n;
    }
    return null;
  }

  void _finishRun() {
    final won = _won;
    final seconds = _elapsedSeconds;
    final safe = _field.cells.where((c) => !c.mine).length;
    final dug = _field.cells.where((c) => !c.mine && c.revealed).length;
    final run = RunResult(
      difficulty: _boardDifficulty,
      won: won,
      seconds: seconds,
      revealedFraction: safe == 0 ? 1 : dug / safe,
      dailyDay: _dailyDay,
    );
    final outcome = _progress.applyRun(run);
    _progress = outcome.progress;
    if (_progressLoaded) {
      unawaited(_saveProgress());
    } else {
      // Saving now could overwrite the stored value; merge after loading.
      _pendingRuns.add(run);
    }
    setState(() {
      _report = RunReport(
        won: won,
        difficulty: _boardDifficulty,
        seconds: seconds,
        daily: _dailyDay != null,
        outcome: outcome,
      );
      _summaryOpen = true;
    });
    if (!won ||
        _dailyDay != null ||
        !widget.platform.allowsResultRegistration) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        offerResultRegistration(
          context,
          gameId: 'tiny-mines',
          metric: 'time',
          value: seconds,
          displayValue: formatTime(seconds),
        );
      }
    });
  }

  void _onSummaryShown() {
    final outcome = _report?.outcome;
    if (outcome == null) return;
    if (outcome.leveledUp) {
      _sound.play(Sfx.levelUp);
    } else if (outcome.isNewBest) {
      _sound.play(Sfx.newBest);
    } else if (outcome.dailyRecorded) {
      _sound.play(Sfx.daily);
    }
  }

  void _toggleFlag(int index) {
    if (!_tutorialChecked) {
      _pendingTap = (index, true);
      return;
    }
    if (!_field.toggleFlag(index)) return;
    _sound.play(Sfx.flag);
    _fx.flag(index, planted: _field.cells[index].flagged);
    setState(() {});
  }

  void _selectDifficulty(Difficulty difficulty) {
    if (_difficulty == difficulty && _dailyDay == null) return;
    _difficulty = difficulty;
    _restart();
  }

  void _selectTheme(GardenTheme theme) {
    final next = _progress.withTheme(theme);
    if (identical(next, _progress)) return;
    setState(() => _progress = next);
    if (_progressLoaded) {
      unawaited(_saveProgress());
    } else {
      _themeTouched = true;
    }
  }

  void _useHint() {
    if (_hints == 0) return;
    final candidate = _field.hintCandidate();
    if (candidate == null) return;
    _hints--;
    _hintPenalty += _hintPenaltySeconds;
    if (!_runStarted) {
      _runStarted = true;
      _startTimer();
    }
    final before = _revealedSnapshot();
    _field.reveal(candidate);
    _fx.sparkle(candidate);
    _afterReveal(candidate, before);
  }

  void _playNext() {
    final next = _report?.difficulty.next;
    if (next == null) return;
    _difficulty = next;
    _restart();
  }

  void _closeSummary() => setState(() => _summaryOpen = false);

  String get _status {
    if (_lost) return 'You dug up a mole! Try a cleaner dig.';
    if (_won) return 'Field cleared in ${formatTime(_elapsedSeconds)}.';
    if (_dailyDay != null) {
      return 'Daily garden for ${formatDay(_today)}: one try, same board for everyone.';
    }
    return 'Tap to dig. Long press or right-click to flag. Tap a pebble to clear around it.';
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final report = _report;
    return Stack(
      children: [
        // Keep keyboard focus (Tab, Enter) out of the game under a card.
        ExcludeFocus(
          excluding: _overlayOpen || _summaryOpen || !_tutorialChecked,
          child: _buildGame(context, palette),
        ),
        if (report != null && _summaryOpen)
          Positioned.fill(
            child: RunSummaryOverlay(
              key: ValueKey(report),
              report: report,
              palette: palette,
              delay: Duration(milliseconds: report.won ? 950 : 800),
              onPlayAgain: _restart,
              onClose: _closeSummary,
              onShown: _onSummaryShown,
              onNext:
                  report.won && !report.daily && report.difficulty.next != null
                  ? _playNext
                  : null,
            ),
          ),
        if (_gardenOpen)
          Positioned.fill(
            child: GardenOverlay(
              palette: palette,
              progress: _progress,
              today: _today,
              dailyPlaying: _dailyDay != null && !_over,
              onSelectTheme: _selectTheme,
              onPlayDaily: _startDaily,
              onClose: _closeGarden,
            ),
          ),
        if (_tutorialOpen)
          Positioned.fill(
            child: HowToPlayOverlay(
              steps: _tutorialSteps,
              palette: palette,
              onClose: _closeTutorial,
            ),
          ),
      ],
    );
  }

  /// Controls are ignored until the first-run check has answered, so the
  /// tutorial cannot open on top of a half-started game. (The board keeps
  /// its own gate: it remembers a tap instead of dropping it.)
  Widget _gate(Widget child) =>
      AbsorbPointer(absorbing: !_tutorialChecked, child: child);

  Widget _buildGame(BuildContext context, GardenPalette palette) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: palette.skyBottom,
      body: Listener(
        onPointerDown: (_) => _sound.onUserInput(),
        child: Stack(
          children: [
            Positioned.fill(child: GardenScenery(palette: palette)),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, box) {
                  final wide =
                      box.maxWidth >= 760 &&
                      box.maxWidth / box.maxHeight >= 1.25;
                  return wide
                      ? _wideLayout(palette, box)
                      : _narrowLayout(palette);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(GardenPalette palette, {double size = 28}) {
    // One line on narrow phones: scale the title down instead of wrapping.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        'Tiny Mines',
        maxLines: 1,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          color: palette.isNight
              ? const Color(0xFFFFFFFF)
              : palette.textPrimary,
          shadows: [
            Shadow(
              color: palette.isNight
                  ? const Color(0x99000000)
                  : const Color(0xB3FFFFFF),
              offset: const Offset(0, 2),
              blurRadius: 0,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _toolButtons(GardenPalette palette) => [
    GardenIconButton(
      palette: palette,
      icon: Icons.help_outline,
      tooltip: 'How to play',
      onPressed: _openTutorial,
    ),
    GardenIconButton(
      palette: palette,
      icon: _sound.userMuted
          ? Icons.volume_off_rounded
          : Icons.volume_up_rounded,
      tooltip: _sound.userMuted ? 'Sound off' : 'Sound on',
      onPressed: _sound.toggle,
    ),
    GardenIconButton(
      palette: palette,
      icon: Icons.lightbulb,
      tooltip: 'Reveal one safe tile (+${_hintPenaltySeconds}s)',
      badge: _hints,
      onPressed: _field.armed && !_over && _hints > 0 ? _useHint : null,
    ),
    GardenIconButton(
      palette: palette,
      icon: Icons.refresh,
      tooltip: 'Restart',
      onPressed: _restart,
    ),
  ];

  String get _bestText {
    if (_dailyDay != null) return '--';
    final best = _progress.bestTime(_difficulty);
    return best == null ? '--' : formatTime(best);
  }

  List<(String, String)> get _stats => [
    ('Mines', '${_boardDifficulty.mines}'),
    ('Flags', '${_field.flags}'),
    ('Time', formatTime(_elapsedSeconds)),
    ('Moves', '$_moves'),
    ('Best', _bestText),
  ];

  Widget _board(GardenPalette palette) {
    return LayoutBuilder(
      builder: (context, box) {
        final dimension = math.min(
          580.0,
          math.min(box.maxWidth, box.maxHeight),
        );
        return Center(
          child: GardenBoard(
            field: _field,
            palette: palette,
            fx: _fx,
            gap: _boardDifficulty.gap,
            hitIndex: _hitIndex,
            dimension: dimension,
            onTap: _tapCell,
            onFlag: _toggleFlag,
          ),
        );
      },
    );
  }

  Widget _statusArea(GardenPalette palette) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _status,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _lost ? palette.danger : palette.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (_over && !_summaryOpen) ...[
          const SizedBox(height: 8),
          GardenButton(
            palette: palette,
            label: 'New Field',
            icon: Icons.refresh,
            height: 44,
            onPressed: _restart,
          ),
        ],
      ],
    );
  }

  Widget _narrowLayout(GardenPalette palette) {
    final tools = _toolButtons(palette);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            children: [
              _gate(
                Row(
                  children: [
                    Expanded(child: _title(palette, size: 26)),
                    for (final button in tools) ...[
                      const SizedBox(width: 6),
                      button,
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _gate(
                GardenPanel(
                  palette: palette,
                  radius: 16,
                  padding: const EdgeInsets.all(5),
                  child: Row(
                    children: [
                      for (final (label, value) in _stats) ...[
                        if (label != 'Mines') const SizedBox(width: 5),
                        Expanded(
                          child: StatTile(
                            palette: palette,
                            label: label,
                            value: value,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _gate(
                DifficultyPicker(
                  palette: palette,
                  selected: _dailyDay == null ? _difficulty : null,
                  onChanged: _selectDifficulty,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _board(palette)),
              const SizedBox(height: 8),
              _statusArea(palette),
              const SizedBox(height: 8),
              _gate(_narrowFooter(palette)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _narrowFooter(GardenPalette palette) {
    final dailyDone = _progress.dailyResult(_today) != null;
    return GardenPanel(
      palette: palette,
      radius: 16,
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      child: Row(
        children: [
          LevelBadge(palette: palette, level: _progress.level, size: 38),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_progress.xpIntoLevel} / ${_progress.xpForNextLevel} XP',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                GardenProgressBar(
                  palette: palette,
                  value: _progress.xpIntoLevel / _progress.xpForNextLevel,
                  height: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: GardenButton(
              palette: palette,
              label: dailyDone ? 'Daily done' : 'Daily',
              icon: dailyDone
                  ? Icons.check_rounded
                  : Icons.calendar_today_rounded,
              height: 40,
              onPressed: dailyDone || _dailyDay != null ? null : _startDaily,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            flex: 2,
            child: GardenButton(
              palette: palette,
              label: 'Garden',
              icon: Icons.local_florist_rounded,
              primary: false,
              height: 40,
              onPressed: _openGarden,
            ),
          ),
        ],
      ),
    );
  }

  /// A side column that scales down instead of overflowing on short screens.
  Widget _sideColumn(double width, List<Widget> children) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.topCenter,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Widget _wideLayout(GardenPalette palette, BoxConstraints box) {
    final side = (box.maxWidth * 0.235).clamp(210.0, 300.0);
    final stats = _stats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _gate(
            _sideColumn(side, [
              GardenPanel(
                palette: palette,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title(palette, size: 30),
                    Text(
                      'A cozy garden dig',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GardenPanel(
                palette: palette,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LevelCard(palette: palette, progress: _progress),
                    const SizedBox(height: 12),
                    PanelCaption('Themes', palette: palette),
                    const SizedBox(height: 6),
                    ThemePicker(
                      palette: palette,
                      progress: _progress,
                      onSelect: _selectTheme,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GardenPanel(
                palette: palette,
                child: DailyCard(
                  palette: palette,
                  progress: _progress,
                  today: _today,
                  playing: _dailyDay != null && !_over,
                  onPlay: _startDaily,
                ),
              ),
            ]),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                _gate(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: DifficultyPicker(
                      palette: palette,
                      selected: _dailyDay == null ? _difficulty : null,
                      onChanged: _selectDifficulty,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: _board(palette)),
                const SizedBox(height: 8),
                _statusArea(palette),
              ],
            ),
          ),
          const SizedBox(width: 18),
          _gate(
            _sideColumn(side, [
              GardenPanel(
                palette: palette,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StatTile(
                      palette: palette,
                      label: stats[2].$1,
                      value: stats[2].$2,
                      large: true,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final i in const [0, 1]) ...[
                          if (i == 1) const SizedBox(width: 8),
                          Expanded(
                            child: StatTile(
                              palette: palette,
                              label: stats[i].$1,
                              value: stats[i].$2,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final i in const [3, 4]) ...[
                          if (i == 4) const SizedBox(width: 8),
                          Expanded(
                            child: StatTile(
                              palette: palette,
                              label: stats[i].$1,
                              value: stats[i].$2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GardenPanel(
                palette: palette,
                padding: const EdgeInsets.all(10),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 4,
                  runSpacing: 8,
                  children: _toolButtons(palette),
                ),
              ),
              const SizedBox(height: 12),
              GardenPanel(
                palette: palette,
                child: RecordsCard(palette: palette, progress: _progress),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
