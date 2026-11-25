import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/platform/game_platform.dart';
import 'package:tiny_mines/src/art/garden_palette.dart';
import 'package:tiny_mines/src/game/difficulty.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/meta/garden_progress_store.dart';
import 'package:tiny_mines/src/ui/garden_cards.dart';
import 'package:tiny_mines/src/ui/run_summary_overlay.dart';

import 'support/fake_stopwatch.dart';

class _Tutorial extends TutorialStore {
  _Tutorial(this.seen);
  final bool seen;
  @override
  Future<bool> hasSeen() async => seen;
  @override
  Future<void> markSeen() async {}
}

class _RecordingPlatform extends NoopGamePlatform {
  _RecordingPlatform() : super(allowsResultRegistration: false);
  final List<String> events = <String>[];
  @override
  void gameplayStart() => events.add('start');
  @override
  void gameplayStop() => events.add('stop');
}

/// Progress store whose load completes only when released.
class _SlowProgressStore extends MemoryGardenProgressStore {
  _SlowProgressStore();
  final Completer<void> release = Completer<void>();
  @override
  Future<GardenProgress> load() async {
    await release.future;
    return super.load();
  }
}

Finder get _tiles =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));

Finder get _runHud => find.byType(GardenRunHud);

Finder _hudStage(int stage) =>
    find.descendant(of: _runHud, matching: find.text('Stage $stage'));

Future<void> _launch(
  WidgetTester tester, {
  required MemoryGardenProgressStore store,
  GamePlatform? platform,
  bool tutorialSeen = true,
  bool launchIntoRun = true,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(1),
        progressStore: store,
        tutorialStore: _Tutorial(tutorialSeen),
        stopwatch: FakeStopwatch(),
        now: () => DateTime(2026, 11, 2, 9),
        platform: platform ?? const NoopGamePlatform(),
        gardenTools: false,
        launchIntoRun: launchIntoRun,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

/// A run below the best stage: no "New best" pill or new plot, so the card
/// has the same rows as a regular result on short screens.
RunReport _gardenReport() {
  final outcome = GardenProgress.fromJson({'runsPlayed': 1, 'bestRunStage': 5})
      .applyGardenRun(
        const GardenRunResult(
          stageReached: 3,
          stagesCleared: 2,
          participated: true,
        ),
      );
  return RunReport.garden(
    stageReached: 3,
    stagesCleared: 2,
    seconds: 95,
    outcome: outcome,
  );
}

RunReport _dailyReport(String day) {
  final outcome = const GardenProgress.initial().applyRun(
    RunResult(
      difficulty: Difficulty.normal,
      won: true,
      seconds: 65,
      revealedFraction: 1,
      dailyDay: day,
    ),
  );
  return RunReport(
    won: true,
    difficulty: Difficulty.normal,
    seconds: 65,
    outcome: outcome,
    daily: true,
    dailyDay: day,
  );
}

Future<void> _showCard(
  WidgetTester tester,
  RunReport report, {
  required DateTime now,
  Size size = const Size(800, 1400),
  Duration delay = Duration.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RunSummaryOverlay(
          report: report,
          palette: GardenPalette.spring,
          onPlayAgain: () {},
          onClose: () {},
          delay: delay,
          now: now,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('launch', () {
    testWidgets('a first launch opens Garden Run stage 1 with the tips', (
      tester,
    ) async {
      final store = MemoryGardenProgressStore();
      final platform = _RecordingPlatform();
      await _launch(
        tester,
        store: store,
        platform: platform,
        tutorialSeen: false,
      );
      expect(_tiles, findsNWidgets(25));
      expect(_hudStage(1), findsOneWidget);
      expect(find.byKey(const ValueKey('garden-run-cta')), findsNothing);
      expect(find.byKey(const ValueKey('onboarding-strip')), findsOneWidget);
      // The Classic launch board was replaced without a portal stop/start.
      expect(platform.events, ['start']);
      expect(store.value.plays, isEmpty);
      expect(store.value.runsPlayed, 0);
      expect(store.value.runCheckpoint, isNull);

      await tester.tap(_tiles.at(12));
      await tester.pump();
      expect(store.value.runCheckpoint, isNotNull);

      // Leaving settles the run once; a second board change adds nothing.
      await tester.tap(find.text('Easy 6x6'));
      await tester.pumpAndSettle();
      expect(store.value.runsPlayed, 1);
      expect(store.value.runCheckpoint, isNull);
      final xp = store.value.totalXp;
      await tester.tap(find.text('Normal 9x9'));
      await tester.pumpAndSettle();
      expect(store.value.runsPlayed, 1);
      expect(store.value.totalXp, xp);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a saved run resumes at launch without a tap', (tester) async {
      final store = MemoryGardenProgressStore();
      await _launch(tester, store: store);
      await tester.tap(_tiles.at(12));
      await tester.pump();
      final snapshot = store.value.runCheckpoint!;
      await tester.pumpWidget(const SizedBox());

      // Without the launch switch the entry names the stage (the phone
      // meta row drops the hearts; the full label keeps them).
      final labelled = MemoryGardenProgressStore(
        GardenProgress.fromJson(store.value.toJson()),
      );
      await _launch(tester, store: labelled, launchIntoRun: false);
      expect(find.text('Resume Garden Run - stage 1'), findsOneWidget);
      expect(
        resumeRunLabel(labelled.value),
        'Resume Garden Run - stage 1, 3 hearts',
      );
      await tester.pumpWidget(const SizedBox());

      final reopened = MemoryGardenProgressStore(
        GardenProgress.fromJson(store.value.toJson()),
      );
      final platform = _RecordingPlatform();
      await _launch(tester, store: reopened, platform: platform);
      expect(_tiles, findsNWidgets(25));
      expect(_hudStage(1), findsOneWidget);
      expect(find.textContaining('Resume Garden Run'), findsNothing);
      expect(reopened.value.runCheckpoint!.board, snapshot.board);
      expect(platform.events, ['start']);

      await tester.tap(find.text('Easy 6x6'));
      await tester.pumpAndSettle();
      expect(reopened.value.runCheckpoint, isNull);
      expect(reopened.value.runsPlayed, 1);
    });

    testWidgets('a returning player without a saved run gets Classic', (
      tester,
    ) async {
      final store = MemoryGardenProgressStore(
        GardenProgress.fromJson({'runsPlayed': 1, 'bestRunStage': 2}),
      );
      await _launch(tester, store: store);
      expect(_tiles, findsNWidgets(36));
      expect(_runHud, findsNothing);
      expect(find.text('Garden Run - best stage 2'), findsOneWidget);
    });

    testWidgets('a dig before the progress loads keeps the Classic board', (
      tester,
    ) async {
      final store = _SlowProgressStore();
      final platform = _RecordingPlatform();
      await _launch(tester, store: store, platform: platform, settle: false);
      await tester.pump();
      await tester.tap(_tiles.at(0));
      await tester.pump();
      store.release.complete();
      await tester.pumpAndSettle();
      expect(_tiles, findsNWidgets(36));
      expect(_runHud, findsNothing);
      expect(platform.events, ['start']);
      expect(store.value.runsPlayed, 0);
    });
  });

  group('result card', () {
    testWidgets('shows the time to the next daily and focuses New Run', (
      tester,
    ) async {
      await _showCard(
        tester,
        _gardenReport(),
        now: DateTime(2026, 11, 2, 18, 48),
        delay: const Duration(milliseconds: 800),
      );
      expect(
        find.text("Today's daily garden is open (5h 12m left)."),
        findsOneWidget,
      );
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'play-again');
      expect(find.byKey(const ValueKey('next-goal')), findsOneWidget);
    });

    testWidgets('a recorded daily shows the streak and the next daily', (
      tester,
    ) async {
      await _showCard(
        tester,
        _dailyReport('2026-11-09'),
        now: DateTime(2026, 11, 9, 23, 30),
      );
      expect(
        find.text('Daily streak: 1 day. New daily in 30m.'),
        findsOneWidget,
      );
      // Finished after midnight: today's daily is already open.
      await _showCard(
        tester,
        _dailyReport('2026-11-09'),
        now: DateTime(2026, 11, 10, 0, 1),
      );
      expect(
        find.text(
          "Play today's daily to keep your 1-day streak (23h 59m left).",
        ),
        findsOneWidget,
      );
    });

    for (final size in const [Size(844, 390), Size(932, 430), Size(560, 315)]) {
      testWidgets('the daily line fits a short card at $size', (tester) async {
        await _showCard(
          tester,
          _gardenReport(),
          now: DateTime(2026, 11, 2, 9),
          size: size,
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('daily-hook')), findsOneWidget);
        final button = tester.getRect(find.text('New Run'));
        expect(button.bottom, lessThanOrEqualTo(size.height));
        expect(button.top, greaterThanOrEqualTo(0));
        final xp = tester.getRect(find.textContaining(RegExp(r'^\+\d+ XP$')));
        expect(xp.bottom, lessThanOrEqualTo(button.top));
      });
    }
  });
}
