import 'package:shared_preferences/shared_preferences.dart';

/// Legacy local best clear time per difficulty (`best_time_<difficulty>`).
///
/// The game now keeps its records in `garden_progress_v1`
/// (see `GardenProgressStore`), which migrates these keys on load and mirrors
/// new bests back into them, so older builds still see the records.
/// Storage failures are swallowed so the game never depends on persistence.
class BestTimes {
  const BestTimes();

  static String _key(String difficulty) => 'best_time_$difficulty';

  /// Best time in seconds, or null when nothing was recorded yet.
  Future<int?> load(String difficulty) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_key(difficulty));
    } catch (_) {
      return null;
    }
  }

  /// Stores [seconds] when it beats the saved time. Returns true on a new best.
  Future<bool> record(String difficulty, int seconds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_key(difficulty));
      if (current != null && current <= seconds) return false;
      await prefs.setInt(_key(difficulty), seconds);
      return true;
    } catch (_) {
      return false;
    }
  }
}
