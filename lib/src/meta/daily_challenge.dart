import 'dart:math' as math;

import '../../mine_field.dart';
import '../game/difficulty.dart';

/// The daily garden: one Normal board per local calendar day, the same for
/// every player, with a starting patch already dug.
class DailyChallenge {
  const DailyChallenge._();

  static const Difficulty difficulty = Difficulty.normal;

  /// Stable day key, e.g. "2026-11-02".
  static String dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Parses [dayKey] output; null for anything else.
  static DateTime? parseDay(String key) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  /// Seed derived from the date only. Kept below 2^53 so web and native
  /// builds compute the same value.
  static int seedFor(DateTime date) =>
      ((date.year * 10000 + date.month * 100 + date.day) * 31337 + 7) %
      2147483647;

  /// Builds today's board: mines are planted away from a seeded start cell,
  /// and that cell is revealed (it is always an opening or a number).
  /// Returns the field and the start cell.
  static (MineField, int) build(DateTime date) {
    final random = math.Random(seedFor(date));
    final size = difficulty.size;
    // Start somewhere in the middle area so the opening is useful.
    final row = 2 + random.nextInt(size - 4);
    final col = 2 + random.nextInt(size - 4);
    final start = row * size + col;
    final field = MineField(
      size: size,
      mineCount: difficulty.mines,
      random: random,
    );
    field.reveal(start);
    return (field, start);
  }

  /// Day before [date] (calendar arithmetic, DST safe).
  static DateTime previousDay(DateTime date) =>
      DateTime(date.year, date.month, date.day - 1);
}
