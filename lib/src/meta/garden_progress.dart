import '../game/difficulty.dart';
import 'daily_challenge.dart';
import 'garden_theme.dart';

/// Facts about one finished run (a win or a mine hit), fed to
/// [GardenProgress.applyRun]. Restarts before the end are not runs.
class RunResult {
  const RunResult({
    required this.difficulty,
    required this.won,
    required this.seconds,
    required this.revealedFraction,
    this.dailyDay,
  });

  final Difficulty difficulty;
  final bool won;

  /// Clock time including hint penalties.
  final int seconds;

  /// Share of safe tiles dug (0..1); 1 on a win.
  final double revealedFraction;

  /// Day key ([DailyChallenge.dayKey]) when this was the daily board.
  final String? dailyDay;

  bool get isDaily => dailyDay != null;
}

/// Saved result of one daily garden.
class DailyResult {
  const DailyResult({required this.won, required this.seconds});

  final bool won;
  final int seconds;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'won': won,
    'seconds': seconds,
  };
}

/// Change caused by one run, shown on the summary card.
class RunOutcome {
  const RunOutcome({
    required this.progress,
    required this.xpGained,
    required this.isNewBest,
    required this.previousBest,
    required this.levelBefore,
    required this.levelAfter,
    required this.newlyUnlockedThemes,
    required this.dailyRecorded,
    required this.streak,
  });

  final GardenProgress progress;
  final int xpGained;

  /// A win that set the first or a faster best time for its difficulty.
  final bool isNewBest;

  /// Best time before this run (null if none).
  final int? previousBest;
  final int levelBefore;
  final int levelAfter;
  final List<GardenTheme> newlyUnlockedThemes;

  /// True when this run saved today's daily result.
  final bool dailyRecorded;

  /// Daily streak after this run.
  final int streak;

  bool get leveledUp => levelAfter > levelBefore;
}

/// Saved meta progress: best times, play counts, garden XP, theme, daily
/// results and the daily streak.
///
/// XP per run: a win earns [winXp] for its difficulty (Easy 30, Normal 70,
/// Hard 150); a mine hit earns a share of it for the dug tiles (at least 3).
/// A finished daily adds [dailyPlayXp], a cleared one also [dailyWinXp].
/// Reaching level L+1 costs 100 + 40 * (L - 1) XP, so Autumn (Lv3) needs 240
/// XP (about 3 Normal clears), Winter (Lv6) 900 and Night (Lv10) 2340.
class GardenProgress {
  const GardenProgress({
    required this.bestTimes,
    required this.wins,
    required this.plays,
    required this.totalXp,
    required this.selectedTheme,
    required this.daily,
    required this.streak,
    required this.lastDailyDay,
    required this.bestStreak,
  });

  const GardenProgress.initial()
    : bestTimes = const <String, int>{},
      wins = const <String, int>{},
      plays = const <String, int>{},
      totalXp = 0,
      selectedTheme = GardenTheme.spring,
      daily = const <String, DailyResult>{},
      streak = 0,
      lastDailyDay = null,
      bestStreak = 0;

  static const int dailyPlayXp = 15;
  static const int dailyWinXp = 40;

  /// Daily results kept for the history (older ones are dropped).
  static const int dailyHistory = 60;

  /// Difficulty name -> best clear time in seconds.
  final Map<String, int> bestTimes;
  final Map<String, int> wins;
  final Map<String, int> plays;
  final int totalXp;
  final GardenTheme selectedTheme;

  /// Day key -> result. One entry per day at most.
  final Map<String, DailyResult> daily;

  /// Consecutive days with a finished daily, ending at [lastDailyDay].
  final int streak;
  final String? lastDailyDay;
  final int bestStreak;

  static int winXp(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => 30,
    Difficulty.normal => 70,
    Difficulty.hard => 150,
  };

  /// XP needed to go from [level] to the next one.
  static int xpToAdvance(int level) => 100 + 40 * (level < 1 ? 0 : level - 1);

  /// XP for [run]. The daily bonus only applies when [dailyBonus] (the day's
  /// result is being recorded now).
  static int xpForRun(RunResult run, {bool dailyBonus = true}) {
    final base = winXp(run.difficulty);
    var xp = run.won
        ? base
        : ((base * 0.4 * run.revealedFraction.clamp(0.0, 1.0)).round()).clamp(
            3,
            base,
          );
    if (run.isDaily && dailyBonus) {
      xp += dailyPlayXp + (run.won ? dailyWinXp : 0);
    }
    return xp;
  }

  int get level => _split().$1;
  int get xpIntoLevel => _split().$2;
  int get xpForNextLevel => xpToAdvance(level);

  (int, int) _split() {
    var level = 1;
    var left = totalXp < 0 ? 0 : totalXp;
    while (left >= xpToAdvance(level)) {
      left -= xpToAdvance(level);
      level += 1;
    }
    return (level, left);
  }

  bool isThemeUnlocked(GardenTheme theme) => level >= theme.requiredLevel;

  int? bestTime(Difficulty difficulty) => bestTimes[difficulty.name];

  DailyResult? dailyResult(DateTime day) => daily[DailyChallenge.dayKey(day)];

  /// Streak still alive on [today]: it counts if the last daily was today or
  /// yesterday, otherwise it has lapsed.
  int currentStreak(DateTime today) {
    final last = lastDailyDay;
    if (last == null) return 0;
    if (last == DailyChallenge.dayKey(today) ||
        last == DailyChallenge.dayKey(DailyChallenge.previousDay(today))) {
      return streak;
    }
    return 0;
  }

  /// Returns this progress unchanged when [theme] is still locked.
  GardenProgress withTheme(GardenTheme theme) {
    if (!isThemeUnlocked(theme)) return this;
    return _copy(selectedTheme: theme);
  }

  /// Keeps the faster of the saved and the given best times. Used to migrate
  /// the legacy `best_time_<difficulty>` keys without loss; idempotent.
  GardenProgress mergeBestTimes(Map<String, int> times) {
    var changed = false;
    final merged = Map<String, int>.of(bestTimes);
    times.forEach((name, seconds) {
      if (Difficulty.fromName(name) == null || seconds < 0) return;
      final current = merged[name];
      if (current == null || seconds < current) {
        merged[name] = seconds;
        changed = true;
      }
    });
    return changed ? _copy(bestTimes: merged) : this;
  }

  RunOutcome applyRun(RunResult run) {
    final levelBefore = level;
    final name = run.difficulty.name;
    final previousBest = run.isDaily ? null : bestTimes[name];
    final xp = xpForRun(
      run,
      dailyBonus: run.dailyDay != null && !daily.containsKey(run.dailyDay),
    );

    // Daily boards start with a free opening, so they never set the
    // difficulty's best time and are counted on their own.
    final isNewBest =
        !run.isDaily &&
        run.won &&
        (previousBest == null || run.seconds < previousBest);
    final nextBest = Map<String, int>.of(bestTimes);
    final nextWins = Map<String, int>.of(wins);
    final nextPlays = Map<String, int>.of(plays);
    if (!run.isDaily) {
      if (isNewBest) nextBest[name] = run.seconds;
      nextPlays[name] = (plays[name] ?? 0) + 1;
      if (run.won) nextWins[name] = (wins[name] ?? 0) + 1;
    }

    var nextDaily = daily;
    var nextStreak = streak;
    var nextLast = lastDailyDay;
    var nextBestStreak = bestStreak;
    var dailyRecorded = false;
    final day = run.dailyDay;
    if (day != null && !daily.containsKey(day)) {
      final map = Map<String, DailyResult>.of(daily)
        ..[day] = DailyResult(won: run.won, seconds: run.seconds);
      final keys = map.keys.toList()..sort();
      if (keys.length > dailyHistory) {
        keys.take(keys.length - dailyHistory).forEach(map.remove);
      }
      nextDaily = map;
      final date = DailyChallenge.parseDay(day);
      final yesterday = date == null
          ? null
          : DailyChallenge.dayKey(DailyChallenge.previousDay(date));
      nextStreak = (lastDailyDay != null && lastDailyDay == yesterday)
          ? streak + 1
          : 1;
      nextLast = day;
      if (nextStreak > nextBestStreak) nextBestStreak = nextStreak;
      dailyRecorded = true;
    }

    final next = _copy(
      bestTimes: nextBest,
      wins: nextWins,
      plays: nextPlays,
      totalXp: totalXp + xp,
      daily: nextDaily,
      streak: nextStreak,
      lastDailyDay: nextLast,
      bestStreak: nextBestStreak,
    );
    final levelAfter = next.level;
    return RunOutcome(
      progress: next,
      xpGained: xp,
      isNewBest: isNewBest,
      previousBest: previousBest,
      levelBefore: levelBefore,
      levelAfter: levelAfter,
      newlyUnlockedThemes: [
        for (final theme in GardenTheme.values)
          if (levelBefore < theme.requiredLevel &&
              levelAfter >= theme.requiredLevel)
            theme,
      ],
      dailyRecorded: dailyRecorded,
      streak: next.streak,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'bestTimes': bestTimes,
    'wins': wins,
    'plays': plays,
    'totalXp': totalXp,
    'selectedTheme': selectedTheme.name,
    'daily': {
      for (final entry in daily.entries) entry.key: entry.value.toJson(),
    },
    'streak': streak,
    'lastDailyDay': lastDailyDay,
    'bestStreak': bestStreak,
  };

  /// Tolerant parser: every missing or invalid field falls back on its own.
  factory GardenProgress.fromJson(Object? json) {
    if (json is! Map) return const GardenProgress.initial();
    int readInt(Object? value) =>
        value is num && value.isFinite && value >= 0 ? value.toInt() : 0;
    Map<String, int> readCounts(Object? value) {
      final out = <String, int>{};
      if (value is Map) {
        value.forEach((key, count) {
          if (key is String &&
              Difficulty.fromName(key) != null &&
              count is num &&
              count.isFinite &&
              count >= 0) {
            out[key] = count.toInt();
          }
        });
      }
      return Map.unmodifiable(out);
    }

    final daily = <String, DailyResult>{};
    final rawDaily = json['daily'];
    if (rawDaily is Map) {
      rawDaily.forEach((key, value) {
        if (key is String &&
            DailyChallenge.parseDay(key) != null &&
            value is Map &&
            value['won'] is bool) {
          daily[key] = DailyResult(
            won: value['won'] as bool,
            seconds: readInt(value['seconds']),
          );
        }
      });
    }
    final last = json['lastDailyDay'];
    final progress = GardenProgress(
      bestTimes: readCounts(json['bestTimes']),
      wins: readCounts(json['wins']),
      plays: readCounts(json['plays']),
      totalXp: readInt(json['totalXp']),
      selectedTheme: GardenTheme.spring,
      daily: Map.unmodifiable(daily),
      streak: readInt(json['streak']),
      lastDailyDay: last is String && DailyChallenge.parseDay(last) != null
          ? last
          : null,
      bestStreak: readInt(json['bestStreak']),
    );
    final theme = json['selectedTheme'];
    return progress.withTheme(
      GardenTheme.fromName(theme is String ? theme : null),
    );
  }

  GardenProgress _copy({
    Map<String, int>? bestTimes,
    Map<String, int>? wins,
    Map<String, int>? plays,
    int? totalXp,
    GardenTheme? selectedTheme,
    Map<String, DailyResult>? daily,
    int? streak,
    String? lastDailyDay,
    int? bestStreak,
  }) {
    return GardenProgress(
      bestTimes: Map.unmodifiable(bestTimes ?? this.bestTimes),
      wins: Map.unmodifiable(wins ?? this.wins),
      plays: Map.unmodifiable(plays ?? this.plays),
      totalXp: totalXp ?? this.totalXp,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      daily: Map.unmodifiable(daily ?? this.daily),
      streak: streak ?? this.streak,
      lastDailyDay: lastDailyDay ?? this.lastDailyDay,
      bestStreak: bestStreak ?? this.bestStreak,
    );
  }
}
