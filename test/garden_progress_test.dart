import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/src/game/difficulty.dart';
import 'package:tiny_mines/src/meta/daily_challenge.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/meta/garden_progress_store.dart';
import 'package:tiny_mines/src/meta/garden_theme.dart';

RunResult _win(Difficulty d, int seconds, {String? day}) => RunResult(
  difficulty: d,
  won: true,
  seconds: seconds,
  revealedFraction: 1,
  dailyDay: day,
);

void main() {
  group('levels and xp', () {
    test('level curve and theme unlock levels', () {
      expect(GardenProgress.xpToAdvance(1), 100);
      expect(GardenProgress.xpToAdvance(2), 140);
      GardenProgress at(int xp) => GardenProgress.fromJson({'totalXp': xp});
      expect(at(0).level, 1);
      expect(at(99).level, 1);
      expect(at(100).level, 2);
      expect(at(240).level, 3);
      expect(at(900).level, 6);
      expect(at(2339).level, 9);
      expect(at(2340).level, 10);
      expect(at(250).xpIntoLevel, 10);
      expect(at(250).xpForNextLevel, 180);
    });

    test('xp per run', () {
      expect(GardenProgress.xpForRun(_win(Difficulty.easy, 9)), 30);
      expect(GardenProgress.xpForRun(_win(Difficulty.hard, 9)), 150);
      const loss = RunResult(
        difficulty: Difficulty.normal,
        won: false,
        seconds: 9,
        revealedFraction: 0.5,
      );
      expect(GardenProgress.xpForRun(loss), 14);
      const early = RunResult(
        difficulty: Difficulty.easy,
        won: false,
        seconds: 1,
        revealedFraction: 0,
      );
      expect(GardenProgress.xpForRun(early), 3);
      expect(
        GardenProgress.xpForRun(_win(Difficulty.normal, 9, day: '2026-11-02')),
        70 + 15 + 40,
      );
    });

    test('applyRun tracks best, counts and unlocks', () {
      var p = const GardenProgress.initial();
      var out = p.applyRun(_win(Difficulty.normal, 80));
      expect(out.isNewBest, isTrue);
      expect(out.previousBest, isNull);
      expect(out.xpGained, 70);
      p = out.progress;
      out = p.applyRun(_win(Difficulty.normal, 90));
      expect(out.isNewBest, isFalse);
      p = out.progress;
      out = p.applyRun(_win(Difficulty.normal, 60));
      expect(out.isNewBest, isTrue);
      expect(out.previousBest, 80);
      expect(out.levelBefore, 2);
      expect(out.levelAfter, 2);
      p = out.progress;
      expect(p.bestTime(Difficulty.normal), 60);
      expect(p.wins['normal'], 3);
      expect(p.plays['normal'], 3);
      out = p.applyRun(_win(Difficulty.easy, 30));
      expect(out.levelAfter, 3);
      expect(out.leveledUp, isTrue);
      expect(out.newlyUnlockedThemes, [GardenTheme.autumn]);
      expect(
        out.progress.withTheme(GardenTheme.autumn).selectedTheme,
        GardenTheme.autumn,
      );
      expect(
        out.progress.withTheme(GardenTheme.night).selectedTheme,
        GardenTheme.spring,
      );
    });
  });

  group('daily', () {
    test('board is the same for a date and differs across dates', () {
      final (a, startA) = DailyChallenge.build(DateTime(2026, 11, 2));
      final (b, startB) = DailyChallenge.build(DateTime(2026, 11, 2, 23, 59));
      final (c, _) = DailyChallenge.build(DateTime(2026, 11, 3));
      List<bool> mines(f) => [for (final cell in f.cells) cell.mine as bool];
      expect(startA, startB);
      expect(mines(a), mines(b));
      expect(mines(a), isNot(mines(c)));
      expect(a.cells[startA].revealed, isTrue);
      expect(a.cells.where((c) => c.mine).length, 12);
      expect(a.lost, isFalse);
    });

    test('day keys round trip and reject junk', () {
      expect(DailyChallenge.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(DailyChallenge.parseDay('2026-01-05'), DateTime(2026, 1, 5));
      expect(DailyChallenge.parseDay('2026-02-30'), isNull);
      expect(DailyChallenge.parseDay('x'), isNull);
      expect(
        DailyChallenge.dayKey(DailyChallenge.previousDay(DateTime(2026, 3, 1))),
        '2026-02-28',
      );
    });

    test('streak grows on consecutive days and lapses after a gap', () {
      var p = const GardenProgress.initial();
      final d1 = DateTime(2026, 10, 30);
      final d2 = DateTime(2026, 10, 31);
      final d3 = DateTime(2026, 11, 1);
      for (final day in [d1, d2]) {
        final out = p.applyRun(
          _win(Difficulty.normal, 50, day: DailyChallenge.dayKey(day)),
        );
        expect(out.dailyRecorded, isTrue);
        p = out.progress;
      }
      expect(p.streak, 2);
      expect(p.currentStreak(d2), 2);
      expect(p.currentStreak(d3), 2, reason: 'still alive until d3 ends');
      expect(p.currentStreak(DateTime(2026, 11, 2)), 0);
      // A loss also keeps the streak; a second result the same day is ignored.
      final loss = RunResult(
        difficulty: Difficulty.normal,
        won: false,
        seconds: 5,
        revealedFraction: 0.2,
        dailyDay: DailyChallenge.dayKey(d3),
      );
      p = p.applyRun(loss).progress;
      expect(p.streak, 3);
      final again = p.applyRun(loss);
      expect(again.dailyRecorded, isFalse);
      expect(
        again.xpGained,
        0,
        reason: 'a recorded day cannot award base XP or daily bonuses again',
      );
      expect(again.progress.daily.length, 3);
      expect(p.dailyResult(d3)!.won, isFalse);
      // Gap: restarts at 1, best streak stays.
      p = p.applyRun(_win(Difficulty.normal, 50, day: '2026-11-05')).progress;
      expect(p.streak, 1);
      expect(p.bestStreak, 3);
      // Daily wins never set the Normal best time.
      expect(p.bestTime(Difficulty.normal), isNull);
    });
  });

  group('persistence', () {
    test('practice cannot change any saved result, even after reload', () {
      final original = const GardenProgress.initial()
          .applyRun(
            const RunResult(
              difficulty: Difficulty.normal,
              won: false,
              seconds: 42,
              revealedFraction: 0.2,
              dailyDay: '2026-11-06',
            ),
          )
          .progress;
      var progress = GardenProgress.fromJson(original.toJson());
      for (final won in [true, false, true]) {
        final run = RunResult(
          difficulty: Difficulty.normal,
          won: won,
          seconds: 1,
          revealedFraction: 1,
          dailyDay: '2026-11-06',
          practice: true,
        );
        expect(GardenProgress.xpForRun(run), 0);
        final result = progress.applyRun(run);
        expect(identical(result.progress, progress), isTrue);
        expect(result.xpGained, 0);
        expect(result.isNewBest, isFalse);
        expect(result.dailyRecorded, isFalse);
        progress = result.progress;
      }
      expect(progress.toJson(), original.toJson());
      final nextDay = progress.applyRun(
        _win(Difficulty.normal, 30, day: '2026-11-07'),
      );
      expect(nextDay.dailyRecorded, isTrue);
      expect(nextDay.xpGained, greaterThan(0));
      expect(nextDay.streak, 2);
    });
    test('json round trip', () {
      final p = const GardenProgress.initial()
          .applyRun(_win(Difficulty.hard, 200))
          .progress
          .applyRun(_win(Difficulty.normal, 70, day: '2026-11-02'))
          .progress;
      final back = GardenProgress.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(back.toJson(), p.toJson());
    });

    test('corrupt fields fall back one by one', () {
      final p = GardenProgress.fromJson({
        'bestTimes': {'easy': 40, 'bogus': 1, 'hard': -3, 'normal': 'x'},
        'totalXp': 'lots',
        'selectedTheme': 'night',
        'daily': {
          '2026-11-02': {'won': 1},
          'nope': {'won': true},
        },
        'streak': -1,
        'lastDailyDay': 7,
      });
      expect(p.bestTimes, {'easy': 40});
      expect(p.totalXp, 0);
      expect(p.selectedTheme, GardenTheme.spring, reason: 'night is locked');
      expect(p.daily, isEmpty);
      expect(p.streak, 0);
      expect(p.lastDailyDay, isNull);
      expect(GardenProgress.fromJson('junk').totalXp, 0);
    });

    test('store migrates legacy best times without loss', () async {
      SharedPreferences.setMockInitialValues({
        'best_time_easy': 65,
        'best_time_hard': 300,
        GardenProgressStore.progressKey: jsonEncode({
          'bestTimes': {'easy': 70, 'hard': 250},
          'totalXp': 120,
        }),
      });
      const store = GardenProgressStore();
      final p = await store.load();
      expect(p.bestTimes, {'easy': 65, 'hard': 250});
      expect(p.totalXp, 120);
      await store.save(p);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('best_time_hard'), 250, reason: 'mirrored back');
      expect((await store.load()).bestTimes, {'easy': 65, 'hard': 250});
    });

    test('corrupt stored json still keeps legacy times', () async {
      SharedPreferences.setMockInitialValues({
        'best_time_normal': 99,
        GardenProgressStore.progressKey: '{not json',
      });
      final p = await const GardenProgressStore().load();
      expect(p.bestTimes, {'normal': 99});
      expect(p.level, 1);
    });

    test('nothing stored gives the defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await const GardenProgressStore().load();
      expect(p.toJson(), const GardenProgress.initial().toJson());
    });
  });

  group('garden run records', () {
    test('a run adds xp once, counts the run and keeps the best stage', () {
      const result = GardenRunResult(
        stageReached: 4,
        stagesCleared: 3,
        participated: true,
      );
      final outcome = const GardenProgress.initial().applyGardenRun(result);
      expect(outcome.xpGained, 55);
      expect(outcome.isNewBest, isTrue);
      expect(outcome.progress.totalXp, 55);
      expect(outcome.progress.runsPlayed, 1);
      expect(outcome.progress.bestRunStage, 4);

      // A weaker run counts but does not lower or re-announce the record.
      final worse = outcome.progress.applyGardenRun(
        const GardenRunResult(
          stageReached: 2,
          stagesCleared: 1,
          participated: true,
        ),
      );
      expect(worse.isNewBest, isFalse);
      expect(worse.progress.bestRunStage, 4);
      expect(worse.progress.runsPlayed, 2);
      expect(worse.progress.totalXp, 55 + 25);
    });

    test('a run without a dig changes nothing', () {
      const base = GardenProgress.initial();
      final outcome = base.applyGardenRun(
        const GardenRunResult(
          stageReached: 1,
          stagesCleared: 0,
          participated: false,
        ),
      );
      expect(identical(outcome.progress, base), isTrue);
      expect(outcome.xpGained, 0);
      expect(outcome.isNewBest, isFalse);
    });

    test('best times, wins, plays and daily state are untouched', () {
      final before = const GardenProgress.initial()
          .applyRun(_win(Difficulty.easy, 40))
          .progress
          .applyRun(_win(Difficulty.normal, 90, day: '2026-11-02'))
          .progress;
      final after = before
          .applyGardenRun(
            const GardenRunResult(
              stageReached: 6,
              stagesCleared: 5,
              participated: true,
            ),
          )
          .progress;
      expect(after.bestTimes, before.bestTimes);
      expect(after.wins, before.wins);
      expect(after.plays, before.plays);
      expect(after.daily.keys, before.daily.keys);
      expect(after.streak, before.streak);
      expect(after.bestStreak, before.bestStreak);
      expect(after.lastDailyDay, before.lastDailyDay);
    });

    test('level ups and new themes are reported', () {
      final outcome = GardenProgress.fromJson({'totalXp': 235}).applyGardenRun(
        const GardenRunResult(
          stageReached: 2,
          stagesCleared: 1,
          participated: true,
        ),
      );
      expect(outcome.leveledUp, isTrue);
      expect(outcome.newlyUnlockedThemes, contains(GardenTheme.autumn));
    });

    test('fields round-trip through JSON and old saves read as zero', () {
      final saved = const GardenProgress.initial()
          .applyGardenRun(
            const GardenRunResult(
              stageReached: 9,
              stagesCleared: 8,
              participated: true,
            ),
          )
          .progress;
      final restored = GardenProgress.fromJson(
        jsonDecode(jsonEncode(saved.toJson())),
      );
      expect(restored.runsPlayed, 1);
      expect(restored.bestRunStage, 9);
      expect(restored.totalXp, saved.totalXp);

      final old = GardenProgress.fromJson({'totalXp': 50, 'wins': {'easy': 1}});
      expect(old.runsPlayed, 0);
      expect(old.bestRunStage, 0);
      expect(old.totalXp, 50);
    });

    test('corrupt values fall back to zero without losing other fields', () {
      for (final bad in <Object?>[-3, 'x', null, double.nan, 1e400, [], {}]) {
        final progress = GardenProgress.fromJson({
          'totalXp': 70,
          'runsPlayed': bad,
          'bestRunStage': bad,
        });
        expect(progress.runsPlayed, 0, reason: '$bad');
        expect(progress.bestRunStage, 0, reason: '$bad');
        expect(progress.totalXp, 70);
      }
      final fractional = GardenProgress.fromJson({
        'runsPlayed': 2.9,
        'bestRunStage': 7,
      });
      expect(fractional.runsPlayed, 2);
      expect(fractional.bestRunStage, 7);
    });

    test('the store persists the fields', () async {
      SharedPreferences.setMockInitialValues({});
      const store = GardenProgressStore();
      final saved = const GardenProgress.initial()
          .applyGardenRun(
            const GardenRunResult(
              stageReached: 3,
              stagesCleared: 2,
              participated: true,
            ),
          )
          .progress;
      await store.save(saved);
      final loaded = await store.load();
      expect(loaded.runsPlayed, 1);
      expect(loaded.bestRunStage, 3);
    });
  });
}
