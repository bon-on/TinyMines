import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'best_times.dart';
import 'mine_field.dart';
import 'result_registration.dart';

void main() => runApp(const TinyMinesApp());

class TinyMinesApp extends StatelessWidget {
  const TinyMinesApp({super.key});

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
      // The static web shell draws a fixed 48px hub bar over the canvas; keep
      // the game below it so the title row and hint/restart buttons stay hit-testable.
      builder: (context, child) => Padding(
        padding: EdgeInsets.only(top: kIsWeb ? webHubBarHeight : 0),
        child: child,
      ),
      home: const TinyMinesScreen(),
    );
  }
}

/// Height of the hub navigation bar from web/index.html (--games-nav-height).
const double webHubBarHeight = 48;

/// Seconds added to the clock for each hint, so hinted clears rank lower.
const int _hintPenaltySeconds = 10;

class TinyMinesScreen extends StatefulWidget {
  const TinyMinesScreen({
    super.key,
    this.random,
    this.bestTimes = const BestTimes(),
  });

  /// Mine placement source; tests pass a seeded generator.
  final math.Random? random;

  /// Local best-time storage; tests can substitute mock preferences.
  final BestTimes bestTimes;

  @override
  State<TinyMinesScreen> createState() => _TinyMinesScreenState();
}

class _TinyMinesScreenState extends State<TinyMinesScreen> {
  _Difficulty _difficulty = _Difficulty.easy;
  late MineField _field;
  int _moves = 0;
  int _elapsedSeconds = 0;
  int _hints = 3;
  final Map<_Difficulty, int?> _bests = {};
  Timer? _timer;

  bool get _lost => _field.lost;
  bool get _won => _field.won;

  @override
  void initState() {
    super.initState();
    _restart();
    _loadBest(_difficulty);
  }

  @override
  void dispose() {
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
    _timer?.cancel();
    _field = MineField(
      size: _difficulty.size,
      mineCount: _difficulty.mines,
      random: widget.random,
    );
    _moves = 0;
    _elapsedSeconds = 0;
    _hints = _difficulty.hints;
    setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _lost || _won) return;
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _stopTimer() {
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
    if (_lost || _won) _stopTimer();
    setState(() {});
    if (_won) {
      _recordBest(_difficulty, _elapsedSeconds);
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
    if (_field.toggleFlag(index)) setState(() {});
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
    _elapsedSeconds += _hintPenaltySeconds;
    _field.reveal(candidate);
    _afterReveal();
  }

  @override
  Widget build(BuildContext context) {
    final status = _lost
        ? 'Mine hit. Try a cleaner sweep.'
        : _won
        ? 'Field cleared in ${_formatTime(_elapsedSeconds)}.'
        : 'Tap to reveal. Long press or right-click to flag. Tap a number to clear around it.';
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
                                  lost: _lost,
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
    required this.onHint,
  });

  final int flags;
  final int hints;
  final int seconds;
  final int moves;
  final int? best;
  final int mines;
  final VoidCallback onRestart;
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
    required this.lost,
    required this.onTap,
    required this.onFlag,
  });

  final MineCell cell;
  final bool lost;
  final VoidCallback onTap;
  final VoidCallback onFlag;

  @override
  Widget build(BuildContext context) {
    final wrongFlag = lost && cell.flagged && !cell.mine;
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
        mouseCursor: interactive && !lost
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
