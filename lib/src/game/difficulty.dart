/// Board presets. Sizes, mine counts and hint budgets are part of the rules.
enum Difficulty {
  easy('Easy', 6, 5, 3),
  normal('Normal', 9, 12, 3),
  hard('Hard', 12, 26, 4),
  expert('Expert', 14, 40, 4);

  const Difficulty(this.label, this.size, this.mines, this.hints);

  final String label;
  final int size;
  final int mines;
  final int hints;

  /// Picker label, e.g. "Easy 6x6".
  String get title => '$label ${size}x$size';

  double get gap => size > 10 ? 3 : 4;

  /// Boards drawn until a solver opens every safe tile without a guess.
  bool get guessFree => this == expert;

  /// The next harder preset, or null for [hard].
  Difficulty? get next => index + 1 < values.length ? values[index + 1] : null;

  static Difficulty? fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
