import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';

class _FakeStore extends TutorialStore {
  _FakeStore({this.seen = false});
  bool seen;
  @override
  Future<bool> hasSeen() async => seen;
  @override
  Future<void> markSeen() async => seen = true;
}

Finder get _tiles =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));

Future<void> _pump(
  WidgetTester tester,
  TutorialStore store, {
  Size size = const Size(800, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(random: math.Random(1), tutorialStore: store),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first launch shows the overlay and blocks the board', (
    tester,
  ) async {
    await _pump(tester, _FakeStore());
    expect(find.text('How to play'), findsOneWidget);
    await tester.tap(_tiles.first, warnIfMissed: false);
    await tester.pump();
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('Moves'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('Next walks the steps and Play stores the flag', (tester) async {
    final store = _FakeStore();
    await _pump(tester, store);
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('Skip and Escape close and store the flag', (tester) async {
    final store = _FakeStore();
    await _pump(tester, store);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsNothing);
    expect(store.seen, isTrue);

    final escStore = _FakeStore();
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, escStore);
    expect(find.text('How to play'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsNothing);
    expect(escStore.seen, isTrue);
  });

  testWidgets('keyboard arrows and Enter step through the overlay', (
    tester,
  ) async {
    final store = _FakeStore();
    await _pump(tester, store);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('Next'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('no overlay when the flag is set', (tester) async {
    await _pump(tester, _FakeStore(seen: true));
    expect(find.text('How to play'), findsNothing);
  });

  testWidgets('real store persists the flag in shared_preferences', (
    tester,
  ) async {
    await _pump(tester, const TutorialStore());
    expect(find.text('How to play'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(await const TutorialStore().hasSeen(), isTrue);
  });

  testWidgets('? reopens at step 1 without resetting; clock is paused', (
    tester,
  ) async {
    await _pump(tester, _FakeStore(seen: true));
    await tester.tap(_tiles.first);
    await tester.pump();
    await tester.tap(find.byTooltip('Reveal one safe tile (+10s)'));
    await tester.pump();
    expect(find.text('0:10'), findsOneWidget);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(find.text('How to play'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.byTooltip('How to play'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('0:10'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.text('0:10'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('0:12'), findsOneWidget);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('0:12'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in const [Size(390, 844), Size(844, 390), Size(1280, 720)]) {
    testWidgets('overlay fits without overflow at $size', (tester) async {
      await _pump(tester, _FakeStore(), size: size);
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(SingleChildScrollView));
      expect(card.width, lessThanOrEqualTo(360));
      expect(card.bottom, lessThanOrEqualTo(size.height));
    });
  }
}
