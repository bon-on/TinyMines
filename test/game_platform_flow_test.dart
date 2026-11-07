import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/mine_field.dart';
import 'package:tiny_mines/platform/game_platform.dart';

class _FakeStore extends TutorialStore {
  _FakeStore({this.seen = false});
  bool seen;
  @override
  Future<bool> hasSeen() async => seen;
  @override
  Future<void> markSeen() async => seen = true;
}

class _FakePlatform extends GamePlatform {
  _FakePlatform({this.allowsResultRegistration = false});

  @override
  final bool allowsResultRegistration;

  final List<String> events = <String>[];

  @override
  Future<void> initialize() async {}

  @override
  void gameplayStart() => events.add('start');

  @override
  void gameplayStop() => events.add('stop');
}

Finder get _tiles =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));

/// Easy field (6x6, 5 mines) with the same seed the screen uses, so tests can
/// tell which tiles are safe.
MineField _referenceField() {
  final field = MineField(
    size: 6,
    mineCount: 5,
    random: math.Random(1),
    requireLogicalSolution: true,
  )..reveal(0);
  return field;
}

Future<void> _pump(
  WidgetTester tester,
  _FakePlatform platform,
  TutorialStore store,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(1),
        tutorialStore: store,
        platform: platform,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _win(WidgetTester tester) async {
  final reference = _referenceField();
  final safe = <int>[
    for (var i = 0; i < reference.cells.length; i++)
      if (!reference.cells[i].mine) i,
  ];
  final replay = MineField(
    size: 6,
    mineCount: 5,
    random: math.Random(1),
    requireLogicalSolution: true,
  );
  for (final index in safe) {
    if (replay.cells[index].revealed) continue;
    replay.reveal(index);
    await tester.tap(_tiles.at(index));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _lose(WidgetTester tester) async {
  final reference = _referenceField();
  final mine = reference.cells.indexWhere((cell) => cell.mine);
  await tester.tap(_tiles.at(0));
  await tester.pump();
  await tester.tap(_tiles.at(mine));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('seen tutorial: gameplay starts once the check resolves', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _FakeStore(seen: true));
    expect(platform.events, <String>['start']);
  });

  testWidgets('first launch starts only after the overlay closes', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _FakeStore());
    expect(find.text('How to play'), findsOneWidget);
    expect(platform.events, isEmpty);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(platform.events, <String>['start']);
  });

  testWidgets('reopening the overlay stops then restarts, no duplicates', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _FakeStore(seen: true));

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(platform.events, <String>['start', 'stop']);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(platform.events, <String>['start', 'stop']);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(platform.events, <String>['start', 'stop', 'start']);
  });

  testWidgets('restart mid-run adds no events; loss stops, new field starts', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _FakeStore(seen: true));

    await tester.tap(find.byTooltip('Restart'));
    await tester.pump();
    expect(platform.events, <String>['start']);

    await _lose(tester);
    expect(find.text('New Field'), findsOneWidget);
    expect(platform.events, <String>['start', 'stop']);

    await tester.tap(find.text('New Field'));
    await tester.pump();
    expect(platform.events, <String>['start', 'stop', 'start']);
  });

  testWidgets('winning stops gameplay', (tester) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _FakeStore(seen: true));
    await _win(tester);
    expect(find.textContaining('Field cleared'), findsOneWidget);
    expect(platform.events, <String>['start', 'stop']);
  });

  testWidgets('leaderboard prompt follows the platform', (tester) async {
    for (final allowed in <bool>[true, false]) {
      final platform = _FakePlatform(allowsResultRegistration: allowed);
      await _pump(tester, platform, _FakeStore(seen: true));
      await _win(tester);
      expect(
        find.text('기록을 등록할까요?'),
        allowed ? findsOneWidget : findsNothing,
        reason: 'allowsResultRegistration: $allowed',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  test('default platform is a no-op that allows the leaderboard', () {
    const platform = NoopGamePlatform();
    expect(platform.allowsResultRegistration, isTrue);
    platform.gameplayStart();
    platform.gameplayStop();
  });
}
