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
import 'src/audio/sound_fx.dart';
import 'src/game/difficulty.dart';
import 'src/game/garden_run.dart';
import 'src/game/garden_run_checkpoint.dart';
import 'src/game/garden_tools.dart';
import 'src/meta/daily_challenge.dart';
import 'src/meta/garden_plots.dart';
import 'src/meta/garden_progress.dart';
import 'src/meta/garden_progress_store.dart';
import 'src/meta/garden_theme.dart';
import 'src/ui/board_fx.dart';
import 'src/ui/garden_board.dart';
import 'src/ui/garden_cards.dart';
import 'src/ui/garden_ui.dart';
import 'src/ui/onboarding_strip.dart';
import 'src/share/result_copy.dart';
import 'src/ui/run_summary_overlay.dart';
import 'src/ui/tool_picker.dart';

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

/// Screen arrangement for a window size (feature-short-viewport-layout).
enum ScreenLayout {
  /// Side panels left and right of the board (desktop, phone landscape).
  wide,

  /// Board first between two slim columns: landscape windows too narrow for
  /// [wide], such as portal preview frames (620x349, 640x480).
  compact,

  /// One column (portrait and square windows).
  stacked,
}

/// The layout used for a window of [size] (the SafeArea box).
ScreenLayout screenLayoutFor(Size size) {
  if (size.width >= 760 && size.width / size.height >= 1.25) {
    return ScreenLayout.wide;
  }
  return size.width > size.height ? ScreenLayout.compact : ScreenLayout.stacked;
}

/// Stacked windows shorter than this fold the controls into fewer rows.
const double shortStackedHeight = 700;

/// Stacked windows fold when the unfolded board side would be smaller than
/// this share of the available width (feature-board-first-phone-layout).
const double foldBoardShare = 0.9;

/// Wide windows bigger than this lay the wide layout out at this size and
/// scale it up (feature-large-screen-scale).
const Size wideDesignSize = Size(1280, 720);

/// Largest scale of the wide layout.
const double maxWideScale = 1.6;

/// Uniform scale of the wide layout in a window of [size]: 1 up to
/// [wideDesignSize], then growing with the smaller ratio, capped.
double wideScaleFor(Size size) => math
    .min(size.width / wideDesignSize.width, size.height / wideDesignSize.height)
    .clamp(1.0, maxWideScale);

class TinyMinesApp extends StatelessWidget {
  const TinyMinesApp({
    super.key,
    this.platform = const NoopGamePlatform(),
    this.soundFx,
    this.launchIntoRun = true,
  });

  final GamePlatform platform;

  /// Injectable sound effects; tests pass a recording one.
  final SoundFx? soundFx;

  /// See [TinyMinesScreen.launchIntoRun]; on for the shipped game.
  final bool launchIntoRun;

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
      home: TinyMinesScreen(
        platform: platform,
        soundFx: soundFx,
        launchIntoRun: launchIntoRun,
      ),
    );
  }
}

/// Seconds added to the clock for each hint, so hinted clears rank lower.
const int _hintPenaltySeconds = 10;

const List<TutorialStep> _tutorialSteps = [
  TutorialStep(
    Icons.grid_view,
    'Numbers count moles in all 8 neighboring patches. Dig the safe ones; use Flag for danger.',
    neighborExample: true,
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
    this.resultCopier = const ResultCopier(),
    this.gardenTools = true,
    this.toolOfferEvery = GardenTools.offerEvery,
    this.toolRandom,
    this.launchIntoRun = false,
  });

  /// Once progress has loaded, replace the untouched Classic launch board by
  /// the saved Garden Run, or by a first run for a player who never played
  /// one (feature-run-first-launch). Off here so plain board tests keep their
  /// Classic launch; [TinyMinesApp] turns it on.
  final bool launchIntoRun;

  /// Garden Run offers a tool after every [toolOfferEvery]-th cleared stage
  /// (feature-garden-tools);
  /// tests of the plain stage flow turn it off.
  final bool gardenTools;

  /// A tool offer follows every this many cleared stages (feature-garden-tools).
  final int toolOfferEvery;

  /// Draws the tool offers; tests pass a seeded generator.
  final math.Random? toolRandom;

  /// Clipboard access for "Copy result"; tests inject a fake.
  final ResultCopier resultCopier;

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
  int _stageBankedMs = 0;
  int get _stageElapsedMs => _stageBankedMs + _clock.elapsedMilliseconds;
  int get _elapsedSeconds => _stageElapsedMs ~/ 1000 + _hintPenalty;
  int _hints = 3;
  Timer? _timer;
  bool _tutorialOpen = false;
  int _tutorialSession = 0;
  // Gameplay events wait until the first-run tutorial check has answered.
  bool _tutorialChecked = false;

  /// First-run tips above the board (feature-first-run-onboarding); shown
  /// while the tutorial flag is unset and the player has not hidden them.
  bool _onboarding = false;
  bool _onboardingDug = false;
  bool _onboardingFlagged = false;
  bool _gameplayActive = false;

  /// Browser tab visible and focused, and no portal pause (GamePix Player
  /// overlays and ads, feature-gamepix-sdk): both must hold to play.
  bool _appActive = true;
  bool _lifecycleActive = true;
  bool _portalPaused = false;
  bool _breakAdInProgress = false;
  bool _flagMode = false;

  /// Board zoom (feature-mobile-touch-zoom): view only, never saved.
  final TransformationController _zoom = TransformationController();
  final GlobalKey _zoomViewerKey = GlobalKey();
  bool _zoomable = false;
  bool _zoomed = false;

  /// Height the unfolded stacked layout spends around the board, measured
  /// once per state that changes it ([_chromeKey]). It predicts the fold for
  /// any window height, so resizing does not first draw the unfolded layout.
  final Map<String, double> _unfoldedChrome = {};

  /// Last dug or flagged cell; zooming in centres it.
  int? _lastCell;
  String? _boardFeedback;
  Timer? _feedbackTimer;
  late final SoundFx _sound =
      widget.soundFx ?? SoundFx(platform: widget.platform);
  late final AppLifecycleListener _lifecycle;
  final BoardFx _fx = BoardFx();

  /// The player made a move on this board (the clock runs from then).
  bool _runStarted = false;

  /// The Classic board shown at launch is still untouched (no other board,
  /// flag or mode switch), so the launch may swap it for a Garden Run.
  bool _launchBoard = false;

  /// Daily board in play: its day key; null for a regular board.
  String? _dailyDay;
  bool _dailyPractice = false;

  /// The mole that ended the run, drawn startled.
  int? _hitIndex;

  /// Garden Run in play; it stays set after the run ended so the board can
  /// still be viewed. Null on regular and daily boards.
  GardenRunState? _run;
  bool _runFinalized = false;

  /// The player dug at least one patch in this run (earns participation XP).
  bool _runParticipated = false;

  /// Time of the stages already cleared in this run.
  int _runBankedMs = 0;

  /// The stage was just cleared; the next one starts after a short pause.
  bool _stageDone = false;

  /// Tools on offer between stages (feature-garden-tools), or null.
  List<GardenTool>? _toolOffer;
  List<GardenTool> _stageReward = const [];

  /// The cleared stage was a boss that restored a heart.
  bool _healedOnClear = false;

  /// Hearts won back on boss stages in this run (for the copied result).
  int _runHeals = 0;
  Timer? _advanceTimer;

  /// A board tap made while the tutorial check was pending:
  /// (cell, isFlag). Applied once the check answers "seen".
  (int, bool)? _pendingTap;

  GardenProgress _progress = const GardenProgress.initial();
  Future<void> _saveQueue = Future<void>.value();
  bool _progressLoaded = false;
  // Runs finished (or themes picked) before the stored progress loaded; they
  // are merged into it once it arrives so nothing is overwritten.
  final List<RunResult> _pendingRuns = <RunResult>[];
  bool _themeTouched = false;

  RunReport? _report;

  /// Win time to offer to the leaderboard once the summary card is shown.
  int? _offerRegistrationFor;
  bool _summaryOpen = false;
  bool _gardenOpen = false;

  bool get _lost => _field.lost;
  bool get _won => _field.won;
  bool get _over => _lost || _won;

  /// The portal sees a Garden Run as one play session: a cleared stage does
  /// not stop gameplay, only the end of the run does.
  bool get _portalOver => _run != null ? _lost : _over;
  int get _runSeconds => (_runBankedMs + _stageElapsedMs) ~/ 1000;
  int get _hintsLeft => _run?.hints ?? _hints;
  double get _gap => _field.size > 10 ? 3 : 4;
  GardenPalette get _palette => GardenPalette.of(_progress.selectedTheme);
  DateTime get _today => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _sound.addListener(_onSoundChanged);
    if (widget.soundFx == null) _sound.load();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _lifecycleActive =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _appActive = _lifecycleActive;
    _sound.setAppVisible(_appActive);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChanged);
    widget.platform.setPauseListener(_onPortalPause);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    widget.platform.setAudioMuteListener(_sound.refreshMute);
    _sound.startMusic();
    _zoom.addListener(_onZoomChanged);
    _restart();
    _launchBoard = true;
    unawaited(_loadProgress());
    _checkFirstRun();
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
    _launchIntoRun();
  }

  /// feature-run-first-launch: resume the saved Garden Run, or start a first
  /// one, in place of the untouched launch board. Nothing of that board was
  /// recorded, and the portal session continues without a stop/start pair.
  void _launchIntoRun() {
    if (!widget.launchIntoRun || !_launchBoard) return;
    _launchBoard = false;
    if (_run != null || _runStarted || _field.armed || _report != null) return;
    if (_pendingTap != null || _overlayOpen) return;
    if (_progress.runCheckpoint == null && _progress.runsPlayed > 0) return;
    _resumeOrStartGardenRun();
  }

  Future<void> _saveProgress() {
    final progress = _progress;
    final store = widget.progressStore;
    _saveQueue = _saveQueue.then((_) async {
      try {
        await store.save(progress);
      } catch (_) {}
    });
    return _saveQueue;
  }

  bool _onHardwareKey(KeyEvent event) {
    _sound.onUserInput();
    return false;
  }

  /// First launch: no modal card. A first-time player gets the board at once
  /// with a short tip strip above it; the full card stays behind "?".
  Future<void> _checkFirstRun() async {
    final session = _tutorialSession;
    var seen = false;
    try {
      seen = await widget.tutorialStore.hasSeen();
    } catch (_) {}
    if (!mounted) return;
    // Rebuild so the control gate in build() lifts even if nothing else does.
    // If the player already opened the card via "?", closing it ends the
    // first-run guidance instead.
    setState(() {
      _tutorialChecked = true;
      _onboarding = !seen && session == _tutorialSession && !_tutorialOpen;
    });
    _syncGameplay();
    // A run resumed before the check answered starts its clock now.
    _resumeClock();
    _applyPendingTap();
  }

  /// Hides the first-run tips for good (stores the tutorial flag).
  void _endOnboarding() {
    if (!_onboarding) return;
    setState(() => _onboarding = false);
    _markTutorialSeen();
  }

  void _markTutorialSeen() {
    try {
      unawaited(widget.tutorialStore.markSeen().catchError((Object _) {}));
    } catch (_) {}
  }

  OnboardingStep get _onboardingStep {
    if (_onboardingFlagged) return OnboardingStep.chord;
    // Sticky: a new board does not bring back the first tip.
    return _onboardingDug || _runStarted || _field.armed
        ? OnboardingStep.numbers
        : OnboardingStep.start;
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

  bool get _overlayOpen => _tutorialOpen || _gardenOpen || _toolOffer != null;

  /// Reports gameplay start/stop to the platform exactly on transitions:
  /// running only after the tutorial check, while no overlay is open and the
  /// field is not finished.
  void _syncGameplay() {
    final wantActive =
        _appActive && _tutorialChecked && !_overlayOpen && !_portalOver;
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
    setState(() {
      _tutorialOpen = false;
      _onboarding = false;
    });
    _syncGameplay();
    _resumeClock();
    _markTutorialSeen();
    _advanceStage();
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
    _advanceStage();
  }

  void _resumeClock() {
    if (_appActive &&
        _tutorialChecked &&
        _runStarted &&
        !_over &&
        !_overlayOpen) {
      _startTimer();
    }
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    _lifecycleActive = state == AppLifecycleState.resumed;
    _applyActive();
  }

  void _onPortalPause(bool paused) {
    if (!mounted) return;
    _portalPaused = paused;
    _applyActive();
  }

  /// Stops the clock and input while the tab is hidden or the portal paused
  /// the game, and restarts the clock once both allow play again.
  void _applyActive() {
    final active = _lifecycleActive && !_portalPaused;
    if (_appActive == active) return;
    setState(() => _appActive = active);
    _sound.setAppVisible(active);
    if (active) {
      _resumeClock();
    } else {
      _stopTimer();
      _checkpointRun();
    }
    _syncGameplay();
  }

  void _onSoundChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    widget.platform.setAudioMuteListener(null);
    widget.platform.setPauseListener(null);
    _lifecycle.dispose();
    _sound.removeListener(_onSoundChanged);
    _sound.stopMusic();
    if (widget.soundFx == null) _sound.dispose();
    _timer?.cancel();
    _feedbackTimer?.cancel();
    _advanceTimer?.cancel();
    _fx.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _resetRunState() {
    _launchBoard = false;
    _stopTimer();
    _clock.reset();
    _stageBankedMs = 0;
    _hintPenalty = 0;
    _moves = 0;
    _flagMode = false;
    _clearFeedback();
    _runStarted = false;
    _hitIndex = null;
    _stageDone = false;
    _toolOffer = null;
    _stageReward = const [];
    _advanceTimer?.cancel();
    _advanceTimer = null;
    _report = null;
    _offerRegistrationFor = null;
    _summaryOpen = false;
    _fx.clear();
    _lastCell = null;
    _resetZoom();
  }

  void _onZoomChanged() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed && mounted) setState(() => _zoomed = zoomed);
  }

  void _resetZoom() {
    _zoomed = false;
    if (_zoom.value.getMaxScaleOnAxis() != 1 ||
        _zoom.value.getTranslation().length2 != 0) {
      _zoom.value = Matrix4.identity();
    }
  }

  /// Zoom in to about 44 px cells around the last dug or flagged patch (the
  /// board centre before the first move), or back out to 1x.
  void _toggleZoom() {
    if (_zoomed) {
      _resetZoom();
      setState(() {});
      return;
    }
    final size = _zoomViewerKey.currentContext?.size;
    if (size == null || size.isEmpty) return;
    final n = _field.size;
    final cell = boardCellSide(size.width, n, _gap);
    final scale = (44 / cell).clamp(1.6, maxBoardZoom);
    final last = _lastCell;
    final focus = last == null
        ? size.center(Offset.zero)
        : Offset(
            (last % n) * (cell + _gap) + cell / 2,
            (last ~/ n) * (cell + _gap) + cell / 2,
          );
    _zoom.value = boardZoomMatrix(size, scale, focus);
  }

  /// New regular board at the current difficulty (leaves the daily board).
  void _restart() {
    _leaveRun();
    _resetRunState();
    _dailyDay = null;
    _dailyPractice = false;
    _field = MineField(
      size: _difficulty.size,
      mineCount: _difficulty.mines,
      random: widget.random,
      requireLogicalSolution: _difficulty == Difficulty.easy,
      guessFree: _difficulty.guessFree,
    );
    _hints = _difficulty.hints;
    setState(() {});
    _syncGameplay();
  }

  void _startDaily() {
    if (!_progressLoaded) return;
    final today = _today;
    if (_progress.dailyResult(today) != null) {
      _startDailyPractice(DailyChallenge.dayKey(today));
      return;
    }
    _loadDailyBoard(today, practice: false);
  }

  void _startDailyPractice(String day) {
    final date = DailyChallenge.parseDay(day);
    if (!_progressLoaded || date == null || !_progress.daily.containsKey(day)) {
      return;
    }
    _loadDailyBoard(date, practice: true);
  }

  void _loadDailyBoard(DateTime day, {required bool practice}) {
    _leaveRun();
    _resetRunState();
    _gardenOpen = false;
    final (field, start) = DailyChallenge.build(day);
    _field = field;
    _dailyDay = DailyChallenge.dayKey(day);
    _dailyPractice = practice;
    _hints = DailyChallenge.difficulty.hints;
    final opened = [
      for (var i = 0; i < field.cells.length; i++)
        if (field.cells[i].revealed) i,
    ];
    _fx.reveal(_wave(start, opened), numbers: _numbers(opened));
    setState(() {});
    _syncGameplay();
  }

  /// Starts a fresh Garden Run at stage 1 (ending any run in play).
  void _startGardenRun() {
    if (!_progressLoaded) return;
    _leaveRun();
    _dailyDay = null;
    _dailyPractice = false;
    _run = const GardenRunState();
    _runFinalized = false;
    _runParticipated = false;
    _runHeals = 0;
    _runBankedMs = 0;
    _loadStage();
  }

  void _resumeOrStartGardenRun() {
    final checkpoint = _progress.runCheckpoint;
    if (checkpoint == null) {
      _startGardenRun();
      return;
    }
    _dailyDay = null;
    _dailyPractice = false;
    _run = checkpoint.run;
    _runFinalized = false;
    _runParticipated = true;
    _runHeals = checkpoint.heals;
    _runBankedMs = checkpoint.bankedMs;
    _loadStage(checkpoint: checkpoint);
  }

  void _loadStage({GardenRunCheckpoint? checkpoint}) {
    final run = _run!;
    final config = run.config;
    _resetRunState();
    _field = MineField(
      size: config.size,
      mineCount: config.mines,
      random: widget.random,
      requireLogicalSolution: config.fairStart,
      survivable: true,
    );
    if (checkpoint == null) {
      _fx.banner(_stageBanner(run.stage, run));
      if (_stageBannerPlot(run.stage) != null) _sound.play(Sfx.newBest);
    } else {
      checkpoint.restoreBoard(_field);
      _stageBankedMs = checkpoint.stageMs;
      _moves = checkpoint.moves;
      _flagMode = checkpoint.flagMode;
      _runStarted = _field.armed;
      if (checkpoint.offer.isNotEmpty) {
        _stageReward = checkpoint.offer;
        _toolOffer = _stageReward;
        _stageDone = true;
      }
      _resumeClock();
    }
    setState(() {});
    _syncGameplay();
  }

  void _checkpointRun() {
    final run = _run;
    if (run == null || _runFinalized || !_runParticipated) return;
    final stage = run.config;
    final checkpoint = GardenRunCheckpoint(
      run: run,
      bankedMs: _runBankedMs + (_stageDone ? _stageElapsedMs : 0),
      stageMs: _stageDone ? 0 : _stageElapsedMs,
      heals: _runHeals,
      moves: _stageDone ? 0 : _moves,
      flagMode: !_stageDone && _flagMode,
      board: !_stageDone
          ? _field.encodeGardenBoard()
          : _stageReward.isEmpty
          ? '.' * (stage.size * stage.size)
          : null,
      offer: _stageDone ? _stageReward : const [],
    );
    _progress = _progress.withRunCheckpoint(checkpoint);
    unawaited(_saveProgress());
  }

  /// Stage the run on the table has reached (0 without one). After a clear
  /// the run already points at the next stage, which only counts once it is
  /// loaded; saving and the side panels share this rule
  /// (feature-live-run-status).
  int get _runStageReached {
    final run = _run;
    if (run == null) return 0;
    return _stageDone ? run.stage - 1 : run.stage;
  }

  /// The Run Path plot that reaching [stage] earns for the first time.
  /// Reaching a stage is what counts (feature-garden-collection), so it is
  /// announced as the stage starts; the run's end saves it.
  GardenPlot? _stageBannerPlot(int stage) {
    if (!_progressLoaded) return null;
    for (final plot in PlotSet.runPath.plots) {
      if (plot.requirement == stage && _progress.bestRunStage < stage) {
        return plot;
      }
    }
    return null;
  }

  FxBanner _stageBanner(int stage, GardenRunState run) {
    final config = GardenRun.stage(stage);
    final plot = _stageBannerPlot(stage);
    final size = '${config.size}x${config.size}';
    final tools = _toolsLabel(run);
    if (plot != null) {
      return FxBanner(
        kind: FxBannerKind.plot,
        title: 'New plot: ${plot.label}',
        subtitle: config.boss
            ? 'Boss garden! $size, ${config.mines} moles - clear it to heal'
            : 'Stage $stage reached - $size, ${config.mines} moles$tools',
        plot: plot,
      );
    }
    if (config.boss) {
      return FxBanner(
        kind: FxBannerKind.boss,
        title: 'Boss garden!',
        subtitle: '$size, ${config.mines} moles - clear it to heal$tools',
      );
    }
    return FxBanner(
      kind: FxBannerKind.stage,
      title: 'Stage $stage',
      subtitle: '$size garden, ${config.mines} moles$tools',
    );
  }

  /// " - Clover x1, Can x2" for the tools a run is carrying, else empty.
  String _toolsLabel(GardenRunState run) {
    final parts = [
      if (run.clovers > 0) 'Clover x${run.clovers}',
      if (run.cans > 0) 'Can x${run.cans}',
    ];
    return parts.isEmpty ? '' : ' - ${parts.join(', ')}';
  }

  /// Opens the tool picker after a cleared stage (the next stage starts when
  /// a tool is picked). Without an eligible tool the next stage starts at once.
  void _advanceStage() {
    final run = _run;
    if (run == null || !_stageDone || _toolOffer != null) return;
    // A card is open: the picker waits and opens when the card closes.
    if (_tutorialOpen || _gardenOpen) return;
    _advanceTimer?.cancel();
    _advanceTimer = null;
    final offer = _stageReward;
    if (offer.isEmpty) {
      _startNextStage();
      return;
    }
    setState(() => _toolOffer = offer);
    _syncGameplay();
  }

  void _pickTool(GardenTool tool) {
    final run = _run;
    final offer = _toolOffer;
    if (run == null || offer == null || !offer.contains(tool)) return;
    _run = run.take(tool);
    _toolOffer = null;
    _startNextStage();
    _showFeedback('${tool.label}: ${tool.blurb}.');
  }

  void _startNextStage() {
    _runBankedMs += _stageElapsedMs;
    _loadStage();
    _checkpointRun();
  }

  void _stageCleared() {
    final before = _run!.hearts;
    _run = _run!.clearStage();
    _healedOnClear = _run!.hearts > before;
    if (_healedOnClear) _runHeals++;
    _stageDone = true;
    _stageReward =
        widget.gardenTools &&
            GardenTools.offersAfter(_run!.cleared, every: widget.toolOfferEvery)
        ? GardenTools.offer(_run!, widget.toolRandom ?? math.Random())
        : const [];
    _checkpointRun();
    final cleared = _run!.stage - 1;
    _fx.banner(
      GardenRun.isBoss(cleared)
          ? FxBanner(
              kind: FxBannerKind.bossCleared,
              title: 'Boss garden cleared!',
              subtitle: _healedOnClear ? '+1 heart' : 'Hearts already full',
            )
          : FxBanner(
              kind: FxBannerKind.cleared,
              title: 'Stage $cleared cleared!',
              subtitle: 'Next: stage ${_run!.stage}',
            ),
    );
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 1800), _advanceStage);
  }

  /// Going to a regular or daily board (or restarting) ends the run now.
  void _leaveRun() {
    _toolOffer = null;
    if (_run == null) return;
    _finalizeRun(showSummary: false);
    _run = null;
  }

  /// Ends the run once: XP and records are applied here and nowhere else.
  void _finalizeRun({required bool showSummary}) {
    final run = _run;
    if (run == null || _runFinalized) return;
    _runFinalized = true;
    _toolOffer = null;
    _advanceTimer?.cancel();
    _advanceTimer = null;
    final reached = _runStageReached;
    final outcome = _progress.applyGardenRun(
      GardenRunResult(
        stageReached: reached,
        stagesCleared: run.cleared,
        participated: _runParticipated,
      ),
    );
    if (!identical(_progress, outcome.progress)) {
      _progress = outcome.progress.withRunCheckpoint(null);
      unawaited(_saveProgress());
    }
    if (!showSummary) return;
    setState(() {
      _report = RunReport.garden(
        stageReached: reached,
        stagesCleared: run.cleared,
        seconds: _runSeconds,
        outcome: outcome,
        heartsHealed: _runHeals,
      );
      _summaryOpen = true;
    });
  }

  void _startTimer() {
    if (!_appActive || _overlayOpen || _over || !_runStarted) return;
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

  /// Clues of the dug [cells] that show a number, for the pop-in effect.
  Map<int, int> _numbers(Iterable<int> cells) => {
    for (final c in cells)
      if (!_field.cells[c].mine && _field.cells[c].nearby > 0)
        c: _field.cells[c].nearby,
  };

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
      _pendingTap = (index, _flagMode);
      return;
    }
    if (!_appActive || _overlayOpen || _summaryOpen || _over) return;
    final cell = _field.cells[index];
    // Flag mode flags hidden patches; a number still chords.
    if (_flagMode && !(cell.revealed && !cell.mine && cell.nearby > 0)) {
      _toggleFlag(index);
      return;
    }
    if (cell.revealed && cell.mine) return;
    if (cell.flagged) {
      _showFeedback(
        'Long-press, right-click or Flag mode removes this marker.',
      );
      return;
    }
    if (cell.revealed && cell.nearby > 0) {
      final placed = _field
          .neighbors(index)
          .where((n) => _field.cells[n].flagged)
          .length;
      if (placed != cell.nearby) {
        _showFeedback(
          'This ${cell.nearby} needs ${cell.nearby} flags ($placed placed).',
        );
        return;
      }
    }
    _clearFeedback();
    final before = _revealedSnapshot();
    final outcome = _field.cells[index].revealed
        ? _field.chord(index)
        : _field.reveal(index);
    if (outcome == RevealOutcome.none) return;
    final firstDig = !_runStarted;
    if (firstDig) {
      _runStarted = true;
      if (_run != null) _runParticipated = true;
      _startTimer();
    }
    _onboardingDug = true;
    _lastCell = index;
    _moves++;
    if (firstDig && (_run?.cans ?? 0) > 0) _useCan();
    _afterReveal(index, before);
  }

  /// Watering can: digs the safest tile and the safe tiles around it, one tile
  /// at a time (no cascade).
  void _useCan() {
    final center = _field.hintCandidate();
    if (center == null || _over) return;
    _run = _run!.useCan();
    for (final cell in [center, ..._field.neighbors(center)]) {
      _field.revealTile(cell);
    }
  }

  void _afterReveal(int origin, List<bool> before) {
    final run = _run;
    final blasts = run == null ? const <int>[] : _field.lastBlasts.toList();
    var cloverSaved = 0;
    if (run != null && blasts.isNotEmpty) {
      cloverSaved = math.min(_run!.clovers, blasts.length);
      _run = _run!
          .useClovers(cloverSaved)
          .loseHearts(blasts.length - cloverSaved);
      if (_run!.isOver) _field.exhaust();
    }
    _sound.play(
      _lost
          ? Sfx.boom
          : _won
          ? Sfx.win
          : blasts.isNotEmpty
          ? Sfx.boom
          : Sfx.reveal,
    );
    if (_over) _stopTimer();
    final dug = [
      for (var i = 0; i < _field.cells.length; i++)
        if (_field.cells[i].revealed && !before[i] && !_field.cells[i].mine) i,
    ];
    if (_lost) {
      _hitIndex = blasts.isNotEmpty ? blasts.last : _findHit(origin);
      final hit = _hitIndex ?? origin;
      _fx.reveal(_wave(origin, dug), numbers: _numbers(dug));
      if (run != null && blasts.isNotEmpty) {
        _fx.heartLoss(hit, left: 0, lost: run.hearts, max: GardenRun.maxHearts);
      }
      _fx.blast(hit, [
        for (var i = 0; i < _field.cells.length; i++)
          if (_field.cells[i].mine && i != hit && !_field.cells[i].flagged)
            (cell: i, delayMs: 260 + math.min(1100, _distance(hit, i) * 90)),
      ]);
    } else {
      _fx.reveal(_wave(origin, dug), numbers: _numbers(dug));
      for (final blast in blasts) {
        _fx.blast(blast, const []);
      }
      if (run != null && blasts.isNotEmpty && run.hearts > _run!.hearts) {
        _fx.heartLoss(
          blasts.last,
          left: _run!.hearts,
          lost: run.hearts - _run!.hearts,
          max: GardenRun.maxHearts,
        );
      }
      if (_won) {
        _fx.bloom([
          for (var i = 0; i < _field.cells.length; i++)
            if (_field.cells[i].mine && !_field.blasted.contains(i))
              (
                cell: i,
                delayMs: 200 + math.min(900, _distance(origin, i) * 70),
              ),
        ]);
      }
    }
    if (run != null && !_lost && _won) _stageCleared();
    if (_over) _endOnboarding();
    // The board's end, a lost heart and their banners are drawn for the
    // whole board: zoom back out so they are seen (feature-mobile-touch-zoom).
    final heartLost = run != null && _run != null && run.hearts > _run!.hearts;
    if (_over || heartLost) _resetZoom();
    setState(() {});
    _syncGameplay();
    if (run != null) {
      if (_lost) {
        _finalizeRun(showSummary: true);
      } else {
        if (!_stageDone) _checkpointRun();
        if (blasts.isNotEmpty) {
          _showFeedback(
            cloverSaved >= blasts.length
                ? 'Lucky clover! The mole cost no heart.'
                : 'A mole! You lost a heart (${_run!.hearts} left).',
          );
        }
      }
    } else if (_over) {
      _finishRun();
    }
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
      practice: _dailyPractice,
    );
    final outcome = _progress.applyRun(run);
    if (!identical(_progress, outcome.progress)) {
      _progress = outcome.progress;
      if (_progressLoaded) {
        unawaited(_saveProgress());
      } else {
        // Saving now could overwrite the stored value; merge after loading.
        _pendingRuns.add(run);
      }
    }
    setState(() {
      _report = RunReport(
        won: won,
        difficulty: _boardDifficulty,
        seconds: seconds,
        daily: _dailyDay != null,
        practice: _dailyPractice,
        dailyDay: _dailyDay,
        outcome: outcome,
      );
      _summaryOpen = true;
    });
    // The leaderboard prompt waits until the card has popped in, so the
    // dialog sits on top of it (and owns the keyboard) instead of under it.
    _offerRegistrationFor =
        won && _dailyDay == null && widget.platform.allowsResultRegistration
        ? seconds
        : null;
  }

  void _onSummaryShown() {
    final seconds = _offerRegistrationFor;
    _offerRegistrationFor = null;
    if (seconds != null && mounted) {
      offerResultRegistration(
        context,
        gameId: 'tiny-mines',
        metric: 'time',
        value: seconds,
        displayValue: formatTime(seconds),
      );
    }
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
    if (!_appActive || _overlayOpen || _summaryOpen) return;
    if (!_field.toggleFlag(index)) return;
    _launchBoard = false;
    _lastCell = index;
    // A light buzz confirms the flag on phones (no-op elsewhere).
    unawaited(HapticFeedback.mediumImpact());
    _clearFeedback();
    if (_field.cells[index].flagged) _onboardingFlagged = true;
    _checkpointRun();
    _sound.play(Sfx.flag);
    _fx.flag(index, planted: _field.cells[index].flagged);
    setState(() {});
  }

  void _selectDifficulty(Difficulty difficulty) {
    if (_difficulty == difficulty && _dailyDay == null && _run == null) return;
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
    if (!_appActive || _overlayOpen || _summaryOpen || _hintsLeft == 0) return;
    _clearFeedback();
    final candidate = _field.hintCandidate();
    if (candidate == null) return;
    final run = _run;
    if (run != null) {
      // Run hints are shared by all stages and carry no time penalty.
      _run = run.useHint();
    } else {
      _hints--;
      _hintPenalty += _hintPenaltySeconds;
    }
    if (!_runStarted) {
      _runStarted = true;
      if (run != null) _runParticipated = true;
      _startTimer();
    }
    final before = _revealedSnapshot();
    _field.reveal(candidate);
    _fx.sparkle(candidate);
    _afterReveal(candidate, before);
  }

  void _playNext() {
    final next = _report?.difficulty?.next;
    if (next == null) return;
    _difficulty = next;
    _restart();
  }

  void _closeSummary() => setState(() => _summaryOpen = false);

  /// Wraps a run summary action that starts a new board: on platforms with
  /// break ads (GamePix, feature-gamepix-sdk) the ad plays first. Elsewhere
  /// the action is returned unchanged.
  VoidCallback? _afterBreakAd(VoidCallback? action) {
    if (action == null || !widget.platform.showsRunBreakAds) return action;
    return () async {
      if (_breakAdInProgress) return;
      _breakAdInProgress = true;
      try {
        await widget.platform.showRunBreakAd();
      } catch (_) {
        // A failed ad never keeps the player from the next board.
      } finally {
        _breakAdInProgress = false;
      }
      if (mounted) action();
    };
  }

  /// The build's link for copied results (adr-share-link-per-flavor).
  String? get _shareLink {
    try {
      return widget.platform.shareLink;
    } catch (_) {
      return null;
    }
  }

  String get _status {
    final run = _run;
    if (run != null) {
      if (_lost) return 'Out of hearts! The run ends at stage ${run.stage}.';
      if (_stageDone) {
        final cleared = run.stage - 1;
        if (!GardenRun.isBoss(cleared)) return 'Stage $cleared cleared!';
        return _healedOnClear
            ? 'Boss garden cleared! +1 heart.'
            : 'Boss garden cleared!';
      }
      if (_boardFeedback != null) return _boardFeedback!;
      final boss = run.config.boss;
      if (!_field.armed) {
        return boss
            ? 'Boss garden! Clear it to win a heart back. Your first dig is safe.'
            : 'Stage ${run.stage}: start anywhere - your first dig is safe.';
      }
      return boss
          ? 'Boss garden! A mole costs a heart; clearing it wins one back.'
          : 'A mole costs a heart. Clear the stage to keep going.';
    }
    if (_lost) return 'You dug up a mole! Try a cleaner dig.';
    if (_won) return 'Field cleared in ${formatTime(_elapsedSeconds)}.';
    if (_boardFeedback != null) return _boardFeedback!;
    if (_dailyDay != null) {
      final date = DailyChallenge.parseDay(_dailyDay!)!;
      return _dailyPractice
          ? 'Practice for ${formatDay(date)} - no XP or records. Your daily result is saved.'
          : 'Daily garden for ${formatDay(date)}: one scored try, same board for everyone.';
    }
    if (!_field.armed) {
      // The tip strip already says it; keep the status line short.
      return _onboarding
          ? 'Tap any patch to dig.'
          : 'Start anywhere - your first dig is safe.';
    }
    return _flagMode
        ? 'Flag mode: tap a hidden patch to mark or remove a flag.'
        : 'Dig mode: tap to dig. Numbers count moles in all 8 neighbors.';
  }

  void _clearFeedback() {
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    _boardFeedback = null;
  }

  void _showFeedback(String message) {
    _clearFeedback();
    setState(() => _boardFeedback = message);
    _feedbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _boardFeedback = null);
    });
  }

  void _setFlagMode(bool flag) {
    if (_flagMode == flag) return;
    _launchBoard = false;
    _clearFeedback();
    setState(() => _flagMode = flag);
    _checkpointRun();
  }

  Widget _modeButton(GardenPalette palette, bool flag, {double height = 40}) {
    return Semantics(
      key: ValueKey(flag ? 'flag-mode' : 'dig-mode'),
      selected: _flagMode == flag,
      child: GardenButton(
        palette: palette,
        label: flag ? 'Flag' : 'Dig',
        icon: flag ? Icons.flag_rounded : Icons.touch_app_rounded,
        primary: _flagMode == flag,
        height: height,
        onPressed: _over ? null : () => _setFlagMode(flag),
      ),
    );
  }

  /// Short landscape screens: Dig/Flag and the difficulty stacked beside
  /// the board, so the board keeps the full column height.
  Widget _controlColumn(GardenPalette palette) {
    // Scales down on very short screens (browser bars, portal frames).
    return SizedBox(
      width: 112,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 112,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _gate(_modeButton(palette, false, height: 46)),
              const SizedBox(height: 8),
              _gate(_modeButton(palette, true, height: 46)),
              if (_zoomable) ...[
                const SizedBox(height: 8),
                _gate(_zoomToggle(palette, size: 46)),
              ],
              const SizedBox(height: 14),
              _gate(
                DifficultyPicker(
                  palette: palette,
                  vertical: true,
                  selected: _dailyDay == null && _run == null
                      ? _difficulty
                      : null,
                  onChanged: _selectDifficulty,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeControls(GardenPalette palette) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Row(
        children: [
          for (final flag in [false, true]) ...[
            if (flag) const SizedBox(width: 8),
            Expanded(child: _modeButton(palette, flag)),
          ],
          if (_zoomable) ...[const SizedBox(width: 8), _zoomToggle(palette)],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final report = _report;
    // Any pointer down (board, cards, overlays) counts as the first user
    // input that lets browsers start the music.
    return Listener(
      onPointerDown: (_) => _sound.onUserInput(),
      child: Stack(
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
                onPlayAgain: _afterBreakAd(
                  report.garden ? _startGardenRun : _restart,
                )!,
                onPractice: _afterBreakAd(
                  report.daily && _dailyDay != null
                      ? () => _startDailyPractice(_dailyDay!)
                      : null,
                ),
                onClose: _closeSummary,
                onShown: _onSummaryShown,
                shareLink: _shareLink,
                now: _today,
                copier: widget.resultCopier,
                onTryGardenRun: _afterBreakAd(
                  !report.garden &&
                          !report.daily &&
                          report.won &&
                          _progressLoaded &&
                          _progress.runsPlayed == 0
                      ? _resumeOrStartGardenRun
                      : null,
                ),
                nextLabel: report.garden ? 'Classic board' : null,
                selectedTheme: _progress.selectedTheme,
                onUseTheme: _selectTheme,
                onNext: _afterBreakAd(
                  report.garden
                      ? _restart
                      : report.won &&
                            !report.daily &&
                            report.difficulty?.next != null
                      ? _playNext
                      : null,
                ),
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
                runStage: _runStageReached,
              ),
            ),
          if (_toolOffer != null && _run != null)
            Positioned.fill(
              child: ToolPickerOverlay(
                palette: palette,
                tools: _toolOffer!,
                stage: _run!.stage - 1,
                onPick: _pickTool,
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
      ),
    );
  }

  /// Controls are ignored until the first-run check has answered, so the
  /// tutorial cannot open on top of a half-started game. (The board keeps
  /// its own gate: it remembers a tap instead of dropping it.)
  Widget _gate(Widget child) =>
      AbsorbPointer(absorbing: !_appActive || !_tutorialChecked, child: child);

  Widget _buildGame(BuildContext context, GardenPalette palette) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: palette.skyBottom,
      body: Stack(
        children: [
          Positioned.fill(child: GardenScenery(palette: palette)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                return switch (screenLayoutFor(box.biggest)) {
                  ScreenLayout.wide => _scaledWideLayout(palette, box),
                  ScreenLayout.compact => _compactLayout(palette),
                  ScreenLayout.stacked => _narrowLayout(palette, box),
                };
              },
            ),
          ),
        ],
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

  List<Widget> _toolButtons(GardenPalette palette, {double size = 44}) => [
    GardenIconButton(
      palette: palette,
      icon: Icons.help_outline,
      tooltip: 'How to play',
      size: size,
      onPressed: _openTutorial,
    ),
    GardenIconButton(
      palette: palette,
      size: size,
      icon: _sound.userMuted
          ? Icons.volume_off_rounded
          : Icons.volume_up_rounded,
      tooltip: _sound.userMuted ? 'Sound off' : 'Sound on',
      onPressed: _sound.toggle,
    ),
    GardenIconButton(
      palette: palette,
      size: size,
      icon: Icons.lightbulb,
      tooltip: _run != null
          ? 'Reveal one safe tile'
          : 'Reveal one safe tile (+${_hintPenaltySeconds}s)',
      badge: _hintsLeft,
      onPressed: _field.armed && !_over && _hintsLeft > 0 ? _useHint : null,
    ),
    GardenIconButton(
      palette: palette,
      size: size,
      icon: Icons.refresh,
      tooltip: _run != null ? 'Restart run' : 'Restart',
      onPressed: _run != null ? _startGardenRun : _restart,
    ),
  ];

  String get _bestText {
    if (_run != null) {
      final stage = _progress.bestRunStage;
      return stage == 0 ? '--' : 'Stage $stage';
    }
    if (_dailyDay != null) return '--';
    final best = _progress.bestTime(_difficulty);
    return best == null ? '--' : formatTime(best);
  }

  List<(String, String)> get _stats => [
    ('Mines', '${_run != null ? _field.mineCount : _boardDifficulty.mines}'),
    ('Flags', '${_field.flags}'),
    ('Time', formatTime(_elapsedSeconds)),
    ('Moves', '$_moves'),
    ('Best', _bestText),
  ];

  /// The board, sized to the box left for it. [onMeasure] gets the box and
  /// returns true to ask for a rebuild of the layout around it (stacked fold).
  Widget _board(
    GardenPalette palette, {
    bool Function(BoxConstraints box)? onMeasure,
  }) {
    return LayoutBuilder(
      builder: (context, box) {
        final run = _run;
        // Garden Run keeps a large hearts row right above the board.
        final rowHeight = run == null ? 0.0 : RunHeartsRow.height;
        final dimension = math.min(
          580.0,
          math.min(box.maxWidth, math.max(0.0, box.maxHeight - rowHeight)),
        );
        if (onMeasure != null && onMeasure(box)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
        // Frame, its border and the bed padding around the grid.
        final inner =
            dimension - 2 * (GardenBoard.frameFor(dimension) + 3 + _gap);
        final zoomable =
            inner > 0 &&
            boardCellSide(inner, _field.size, _gap) < zoomCellThreshold;
        if (zoomable != _zoomable) {
          // The zoom toggle sits outside the board: update it after layout.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || zoomable == _zoomable) return;
            if (!zoomable) _resetZoom();
            setState(() => _zoomable = zoomable);
          });
        }
        final board = GardenBoard(
          field: _field,
          palette: palette,
          fx: _fx,
          gap: _gap,
          hitIndex: _hitIndex,
          flagMode: _flagMode && !_over,
          dimension: dimension,
          onTap: _tapCell,
          onFlag: _toggleFlag,
          zoom: _zoom,
          zoomable: zoomable,
          zoomed: _zoomed,
          viewerKey: _zoomViewerKey,
        );
        if (run == null) return Center(child: board);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RunHeartsRow(palette: palette, hearts: run.hearts),
              board,
            ],
          ),
        );
      },
    );
  }

  Widget _statusArea(GardenPalette palette) {
    const fontSize = 13.0;
    const lineHeight = 1.25;
    // Always two lines tall, so a longer message never resizes the board.
    final twoLines =
        MediaQuery.textScalerOf(context).scale(fontSize) * lineHeight * 2 + 12;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: const ValueKey('status-line'),
          constraints: BoxConstraints(minHeight: twoLines),
          alignment: Alignment.center,
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
              fontSize: fontSize,
              height: lineHeight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (_over && !_summaryOpen) ...[
          const SizedBox(height: 8),
          _endButton(palette),
        ],
      ],
    );
  }

  /// "New Field" / "Next stage" / "New Run" once a board has ended.
  Widget _endButton(GardenPalette palette, {double height = 44}) {
    return GardenButton(
      palette: palette,
      label: _run == null
          ? 'New Field'
          : _stageDone
          ? 'Next stage'
          : 'New Run',
      icon: _stageDone ? Icons.arrow_forward_rounded : Icons.refresh,
      height: height,
      onPressed: _run == null
          ? _restart
          : _stageDone
          ? _advanceStage
          : _startGardenRun,
    );
  }

  /// Stacked layout for portrait and square windows (feature-board-first-
  /// phone-layout). Top: title and tools, stats, the level / Garden Run /
  /// Daily / Garden row and (unfolded) the difficulty picker. Then the board,
  /// and below it, in thumb reach, Dig / Flag / zoom and the status line.
  /// The layout folds (Dig/Flag/zoom icons beside a short-label difficulty
  /// picker, tips in the status line's place) on windows under
  /// [shortStackedHeight] and whenever the unfolded board came out under
  /// [foldBoardShare] of the width.
  Widget _narrowLayout(GardenPalette palette, BoxConstraints box) {
    // The board side the unfolded layout should reach before it folds.
    final target = math.min(box.maxWidth, 560) - 24;
    final key = _chromeKey(box.maxWidth);
    final rowHeight = _run == null ? 0.0 : RunHeartsRow.height;
    bool tooSmall(double chrome) =>
        math.min(target, box.maxHeight - chrome - rowHeight) <
        target * foldBoardShare;
    final chrome = _unfoldedChrome[key];
    final fold =
        box.maxHeight < shortStackedHeight ||
        (chrome != null && tooSmall(chrome));
    final tools = _toolButtons(palette);
    // Folded windows show the tips in the status line's place (feedback and
    // the end of a board still show it), as on short wide screens.
    final tipsForStatus =
        fold && _onboarding && _boardFeedback == null && !_over;
    final gap = fold ? 6.0 : 8.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, fold ? 6 : 8, 12, fold ? 8 : 10),
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
              SizedBox(height: gap),
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
              SizedBox(height: gap),
              _gate(_metaRow(palette, fold: fold)),
              if (!fold) ...[
                SizedBox(height: gap),
                _gate(_difficultyPicker(palette)),
              ],
              SizedBox(height: fold ? 4 : 6),
              if (_onboarding) ...[
                _tipStrip(palette, compact: true),
                const SizedBox(height: 6),
              ],
              Expanded(
                child: _board(
                  palette,
                  // Unfolded: record what the rows around the board cost and
                  // fold if the board came out too small.
                  onMeasure: fold
                      ? null
                      : (board) {
                          final cost = box.maxHeight - board.maxHeight;
                          _unfoldedChrome[key] = cost;
                          return tooSmall(cost);
                        },
                ),
              ),
              SizedBox(height: gap),
              _gate(fold ? _foldedControls(palette) : _modeControls(palette)),
              if (!tipsForStatus) ...[
                SizedBox(height: gap),
                _statusArea(palette),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Folded stacked windows: Dig, Flag (and zoom) as icons beside the
  /// difficulty picker with short names. With the zoom toggle the icons
  /// shrink a little, so the difficulty names stay readable.
  Widget _foldedControls(GardenPalette palette) {
    final icon = _zoomable ? 38.0 : 42.0;
    return Row(
      children: [
        _modeIcon(palette, false, size: icon),
        SizedBox(width: _zoomable ? 4 : 6),
        _modeIcon(palette, true, size: icon),
        if (_zoomable) ...[
          const SizedBox(width: 4),
          _zoomToggle(palette, size: icon),
        ],
        const SizedBox(width: 8),
        // Names only ("Hard"); the size is the semantics label.
        Expanded(child: _difficultyPicker(palette, shortLabels: true)),
      ],
    );
  }

  Widget _difficultyPicker(
    GardenPalette palette, {
    bool vertical = false,
    bool shortLabels = false,
  }) => DifficultyPicker(
    palette: palette,
    vertical: vertical,
    shortLabels: shortLabels,
    selected: _dailyDay == null && _run == null ? _difficulty : null,
    onChanged: _selectDifficulty,
  );

  /// Icon-only Dig/Flag toggle for short windows; the label stays as the
  /// tooltip and semantics label.
  Widget _modeIcon(GardenPalette palette, bool flag, {double size = 42}) {
    return Semantics(
      key: ValueKey(flag ? 'flag-mode' : 'dig-mode'),
      selected: _flagMode == flag,
      child: GardenIconButton(
        palette: palette,
        icon: flag ? Icons.flag_rounded : Icons.touch_app_rounded,
        tooltip: flag ? 'Flag' : 'Dig',
        selected: _flagMode == flag,
        size: size,
        onPressed: _over ? null : () => _setFlagMode(flag),
      ),
    );
  }

  /// Zoom in/out, shown next to Dig/Flag while the board is zoomable.
  Widget _zoomToggle(GardenPalette palette, {double size = 40}) {
    return GardenIconButton(
      key: const ValueKey('zoom-toggle'),
      palette: palette,
      icon: _zoomed ? Icons.zoom_out_rounded : Icons.zoom_in_rounded,
      tooltip: _zoomed ? 'Zoom out' : 'Zoom in',
      selected: _zoomed,
      size: size,
      onPressed: _toggleZoom,
    );
  }

  /// What changes the height of the rows around the stacked board: the tip
  /// strip, the hearts row, the end-of-board button and the width (wrapping).
  String _chromeKey(double width) =>
      '${_onboarding ? 't' : '-'}${_run != null ? 'r' : '-'}'
      '${_over && !_summaryOpen ? 'e' : '-'}${width.round()}';

  bool get _dailyDone => _progress.dailyResult(_today) != null;

  VoidCallback? get _dailyAction =>
      !_progressLoaded || (_dailyDay != null && !_over) ? null : _startDaily;

  /// Stacked windows: level, Garden Run entry (or live status), Daily and
  /// Garden in one row. [fold] picks the two-line run status and short
  /// labels.
  Widget _metaRow(GardenPalette palette, {required bool fold}) {
    final run = _run;
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          if (run == null) ...[
            LevelBadge(palette: palette, level: _progress.level, size: 40),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: run != null
                ? GardenPanel(
                    palette: palette,
                    radius: 25,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    // Unfolded rows have room for the one-line status.
                    child: Center(
                      child: fold
                          ? _compactRunHud(palette, run)
                          : _runHud(palette, run),
                    ),
                  )
                : Center(child: _runEntry(palette, height: 44, long: !fold)),
          ),
          const SizedBox(width: 6),
          GardenIconButton(
            palette: palette,
            icon: _dailyDone
                ? Icons.check_rounded
                : Icons.calendar_today_rounded,
            tooltip: _dailyDone ? 'Practice daily' : 'Daily',
            onPressed: _dailyAction,
          ),
          const SizedBox(width: 6),
          GardenIconButton(
            palette: palette,
            icon: Icons.local_florist_rounded,
            tooltip: 'Garden',
            onPressed: _openGarden,
          ),
        ],
      ),
    );
  }

  /// The Garden Run entry while no run is playing: the call to action until
  /// the first run, then a plain button.
  Widget _runEntry(
    GardenPalette palette, {
    double height = 44,
    bool long = false,
  }) {
    if (_promoteRun) {
      return GardenRunCta(
        palette: palette,
        compact: true,
        onStart: _startGardenRun,
      );
    }
    final best = _progress.bestRunStage;
    return SizedBox(
      width: double.infinity,
      child: GardenButton(
        palette: palette,
        label:
            resumeRunLabel(_progress, withHearts: false) ??
            (best > 0
                ? 'Garden Run - best ${long ? 'stage ' : ''}$best'
                : long
                ? 'Garden Run - ${GardenRun.startHearts} hearts'
                : 'Garden Run'),
        icon: Icons.favorite_rounded,
        height: height,
        onPressed: _progressLoaded ? _resumeOrStartGardenRun : null,
      ),
    );
  }

  /// A column of [width] whose content is laid out at that width and scaled
  /// down (never up) when it is taller than the window.
  Widget _fitColumn(double width, List<Widget> children) {
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

  /// Short landscape windows narrower than the wide layout (portal preview
  /// frames such as 620x349 or 640x480): the board takes the middle and all
  /// of the height; slim columns hold the rest.
  Widget _compactLayout(GardenPalette palette) {
    final run = _run;
    final stats = _stats;
    Widget tile(int i) => Expanded(
      child: StatTile(palette: palette, label: stats[i].$1, value: stats[i].$2),
    );
    const fontSize = 12.0;
    const lineHeight = 1.25;
    final threeLines =
        MediaQuery.textScalerOf(context).scale(fontSize) * lineHeight * 3 + 12;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fitColumn(_compactLeft, [
            Row(
              children: [
                LevelBadge(palette: palette, level: _progress.level, size: 30),
                const SizedBox(width: 6),
                Expanded(child: _title(palette, size: 24)),
              ],
            ),
            const SizedBox(height: 6),
            _gate(
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _toolButtons(palette, size: 38),
              ),
            ),
            const SizedBox(height: 8),
            _gate(
              run != null
                  ? GardenPanel(
                      palette: palette,
                      radius: 16,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: _compactRunHud(palette, run),
                    )
                  : _runEntry(palette, height: 40),
            ),
            const SizedBox(height: 8),
            GardenPanel(
              palette: palette,
              radius: 16,
              padding: const EdgeInsets.all(5),
              child: Column(
                children: [
                  Row(
                    children: [
                      tile(0),
                      const SizedBox(width: 4),
                      tile(1),
                      const SizedBox(width: 4),
                      tile(3),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(children: [tile(2), const SizedBox(width: 4), tile(4)]),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              key: const ValueKey('status-line'),
              constraints: BoxConstraints(minHeight: threeLines),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: palette.panel,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _lost ? palette.danger : palette.textPrimary,
                  fontSize: fontSize,
                  height: lineHeight,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_over && !_summaryOpen) ...[
              const SizedBox(height: 6),
              _endButton(palette, height: 38),
            ],
          ]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                if (_onboarding) ...[
                  _tipStrip(palette, compact: true),
                  const SizedBox(height: 6),
                ],
                Expanded(child: _board(palette)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _gate(
            _fitColumn(_compactRight, [
              // A zoomable board puts Dig, Flag and the zoom toggle in one
              // icon row, so the column does not grow.
              if (_zoomable)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _modeIcon(palette, false, size: 36),
                    _modeIcon(palette, true, size: 36),
                    _zoomToggle(palette, size: 36),
                  ],
                )
              else ...[
                _modeButton(palette, false, height: 42),
                const SizedBox(height: 6),
                _modeButton(palette, true, height: 42),
              ],
              const SizedBox(height: 10),
              _difficultyPicker(palette, vertical: true),
              const SizedBox(height: 10),
              GardenButton(
                palette: palette,
                label: _dailyDone ? 'Practice' : 'Daily',
                icon: _dailyDone
                    ? Icons.check_rounded
                    : Icons.calendar_today_rounded,
                height: 38,
                onPressed: _dailyAction,
              ),
              const SizedBox(height: 6),
              GardenButton(
                palette: palette,
                label: 'Garden',
                icon: Icons.local_florist_rounded,
                primary: false,
                height: 38,
                onPressed: _openGarden,
              ),
            ]),
          ),
        ],
      ),
    );
  }

  /// Garden Run status for slim spaces (compact column, short stacked meta
  /// row): stage (and boss tag) over the run clock. The hearts show in the
  /// large row above the board.
  Widget _compactRunHud(GardenPalette palette, GardenRunState run) {
    final stage = GardenRun.stage(_stageDone ? run.stage - 1 : run.stage);
    final style = TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: 17,
      color: palette.textPrimary,
    );
    return Column(
      key: const ValueKey('compact-run-hud'),
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stage ${stage.stage}', style: style),
              if (stage.boss) ...[
                const SizedBox(width: 8),
                Container(
                  key: const ValueKey('boss-tag'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: palette.flowerCenter,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'BOSS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: Color(0xFF3B2A05),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          'Run ${formatTime(_runSeconds)}',
          style: style.copyWith(fontSize: 14, color: palette.textSecondary),
        ),
      ],
    );
  }

  static const double _compactLeft = 160;
  static const double _compactRight = 118;

  Widget _tipStrip(GardenPalette palette, {required bool compact}) =>
      OnboardingStrip(
        palette: palette,
        step: _onboardingStep,
        compact: compact,
        onClose: _endOnboarding,
      );

  /// Garden Run is promoted until the first run has been played.
  bool get _promoteRun =>
      _progressLoaded &&
      _run == null &&
      _progress.runCheckpoint == null &&
      _progress.runsPlayed == 0;

  Widget _runHud(GardenPalette palette, GardenRunState run) {
    return GardenRunHud(
      palette: palette,
      stage: GardenRun.stage(_stageDone ? run.stage - 1 : run.stage),
      runSeconds: _runSeconds,
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
          // Laid out at least 210 wide (the cards' design width), then
          // scaled into [width] on short landscape screens.
          child: SizedBox(
            width: math.max(width, 210),
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

  /// The wide layout, laid out at the design size and scaled up on large
  /// windows (feature-large-screen-scale).
  Widget _scaledWideLayout(GardenPalette palette, BoxConstraints box) {
    final scale = wideScaleFor(box.biggest);
    // The same widget structure at every scale, so crossing 1280x720 (going
    // fullscreen) does not remount the layout.
    final inner = Size(box.maxWidth / scale, box.maxHeight / scale);
    // Tight outer box: a FittedBox under loose constraints would stay at the
    // child's (unscaled) size.
    return SizedBox(
      key: const ValueKey('wide-scaled'),
      width: box.maxWidth,
      height: box.maxHeight,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox.fromSize(
          size: inner,
          child: _wideLayout(palette, BoxConstraints.tight(inner)),
        ),
      ),
    );
  }

  Widget _wideLayout(GardenPalette palette, BoxConstraints box) {
    final shortWide = box.maxHeight < 520;
    final side = shortWide
        ? (box.maxWidth * 0.2).clamp(160.0, 260.0)
        : (box.maxWidth * 0.235).clamp(210.0, 300.0);
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
              if (_promoteRun)
                GardenRunCta(palette: palette, onStart: _startGardenRun)
              else
                GardenPanel(
                  palette: palette,
                  child: GardenRunCard(
                    palette: palette,
                    progress: _progress,
                    playing: _run != null,
                    runStage: _run == null ? null : _runStageReached,
                    onStart: !_progressLoaded
                        ? null
                        : _run == null
                        ? _resumeOrStartGardenRun
                        : _startGardenRun,
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
                if (!shortWide) ...[
                  _gate(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: DifficultyPicker(
                        palette: palette,
                        selected: _dailyDay == null && _run == null
                            ? _difficulty
                            : null,
                        onChanged: _selectDifficulty,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _gate(_modeControls(palette)),
                  const SizedBox(height: 8),
                ],
                if (_onboarding && !shortWide) ...[
                  _tipStrip(palette, compact: box.maxHeight < 600),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: shortWide
                      ? Row(
                          children: [
                            _controlColumn(palette),
                            const SizedBox(width: 10),
                            Expanded(child: _board(palette)),
                          ],
                        )
                      : _board(palette),
                ),
                const SizedBox(height: 8),
                // Short landscape screens: the tips take the status line's
                // place (feedback still wins) so the board keeps its size.
                if (shortWide &&
                    _onboarding &&
                    _boardFeedback == null &&
                    !_over)
                  _tipStrip(palette, compact: true)
                else
                  _statusArea(palette),
              ],
            ),
          ),
          const SizedBox(width: 18),
          _gate(
            _sideColumn(side, [
              if (_run != null) ...[
                GardenPanel(
                  palette: palette,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: _runHud(palette, _run!),
                ),
                const SizedBox(height: 12),
              ],
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
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: GardenPlotsCard(
                  palette: palette,
                  progress: _progress,
                  runStage: _runStageReached,
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
