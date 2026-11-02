import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../best_times.dart';
import '../game/difficulty.dart';
import 'garden_progress.dart';

/// Persists [GardenProgress] as JSON under [progressKey].
///
/// Loading also migrates the legacy per-difficulty best times
/// ([BestTimes], `best_time_<difficulty>`): the faster of the two wins, so no
/// record is ever lost. Saving mirrors best times back into the legacy keys.
/// Storage failures never break play: a read failure or corrupt value loads
/// the defaults (plus whatever legacy times are readable) and a failed write
/// is ignored.
class GardenProgressStore {
  const GardenProgressStore({this.legacy = const BestTimes()});

  static const String progressKey = 'garden_progress_v1';

  final BestTimes legacy;

  Future<GardenProgress> load() async {
    var progress = const GardenProgress.initial();
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(progressKey);
      if (raw != null) progress = GardenProgress.fromJson(jsonDecode(raw));
    } catch (_) {
      progress = const GardenProgress.initial();
    }
    final legacyTimes = <String, int>{};
    for (final difficulty in Difficulty.values) {
      try {
        final seconds = await legacy.load(difficulty.name);
        if (seconds != null) legacyTimes[difficulty.name] = seconds;
      } catch (_) {}
    }
    return progress.mergeBestTimes(legacyTimes);
  }

  Future<void> save(GardenProgress progress) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(progressKey, jsonEncode(progress.toJson()));
    } catch (_) {}
    for (final entry in progress.bestTimes.entries) {
      try {
        await legacy.record(entry.key, entry.value);
      } catch (_) {}
    }
  }
}

/// In-memory store for tests.
class MemoryGardenProgressStore extends GardenProgressStore {
  MemoryGardenProgressStore([this.value = const GardenProgress.initial()]);

  GardenProgress value;
  int saveCount = 0;

  @override
  Future<GardenProgress> load() async => value;

  @override
  Future<void> save(GardenProgress progress) async {
    value = progress;
    saveCount += 1;
  }
}
