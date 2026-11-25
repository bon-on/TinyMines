import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/platform/game_platform.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/meta/garden_progress_store.dart';
import 'package:tiny_mines/src/ui/garden_cards.dart';

// feature-board-first-phone-layout.

class _Tutorial extends TutorialStore {
  _Tutorial(this.seen);
  final bool seen;
  @override
  Future<bool> hasSeen() async => seen;
  @override
  Future<void> markSeen() async {}
}

final _returning = GardenProgress.fromJson(const {
  'totalXp': 120,
  'runsPlayed': 2,
  'bestRunStage': 3,
});

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  required bool fresh,
  GardenProgress? progress,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(2),
        tutorialStore: _Tutorial(!fresh),
        progressStore: MemoryGardenProgressStore(
          progress ?? (fresh ? const GardenProgress.initial() : _returning),
        ),
        platform: NoopGamePlatform(allowsResultRegistration: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _tiles =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));

/// Folded layouts name the difficulty "Hard" instead of "Hard 12x12".
Finder get _shortPicker => find.text('Hard');

void _expectBelowBoard(WidgetTester tester, Size size) {
  final board = tester.getRect(find.byKey(const ValueKey('garden-board')));
  for (final key in const ['dig-mode', 'flag-mode']) {
    final rect = tester.getRect(find.byKey(ValueKey(key)));
    expect(rect.top, greaterThanOrEqualTo(board.bottom), reason: key);
    expect(rect.bottom, lessThanOrEqualTo(size.height), reason: key);
  }
}

/// Rendered line height of [text]. Roboto lines are about 1.1-1.17 x the
/// font size, so 12.1 px or more means at least 11 px type.
double _lineHeight(WidgetTester tester, Finder text) =>
    tester.getRect(text).height;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Real Roboto, so label widths (and any scaling) match the web build.
  setUpAll(() async {
    final roboto = FontLoader('Roboto');
    for (final weight in ['Regular', 'Medium', 'Bold', 'Black']) {
      roboto.addFont(rootBundle.load('assets/fonts/Roboto-$weight.ttf'));
    }
    await roboto.load();
  });

  for (final size in const [
    Size(390, 720),
    Size(390, 760),
    Size(390, 844),
    Size(360, 700),
    Size(360, 640),
    Size(320, 568),
  ]) {
    for (final fresh in [true, false]) {
      testWidgets('B1/B2 at $size (${fresh ? 'first run' : 'returning'})', (
        tester,
      ) async {
        await _pump(tester, size, fresh: fresh);
        expect(tester.takeException(), isNull);
        final board = tester.getRect(
          find.byKey(const ValueKey('garden-board')),
        );
        if (size.height >= 700) {
          expect(
            board.width,
            greaterThanOrEqualTo(0.9 * (size.width - 24) - 0.5),
            reason: 'board side at $size',
          );
        }
        _expectBelowBoard(tester, size);
        if (fresh && size.width >= 360) {
          // The first-run call to action stays readable (>= 11 px).
          expect(
            _lineHeight(tester, find.text(GardenRunCta.subtitle)),
            greaterThanOrEqualTo(12.1),
          );
        }
      });
    }
  }

  testWidgets('B2: Dig/Flag stay below the board during a Garden Run', (
    tester,
  ) async {
    for (final size in const [Size(390, 720), Size(360, 640)]) {
      await _pump(tester, size, fresh: false);
      await tester.tap(find.textContaining('Garden Run - best'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('board-hearts')), findsOneWidget);
      expect(tester.takeException(), isNull);
      _expectBelowBoard(tester, size);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('resizing predicts the fold without an unfolded frame', (
    tester,
  ) async {
    await _pump(tester, const Size(390, 720), fresh: true);
    expect(_shortPicker, findsOneWidget, reason: 'folded at 390x720');
    for (final height in const [721.0, 725.0, 1000.0, 722.0]) {
      tester.view.physicalSize = Size(390, height);
      await tester.pump();
      // The first frame at the new size is already the final layout.
      final first = _shortPicker.evaluate().isNotEmpty;
      await tester.pumpAndSettle();
      expect(_shortPicker.evaluate().isNotEmpty, first, reason: '$height');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the resume label stays readable on a 360 px phone', (
    tester,
  ) async {
    // Play one dig of a run, then come back with the saved checkpoint.
    final store = MemoryGardenProgressStore(_returning);
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget screen() => MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(2),
        tutorialStore: _Tutorial(true),
        progressStore: store,
        platform: NoopGamePlatform(allowsResultRegistration: false),
      ),
    );
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Garden Run - best'));
    await tester.pumpAndSettle();
    await tester.tap(_tiles.at(12));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    final text = resumeRunLabel(store.value, withHearts: false);
    expect(text, isNotNull);
    final label = find.text(text!);
    expect(label, findsOneWidget);
    expect(_lineHeight(tester, label), greaterThanOrEqualTo(12.1));
  });
}
