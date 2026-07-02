import 'dart:math' as math;

import 'package:flutter/material.dart';

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
      home: const TinyMinesScreen(),
    );
  }
}

class TinyMinesScreen extends StatefulWidget {
  const TinyMinesScreen({super.key});

  @override
  State<TinyMinesScreen> createState() => _TinyMinesScreenState();
}

class _TinyMinesScreenState extends State<TinyMinesScreen> {
  final math.Random _random = math.Random();
  _Difficulty _difficulty = _Difficulty.easy;
  late List<_MineCell> _cells;
  bool _armed = false;
  bool _lost = false;
  bool _won = false;
  int _moves = 0;

  int get _size => _difficulty.size;
  int get _mineCount => _difficulty.mines;
  int get _flags => _cells.where((cell) => cell.flagged).length;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  void _restart() {
    _cells = List.generate(_size * _size, (_) => _MineCell());
    _armed = false;
    _lost = false;
    _won = false;
    _moves = 0;
    setState(() {});
  }

  int _index(int row, int col) => row * _size + col;

  Iterable<int> _neighbors(int index) sync* {
    final row = index ~/ _size;
    final col = index % _size;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = row + dr;
        final nc = col + dc;
        if (nr >= 0 && nr < _size && nc >= 0 && nc < _size) {
          yield _index(nr, nc);
        }
      }
    }
  }

  void _plantMines(int safeIndex) {
    final blocked = {safeIndex, ..._neighbors(safeIndex)};
    final candidates = [
      for (var i = 0; i < _cells.length; i++)
        if (!blocked.contains(i)) i,
    ]..shuffle(_random);

    for (final index in candidates.take(_mineCount)) {
      _cells[index].mine = true;
    }
    for (var i = 0; i < _cells.length; i++) {
      _cells[i].nearby = _neighbors(i).where((n) => _cells[n].mine).length;
    }
    _armed = true;
  }

  void _reveal(int index) {
    if (_lost || _won) return;
    if (!_armed) _plantMines(index);
    final cell = _cells[index];
    if (cell.flagged || cell.revealed) return;
    _moves++;

    if (cell.mine) {
      cell.revealed = true;
      _lost = true;
      for (final mineCell in _cells.where((c) => c.mine)) {
        mineCell.revealed = true;
      }
      setState(() {});
      return;
    }

    final queue = <int>[index];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      final currentCell = _cells[current];
      if (currentCell.revealed || currentCell.flagged) continue;
      currentCell.revealed = true;
      if (currentCell.nearby == 0) {
        for (final next in _neighbors(current)) {
          final nextCell = _cells[next];
          if (!nextCell.revealed && !nextCell.flagged && !nextCell.mine) {
            queue.add(next);
          }
        }
      }
    }
    _won = _cells.where((c) => !c.mine).every((c) => c.revealed);
    setState(() {});
  }

  void _toggleFlag(int index) {
    if (_lost || _won) return;
    final cell = _cells[index];
    if (cell.revealed) return;
    cell.flagged = !cell.flagged;
    setState(() {});
  }

  void _selectDifficulty(_Difficulty difficulty) {
    if (_difficulty == difficulty) return;
    _difficulty = difficulty;
    _restart();
  }

  @override
  Widget build(BuildContext context) {
    final status = _lost
        ? 'Mine hit. Try a cleaner sweep.'
        : _won
        ? 'Field cleared.'
        : 'Tap to reveal. Long press to flag.';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            children: [
              _Header(
                flags: _flags,
                moves: _moves,
                mines: _mineCount,
                onRestart: _restart,
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
                          itemCount: _cells.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _size,
                                crossAxisSpacing: _difficulty.gap,
                                mainAxisSpacing: _difficulty.gap,
                              ),
                          itemBuilder: (context, index) {
                            return _MineTile(
                              cell: _cells[index],
                              onTap: () => _reveal(index),
                              onLongPress: () => _toggleFlag(index),
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
    );
  }
}

class _MineCell {
  bool mine = false;
  bool revealed = false;
  bool flagged = false;
  int nearby = 0;
}

enum _Difficulty {
  easy('Easy', 8, 8),
  normal('Normal', 9, 10),
  hard('Hard', 12, 24);

  const _Difficulty(this.label, this.size, this.mines);

  final String label;
  final int size;
  final int mines;

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
    required this.moves,
    required this.mines,
    required this.onRestart,
  });

  final int flags;
  final int moves;
  final int mines;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Tiny Mines',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ),
        _Metric(label: 'Mines', value: '$mines'),
        const SizedBox(width: 6),
        _Metric(label: 'Flags', value: '$flags'),
        const SizedBox(width: 6),
        _Metric(label: 'Moves', value: '$moves'),
        IconButton(
          onPressed: onRestart,
          tooltip: 'Restart',
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
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
    required this.onTap,
    required this.onLongPress,
  });

  final _MineCell cell;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final content = cell.revealed
        ? cell.mine
              ? Icons.close
              : null
        : cell.flagged
        ? Icons.flag
        : null;
    return Material(
      color: cell.revealed ? const Color(0xFF252B2E) : const Color(0xFF65756F),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Center(
          child: content != null
              ? Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5484D),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    content,
                    color: const Color(0xFFFFFFFF),
                    size: 17,
                  ),
                )
              : Text(
                  cell.revealed && cell.nearby > 0 ? '${cell.nearby}' : '',
                  style: TextStyle(
                    color: _numberColor(cell.nearby),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
      _ => Colors.white,
    };
  }
}
