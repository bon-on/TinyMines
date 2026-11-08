import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/platform/game_platform.dart';
import 'package:tiny_mines/src/art/garden_palette.dart';
import 'package:tiny_mines/src/game/difficulty.dart';
import 'package:tiny_mines/src/meta/garden_plots.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/meta/garden_progress_store.dart';
import 'package:tiny_mines/src/meta/garden_theme.dart';
import 'package:tiny_mines/src/ui/garden_cards.dart';
import 'package:tiny_mines/src/ui/run_summary_overlay.dart';

import 'support/fake_stopwatch.dart';

class _Seen extends TutorialStore {
  @override
  Future<bool> hasSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

final GardenProgress _partial = GardenProgress.fromJson({
  'bestRunStage': 3,
  'dailyClears': 1,
  'runsPlayed': 2,
});

Future<void> _pumpScreen(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(1),
        progressStore: MemoryGardenProgressStore(_partial),
        tutorialStore: _Seen(),
        stopwatch: FakeStopwatch(),
        now: () => DateTime(2026, 11, 2, 9),
        platform: const NoopGamePlatform(allowsResultRegistration: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('every plot paints in all four themes, earned or not', (
    tester,
  ) async {
    for (final theme in GardenTheme.values) {
      final palette = GardenPalette.of(theme);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                for (final earned in const [true, false])
                  for (final plot in GardenPlot.values)
                    PlotTile(palette: palette, plot: plot, earned: earned),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: theme.name);
      expect(find.byType(PlotTile), findsNWidgets(16));
    }
  });

  testWidgets('the card shows N/8, set bonuses and the next plot', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: GardenPlotsCard(
              palette: GardenPalette.spring,
              progress: _partial,
            ),
          ),
        ),
      ),
    );
    expect(find.text('3/8'), findsOneWidget);
    expect(find.text('Run Path - +100 XP when complete'), findsOneWidget);
    expect(find.text('Daily Beds - +150 XP when complete'), findsOneWidget);
    expect(
      find.text('Next: Lily pond - Clear 1 more daily garden'),
      findsOneWidget,
    );
    final done = GardenProgress.fromJson({
      'bestRunStage': 9,
      'dailyClears': 7,
      'rewardedSets': ['run', 'daily'],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: GardenPlotsCard(
              palette: GardenPalette.night,
              progress: done,
            ),
          ),
        ),
      ),
    );
    expect(find.text('8/8'), findsOneWidget);
    expect(find.text('Collection complete!'), findsOneWidget);
    expect(find.text('Run Path - complete'), findsOneWidget);
  });

  for (final size in const [
    Size(390, 844),
    Size(1280, 720),
    Size(1366, 768),
    Size(844, 390),
  ]) {
    testWidgets('the collection fits at $size', (tester) async {
      await _pumpScreen(tester, size);
      expect(tester.takeException(), isNull);
      final wide = size.width >= 760 && size.width / size.height >= 1.25;
      if (!wide) {
        expect(find.byKey(const ValueKey('garden-plots')), findsNothing);
        await tester.tap(find.text('Garden'));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('garden-plots')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the result card announces a new plot and a set bonus', (
    tester,
  ) async {
    final before = GardenProgress.fromJson({'bestRunStage': 5});
    final outcome = before.applyGardenRun(
      const GardenRunResult(
        stageReached: 7,
        stagesCleared: 6,
        participated: true,
      ),
    );
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunSummaryOverlay(
            report: RunReport.garden(
              stageReached: 7,
              stagesCleared: 6,
              seconds: 200,
              outcome: outcome,
            ),
            palette: GardenPalette.spring,
            onPlayAgain: () {},
            onClose: () {},
            delay: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('New plot: Sunflower patch (4/8)'), findsOneWidget);
    expect(find.text('Set complete: Run Path +100 XP'), findsOneWidget);
    expect(find.text('+200 XP'), findsOneWidget);
  });

  testWidgets('several new plots are numbered one by one', (tester) async {
    final outcome = const GardenProgress.initial().applyGardenRun(
      const GardenRunResult(
        stageReached: 3,
        stagesCleared: 2,
        participated: true,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunSummaryOverlay(
            report: RunReport.garden(
              stageReached: 3,
              stagesCleared: 2,
              seconds: 60,
              outcome: outcome,
            ),
            palette: GardenPalette.spring,
            onPlayAgain: () {},
            onClose: () {},
            delay: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('New plot: Sprout bed (1/8)'), findsOneWidget);
    expect(find.text('New plot: Tulip row (2/8)'), findsOneWidget);
  });

  testWidgets('a complete but unpaid set says the bonus comes next', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: GardenPlotsCard(
              palette: GardenPalette.spring,
              progress: GardenProgress.fromJson({'bestRunStage': 7}),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Run Path - +100 XP on your next result'), findsOneWidget);
  });

  for (final size in const [
    Size(390, 844),
    Size(844, 390),
    Size(1280, 720),
    Size(1366, 768),
  ]) {
    testWidgets('the busiest result card fits at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Daily win with Practice, Try Garden Run, Next, a new plot and a set.
      final legacy = GardenProgress.fromJson({
        'bestRunStage': 7,
        'daily': {
          for (final d in const [1, 2, 3, 4, 5, 6])
            '2026-10-0$d': {'won': true, 'seconds': 80},
        },
      });
      final outcome = legacy.applyRun(
        const RunResult(
          difficulty: Difficulty.normal,
          won: true,
          seconds: 70,
          revealedFraction: 1,
          dailyDay: '2026-11-02',
        ),
      );
      expect(outcome.newPlots, isNotEmpty);
      expect(outcome.completedSets, isNotEmpty);
      var played = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RunSummaryOverlay(
              report: RunReport(
                won: true,
                difficulty: Difficulty.normal,
                seconds: 70,
                outcome: outcome,
                daily: true,
                dailyDay: '2026-11-02',
              ),
              palette: GardenPalette.spring,
              onPlayAgain: () => played++,
              onClose: () {},
              onPractice: () {},
              onTryGardenRun: () {},
              onNext: () {},
              nextLabel: 'Classic board',
              delay: Duration.zero,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in const ['New Field', 'Practice same board']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.bottom, lessThanOrEqualTo(size.height), reason: label);
      }
      await tester.tap(find.text('New Field'));
      expect(played, 1);
    });
  }
}
