import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';

import 'support/fake_stopwatch.dart';

class _FakeStore extends TutorialStore {
  _FakeStore({this.seen = false});
  bool seen;
  @override
  Future<bool> hasSeen() async => seen;
  @override
  Future<void> markSeen() async => seen = true;
}

class _SlowStore extends TutorialStore {
  final Completer<void> release = Completer<void>();
  @override
  Future<bool> hasSeen() async {
    await release.future;
    return false;
  }

  @override
  Future<void> markSeen() async {}
}

class _LateSeenStore extends TutorialStore {
  final Completer<void> release = Completer<void>();
  @override
  Future<bool> hasSeen() async {
    await release.future;
    return true;
  }

  @override
  Future<void> markSeen() async {}
}

Finder get _tiles =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));

Future<void> _pump(
  WidgetTester tester,
  TutorialStore store, {
  Size size = const Size(800, 1400),
  Stopwatch? stopwatch,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(1),
        tutorialStore: store,
        stopwatch: stopwatch,
      ),
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

  testWidgets('one visual card explains neighbors and Play stores the flag', (
    tester,
  ) async {
    final store = _FakeStore();
    await _pump(tester, store);
    expect(find.byKey(const ValueKey('neighbor-example')), findsOneWidget);
    expect(find.textContaining('all 8 neighboring patches'), findsOneWidget);
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

  testWidgets('arrows keep the short card open and Enter starts play', (
    tester,
  ) async {
    final store = _FakeStore();
    await _pump(tester, store);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('How to play'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
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
    final watch = FakeStopwatch();
    await _pump(tester, _FakeStore(seen: true), stopwatch: watch);
    await tester.tap(_tiles.first);
    await tester.pump();
    await tester.tap(find.byTooltip('Reveal one safe tile (+10s)'));
    await tester.pump();
    expect(find.text('0:10'), findsOneWidget);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(find.text('How to play'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.tap(find.byTooltip('How to play'), warnIfMissed: false);
    await tester.pump();
    watch.advance(5000);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('0:10'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.text('0:10'), findsOneWidget);
    watch.advance(2000);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:12'), findsOneWidget);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('0:12'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('many short tutorial visits still accumulate time', (
    tester,
  ) async {
    final watch = FakeStopwatch();
    await _pump(tester, _FakeStore(seen: true), stopwatch: watch);
    await tester.tap(_tiles.first);
    await tester.pump();
    expect(watch.isRunning, isTrue);

    for (var i = 0; i < 4; i++) {
      watch.advance(900);
      await tester.tap(find.byTooltip('How to play'));
      await tester.pump();
      expect(watch.isRunning, isFalse);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(watch.isRunning, isTrue);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:03'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('taps are ignored while the first-run check is pending', (
    tester,
  ) async {
    final store = _SlowStore();
    final watch = FakeStopwatch();
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: TinyMinesScreen(
          random: math.Random(1),
          tutorialStore: store,
          stopwatch: watch,
        ),
      ),
    );
    await tester.tap(_tiles.first, warnIfMissed: false);
    await tester.pump();
    // A revealed first tile would have started the clock.
    expect(watch.isRunning, isFalse, reason: 'tap must be absorbed');
    store.release.complete();
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(watch.isRunning, isFalse, reason: 'game is still untouched');
  });

  testWidgets('board accepts taps after a late seen answer', (tester) async {
    final store = _LateSeenStore();
    final watch = FakeStopwatch();
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: TinyMinesScreen(
          random: math.Random(1),
          tutorialStore: store,
          stopwatch: watch,
        ),
      ),
    );
    await tester.pumpAndSettle();
    store.release.complete();
    await tester.pumpAndSettle();
    await tester.tap(_tiles.first);
    await tester.pump();
    expect(watch.isRunning, isTrue, reason: 'first tap must register');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Tab and Ctrl shortcuts are not swallowed by the card', (
    tester,
  ) async {
    await _pump(tester, _FakeStore());
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.f5), isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    // Ctrl+Enter, F5 did not advance or close the card.
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('How to play'), findsOneWidget);
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
