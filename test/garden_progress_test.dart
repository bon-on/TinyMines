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
        lessThan(GardenProgress.dailyPlayXp + 3),
        reason: 'no daily bonus for a day already recorded',
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
}
