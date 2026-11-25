import 'dart:math' as math;
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/mine_field.dart';
import 'package:tiny_mines/platform/game_platform.dart';
import 'package:tiny_mines/src/game/garden_run.dart';
import 'package:tiny_mines/src/game/garden_tools.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/meta/garden_progress_store.dart';

class _Seen extends TutorialStore {
  @override
  Future<bool> hasSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

Finder get _tiles =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));

Finder get _picker => find.byKey(const ValueKey('tool-picker'));

Finder get _fullHearts => find.descendant(
  of: find.byKey(const ValueKey('board-hearts')),
  matching: find.byIcon(Icons.favorite_rounded),
);

/// A seed whose first offer (full hearts, no tools) contains [tool].
int _seedOffering(GardenTool tool) {
  for (var seed = 0; seed < 200; seed++) {
    if (GardenTools.offer(
      const GardenRunState(),
      math.Random(seed),
    ).contains(tool)) {
      return seed;
    }
  }
  throw StateError('no seed offers $tool');
}

Future<void> _pump(
  WidgetTester tester, {
  required int toolSeed,
  Size size = const Size(800, 1400),
  MemoryGardenProgressStore? store,
  bool start = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(1),
        toolRandom: math.Random(toolSeed),
        progressStore: store ?? MemoryGardenProgressStore(),
        tutorialStore: _Seen(),
        now: () => DateTime(2026, 11, 2, 9),
        platform: const NoopGamePlatform(allowsResultRegistration: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (!start) return;
  final cta = find.byKey(const ValueKey('garden-run-cta'));
  final wide = find.text('Start Garden Run');
  await tester.tap(
    cta.evaluate().isNotEmpty
        ? cta
        : wide.evaluate().isNotEmpty
        ? wide
        : find.textContaining('Garden Run -'),
  );
  await tester.pumpAndSettle();
}

/// Mirrors the screen's board generation (same seed, same call order).
class _Garden {
  final math.Random random = math.Random(1);
  MineField stage(int stage, int first) {
    final config = GardenRun.stage(stage);
    return MineField(
      size: config.size,
      mineCount: config.mines,
      random: random,
      requireLogicalSolution: config.fairStart,
      survivable: true,
    )..reveal(first);
  }
}

Future<void> _clear(WidgetTester tester, MineField reference, int first) async {
  final replay =
      MineField(
        size: reference.size,
        mineCount: reference.mineCount,
        survivable: true,
      )..plantMinesAt([
        for (var i = 0; i < reference.cells.length; i++)
          if (reference.cells[i].mine) i,
      ]);
  for (final i in [
    first,
    for (var i = 0; i < reference.cells.length; i++)
      if (i != first) i,
  ]) {
    if (reference.cells[i].mine || replay.cells[i].revealed) continue;
    replay.reveal(i);
    await tester.tap(_tiles.at(i));
    await tester.pump();
  }
}

List<int> _moles(MineField field) => [
  for (var i = 0; i < field.cells.length; i++)
    if (field.cells[i].mine) i,
];

Future<void> _tap(WidgetTester tester, int index) async {
  await tester.tap(_tiles.at(index));
  await tester.pump();
}

/// Clears stage 1 and opens the picker via "Next stage".
Future<_Garden> _toPicker(WidgetTester tester) async {
  final garden = _Garden();
  await _clear(tester, garden.stage(1, 12), 12);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text('Next stage'));
  await tester.pump();
  return garden;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('reopening preserves the offer and the selected tool', (
    tester,
  ) async {
    final store = MemoryGardenProgressStore();
    await _pump(tester, toolSeed: 3, store: store);
    await _toPicker(tester);
    final offer = store.value.runCheckpoint!.offer;
    expect(offer, hasLength(3));

    await tester.pumpWidget(const SizedBox());
    final reopened = MemoryGardenProgressStore(
      GardenProgress.fromJson(store.value.toJson()),
    );
    await _pump(tester, toolSeed: 21, store: reopened, start: false);
    await tester.tap(find.textContaining('Resume Garden Run'));
    await tester.pumpAndSettle();
    expect(_picker, findsOneWidget);
    final clover = find.bySemanticsLabel(
      '${GardenTool.clover.label}: ${GardenTool.clover.blurb}',
    );
    expect(
      tester
          .getSemantics(clover)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(reopened.value.runCheckpoint!.offer, offer);
    await tester.tap(find.byKey(const ValueKey('tool-clover')));
    await tester.pumpAndSettle();
    expect(reopened.value.runCheckpoint!.run.clovers, 1);
    expect(reopened.value.runCheckpoint!.offer, isEmpty);
    expect(reopened.value.runCheckpoint!.board, '.' * 36);

    await tester.pumpWidget(const SizedBox());
    final afterPick = MemoryGardenProgressStore(
      GardenProgress.fromJson(reopened.value.toJson()),
    );
    await _pump(tester, toolSeed: 21, store: afterPick, start: false);
    await tester.tap(find.textContaining('Resume Garden Run'));
    await tester.pumpAndSettle();
    expect(_picker, findsNothing);
    expect(_tiles, findsNWidgets(36));
    await tester.tap(find.text('Normal 9x9'));
    await tester.pumpAndSettle();
    expect(afterPick.value.runCheckpoint, isNull);
    expect(afterPick.value.runsPlayed, 1);
    expect(afterPick.value.bestRunStage, 2);
    expect(afterPick.value.totalXp, 25);
  });

  testWidgets('the picker offers three tools and blocks the board', (
    tester,
  ) async {
    await _pump(tester, toolSeed: 3);
    await _toPicker(tester);
    expect(_picker, findsOneWidget);
    expect(find.textContaining('Pick a garden tool'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('tool-') &&
            (w.key! as ValueKey<String>).value != 'tool-picker',
      ),
      findsNWidgets(3),
    );
    // Still the cleared 5x5 board, and the 1.8 s timer does not pick for us.
    expect(_tiles, findsNWidgets(25));
    await tester.pump(const Duration(seconds: 5));
    expect(_picker, findsOneWidget);
    expect(_tiles, findsNWidgets(25));
  });

  testWidgets('picking a tool starts the next stage', (tester) async {
    await _pump(tester, toolSeed: 3);
    await _toPicker(tester);
    final offer = GardenTools.offer(const GardenRunState(), math.Random(3));
    await tester.tap(find.byKey(ValueKey('tool-${offer.first.name}')));
    await tester.pumpAndSettle();
    expect(_picker, findsNothing);
    expect(_tiles, findsNWidgets(36));
  });

  testWidgets('keys 1-3 pick and the auto-advance timer opens the picker', (
    tester,
  ) async {
    await _pump(tester, toolSeed: 5);
    final garden = _Garden();
    await _clear(tester, garden.stage(1, 12), 12);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(_picker, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    expect(_picker, findsNothing);
    expect(_tiles, findsNWidgets(36));
  });

  testWidgets('a clover absorbs one mole, the next one costs a heart', (
    tester,
  ) async {
    final seed = _seedOffering(GardenTool.clover);
    await _pump(tester, toolSeed: seed);
    final garden = await _toPicker(tester);
    await tester.tap(find.byKey(const ValueKey('tool-clover')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Clover x1'), findsWidgets);
    final ref = garden.stage(2, 14);
    final moles = _moles(ref);
    await _tap(tester, 14);
    await _tap(tester, moles[0]);
    expect(_fullHearts, findsNWidgets(3));
    expect(find.textContaining('Lucky clover'), findsWidgets);
    await _tap(tester, moles[1]);
    expect(_fullHearts, findsNWidgets(2));
    expect(find.textContaining('lost a heart'), findsWidgets);
  });

  testWidgets(
    'a can digs a safe 3x3 patch (no cascade) after the first dig, once',
    (tester) async {
      final seed = _seedOffering(GardenTool.can);
      await _pump(tester, toolSeed: seed);
      final semantics = tester.ensureSemantics();
      final garden = await _toPicker(tester);
      await tester.tap(find.byKey(const ValueKey('tool-can')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Can x1'), findsWidgets);

      final ref = garden.stage(2, 14);
      final center = ref.hintCandidate();
      expect(center, isNotNull);
      for (final cell in [center!, ...ref.neighbors(center)]) {
        ref.revealTile(cell);
      }
      final expectedHidden = ref.cells.where((c) => !c.revealed).length;
      await _tap(tester, 14);
      expect(
        find.bySemanticsLabel('Hidden tile', skipOffstage: false),
        findsNWidgets(expectedHidden),
      );
      expect(_fullHearts, findsNWidgets(3));
      semantics.dispose();
    },
  );

  testWidgets('a lantern adds two hints to the shared budget', (tester) async {
    final seed = _seedOffering(GardenTool.lantern);
    await _pump(tester, toolSeed: seed);
    await _toPicker(tester);
    await tester.tap(find.byKey(const ValueKey('tool-lantern')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('5')),
      findsOneWidget,
    );
  });

  for (final size in const [
    Size(1280, 720),
    Size(1366, 768),
    Size(390, 844),
    Size(320, 568),
    Size(560, 315),
  ]) {
    testWidgets('the picker fits at $size', (tester) async {
      await _pump(tester, toolSeed: 3, size: size);
      await _toPicker(tester);
      expect(_picker, findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final tool in GardenTools.offer(
        const GardenRunState(),
        math.Random(3),
      )) {
        final card = find.byKey(ValueKey('tool-${tool.name}'));
        expect(card, findsOneWidget);
        await tester.ensureVisible(card);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('a card open when the stage ends delays the picker', (
    tester,
  ) async {
    await _pump(tester, toolSeed: 5);
    final garden = _Garden();
    await _clear(tester, garden.stage(1, 12), 12);
    await tester.tap(find.byIcon(Icons.help_outline).first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 2500));
    expect(_picker, findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_picker, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pumpAndSettle();
    expect(_picker, findsNothing);
    expect(_tiles, findsNWidgets(36));
  });

  testWidgets('with the picker, gameplay stops and restarts around it', (
    tester,
  ) async {
    final platform = _Events();
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryGardenProgressStore();
    await tester.pumpWidget(
      MaterialApp(
        home: TinyMinesScreen(
          random: math.Random(1),
          toolRandom: math.Random(3),
          progressStore: store,
          tutorialStore: _Seen(),
          platform: platform,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cta = find.byKey(const ValueKey('garden-run-cta'));
    await tester.tap(
      cta.evaluate().isNotEmpty ? cta : find.text('Start Garden Run'),
    );
    await tester.pumpAndSettle();
    final garden = _Garden();
    await _clear(tester, garden.stage(1, 12), 12);
    await tester.pump(const Duration(milliseconds: 100));
    expect(platform.events, ['start']);
    await tester.tap(find.text('Next stage'));
    await tester.pump();
    expect(platform.events, ['start', 'stop']);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pumpAndSettle();
    expect(platform.events, ['start', 'stop', 'start']);
    // Leaving after the pick ends the run once: stage 2 reached, one clear.
    await tester.tap(find.text('Normal 9x9'));
    await tester.pumpAndSettle();
    expect(store.value.bestRunStage, 2);
    expect(store.value.runsPlayed, 1);
    expect(store.value.totalXp, 25);
  });

  group('live run status (feature-live-run-status)', () {
    String status(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('garden-run-status')))
        .data!;
    Finder plots(int n) => find.descendant(
      of: find.byKey(const ValueKey('garden-plots')),
      matching: find.text('$n/8'),
    );

    testWidgets('panels wait for the next stage to load before moving on', (
      tester,
    ) async {
      final store = MemoryGardenProgressStore();
      await _pump(
        tester,
        toolSeed: _seedOffering(GardenTool.clover),
        size: const Size(1280, 720),
        store: store,
      );
      expect(status(tester), 'Stage 1');
      await _toPicker(tester);
      expect(_picker, findsOneWidget);
      // Stage 1 is cleared, but stage 2 has not started: no plot yet.
      expect(status(tester), 'Stage 1');
      expect(plots(0), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tool-clover')));
      await tester.pumpAndSettle();
      expect(status(tester), 'Stage 2');
      expect(plots(1), findsOneWidget);
    });

    testWidgets('a resumed run with a pending offer shows the cleared stage', (
      tester,
    ) async {
      final store = MemoryGardenProgressStore();
      await _pump(
        tester,
        toolSeed: _seedOffering(GardenTool.clover),
        size: const Size(1280, 720),
        store: store,
      );
      await _toPicker(tester);
      await tester.pumpWidget(const SizedBox());
      final reopened = MemoryGardenProgressStore(
        GardenProgress.fromJson(store.value.toJson()),
      );
      await _pump(
        tester,
        toolSeed: 21,
        size: const Size(1280, 720),
        store: reopened,
        start: false,
      );
      await tester.tap(find.textContaining('Resume Garden Run'));
      await tester.pumpAndSettle();
      expect(_picker, findsOneWidget);
      expect(status(tester), 'Stage 1');
      expect(plots(0), findsOneWidget);
    });
  });
}

class _Events extends NoopGamePlatform {
  _Events() : super(allowsResultRegistration: false);
  final List<String> events = <String>[];
  @override
  void gameplayStart() => events.add('start');
  @override
  void gameplayStop() => events.add('stop');
}
