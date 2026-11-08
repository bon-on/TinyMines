import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/mine_field.dart';
import 'package:tiny_mines/platform/game_platform.dart';
import 'package:tiny_mines/src/audio/sound_fx.dart';
import 'package:tiny_mines/src/meta/garden_progress_store.dart';
import 'package:tiny_mines/src/ui/garden_board.dart';

import 'support/fake_stopwatch.dart';

class _Tutorial extends TutorialStore {
  _Tutorial({this.seen = true});
  bool seen;
  @override
  Future<bool> hasSeen() async => seen;
  @override
  Future<void> markSeen() async => seen = true;
}

class _Platform extends NoopGamePlatform {
  _Platform() : super(allowsResultRegistration: false);
  final events = <String>[];
  @override
  void gameplayStart() => events.add('start');
  @override
  void gameplayStop() => events.add('stop');
}

class _LateTutorial extends TutorialStore {
  final release = Completer<bool>();
  @override
  Future<bool> hasSeen() => release.future;
}

class _Effects implements SoundPlayer {
  @override
  void play(String asset, double volume) {}
  @override
  void dispose() {}
}

class _Music implements MusicPlayer {
  final events = <String>[];
  @override
  Future<bool> start(String asset, double volume) async {
    events.add('start');
    return true;
  }

  @override
  void pause() => events.add('pause');
  @override
  Future<bool> resume() async {
    events.add('resume');
    return true;
  }

  @override
  void stop() => events.add('stop');
}

Finder get _tiles =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));
MineField _field(WidgetTester tester) =>
    tester.widget<GardenBoard>(find.byType(GardenBoard)).field;

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  _Platform? platform,
  FakeStopwatch? watch,
  _Tutorial? tutorial,
  SoundFx? sound,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(1),
        tutorialStore: tutorial ?? _Tutorial(),
        progressStore: MemoryGardenProgressStore(),
        stopwatch: watch,
        platform: platform ?? _Platform(),
        soundFx: sound,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _background(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void _foreground(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'tap Flag mode marks tiles without digging and resets on new field',
    (tester) async {
      final watch = FakeStopwatch();
      await _pump(tester, watch: watch);
      final field = _field(tester);
      expect(
        find.text('Start anywhere - your first dig is safe.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('flag-mode')));
      await tester.tap(_tiles.at(14));
      await tester.pump();
      expect(field.cells[14].flagged, isTrue);
      expect(field.armed, isFalse);
      expect(watch.isRunning, isFalse);
      await tester.tap(find.byKey(const ValueKey('dig-mode')));
      await tester.pump();
      expect(
        field.cells[14].flagged,
        isTrue,
        reason: 'switching does not alter tiles',
      );
      await tester.tap(_tiles.at(14));
      await tester.pump();
      expect(field.armed, isFalse, reason: 'Dig does not reveal a flag');
      expect(
        find.text('Switch to Flag to remove this marker.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('flag-mode')));
      await tester.tap(_tiles.at(14));
      await tester.pump();
      expect(field.cells[14].flagged, isFalse);
      await tester.tap(find.byTooltip('Restart'));
      await tester.pump();
      await tester.tap(_tiles.at(14));
      await tester.pump();
      expect(
        _field(tester).cells[14].revealed,
        isTrue,
        reason: 'restart defaults to Dig',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'right click and long press flag in either mode; revealed tiles never chord in Flag',
    (tester) async {
      await _pump(tester);
      final field = _field(tester)..plantMinesAt([0, 2, 4, 30, 35]);
      await tester.tap(_tiles.at(7));
      await tester.pump();
      expect(field.cells[7].nearby, 2);
      await tester.longPress(_tiles.at(0));
      await tester.tap(_tiles.at(2), buttons: kSecondaryMouseButton);
      await tester.pump();
      expect(field.cells[0].flagged, isTrue);
      expect(field.cells[2].flagged, isTrue);
      final revealed = field.cells.where((c) => c.revealed).length;
      await tester.tap(find.byKey(const ValueKey('flag-mode')));
      await tester.tap(_tiles.at(7));
      await tester.pump();
      expect(field.cells.where((c) => c.revealed).length, revealed);
      await tester.longPress(_tiles.at(0));
      await tester.tap(_tiles.at(2), buttons: kSecondaryMouseButton);
      await tester.pump();
      expect(field.flags, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'unmatched clue explains visible flag count and clears after a brief interval',
    (tester) async {
      await _pump(tester);
      final field = _field(tester)..plantMinesAt([0, 2, 4, 30, 35]);
      await tester.tap(_tiles.at(7));
      await tester.tap(_tiles.at(7));
      await tester.pump();
      expect(find.text('This 2 needs 2 flags (0 placed).'), findsOneWidget);
      expect(field.lost, isFalse);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('This 2 needs 2 flags (0 placed).'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('the visual card behind ? never starts a hidden board', (
    tester,
  ) async {
    final watch = FakeStopwatch();
    final tutorial = _Tutorial(seen: false);
    final platform = _Platform();
    await _pump(tester, watch: watch, tutorial: tutorial, platform: platform);
    // First launch: no card, the board is live.
    expect(find.byKey(const ValueKey('neighbor-example')), findsNothing);
    expect(platform.events, ['start']);
    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(find.byKey(const ValueKey('neighbor-example')), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    expect(platform.events, ['start', 'stop']);
    await tester.tap(_tiles.first, warnIfMissed: false);
    expect(_field(tester).armed, isFalse);
    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(tutorial.seen, isTrue);
    expect(platform.events, ['start', 'stop', 'start']);
    expect(watch.isRunning, isFalse);
    await tester.tap(_tiles.at(14));
    await tester.pump();
    expect(watch.isRunning, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'inactivity pauses clock, audio and events; overlays block foreground resume',
    (tester) async {
      final watch = FakeStopwatch();
      final platform = _Platform();
      final music = _Music();
      final sound = SoundFx(
        player: _Effects(),
        music: music,
        requiresUserInput: false,
      );
      await _pump(tester, watch: watch, platform: platform, sound: sound);
      await tester.tap(_tiles.at(14));
      await tester.pump();
      watch.advance(1500);
      _background(tester);
      await tester.pump();
      expect(watch.isRunning, isFalse);
      expect(platform.events, ['start', 'stop']);
      expect(music.events, ['start', 'pause']);
      watch.advance(6000);
      _foreground(tester);
      await tester.pump();
      expect(watch.elapsedMilliseconds, 1500);
      expect(watch.isRunning, isTrue);
      expect(platform.events, ['start', 'stop', 'start']);
      expect(music.events, ['start', 'pause', 'resume']);
      await tester.tap(find.byTooltip('How to play'));
      await tester.pump();
      _background(tester);
      _foreground(tester);
      await tester.pump();
      expect(watch.isRunning, isFalse);
      expect(platform.events, ['start', 'stop', 'start', 'stop']);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(watch.isRunning, isTrue);
      expect(platform.events, ['start', 'stop', 'start', 'stop', 'start']);
      await tester.pumpWidget(const SizedBox.shrink());
      sound.dispose();
    },
  );

  testWidgets('returning before the first dig rebuilds enabled controls', (
    tester,
  ) async {
    final tutorial = _LateTutorial();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: TinyMinesScreen(
          tutorialStore: tutorial,
          progressStore: MemoryGardenProgressStore(),
        ),
      ),
    );
    _background(tester);
    tutorial.release.complete(true);
    await tester.pumpAndSettle();
    _foreground(tester);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('flag-mode')));
    await tester.tap(_tiles.at(14));
    await tester.pump();
    expect(_field(tester).cells[14].flagged, isTrue);
    expect(_field(tester).armed, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [
    const Size(360, 760),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1280, 720),
  ]) {
    testWidgets('Dig/Flag controls and short help fit $size', (tester) async {
      await _pump(tester, size: size);
      for (final key in ['dig-mode', 'flag-mode']) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        expect(rect.width, greaterThanOrEqualTo(40));
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('How to play'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Skip'));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
