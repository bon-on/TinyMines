import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/platform/game_platform.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/meta/garden_progress_store.dart';
import 'package:tiny_mines/src/ui/garden_ui.dart';

import 'support/fake_stopwatch.dart';

// feature-large-screen-scale: the wide layout grows with big windows.

class _Tutorial extends TutorialStore {
  @override
  Future<bool> hasSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

Finder get _board => find.byKey(const ValueKey('garden-board'));
Finder get _tiles =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(1),
        progressStore: MemoryGardenProgressStore(
          GardenProgress.fromJson({'runsPlayed': 1, 'bestRunStage': 3}),
        ),
        tutorialStore: _Tutorial(),
        stopwatch: FakeStopwatch(),
        now: () => DateTime(2026, 11, 2, 9),
        platform: const NoopGamePlatform(allowsResultRegistration: false),
        gardenTools: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// On-screen size of the board (after the layout scale).
Size _globalSize(WidgetTester tester) {
  final tl = tester.getTopLeft(_board);
  final br = tester.getBottomRight(_board);
  return Size(br.dx - tl.dx, br.dy - tl.dy);
}

/// Value text of the stat tile labelled [label].
String _statValue(WidgetTester tester, String label) {
  final tile = find.ancestor(
    of: find.text(label),
    matching: find.byType(StatTile),
  );
  final texts = tester
      .widgetList<Text>(find.descendant(of: tile, matching: find.byType(Text)))
      .map((t) => t.data)
      .toList();
  return texts.firstWhere((t) => t != label)!;
}

void main() {
  test('scale is 1 up to the design size and capped above it', () {
    expect(wideScaleFor(const Size(1100, 620)), 1);
    expect(wideScaleFor(const Size(1280, 720)), 1);
    expect(wideScaleFor(const Size(1920, 1080)), 1.5);
    expect(wideScaleFor(const Size(2560, 1440)), maxWideScale);
    expect(wideScaleFor(const Size(1920, 720)), 1);
  });

  testWidgets('big windows scale the board and keep relative positions', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 720));
    final small = _globalSize(tester);
    final smallTopLeft = tester.getTopLeft(_board);

    // 1920x1080 is exactly 1.5x the design size: the same arrangement, with
    // the board's corner at the scaled position.
    await _pump(tester, const Size(1920, 1080));
    expect(_globalSize(tester).width, closeTo(small.width * 1.5, 1));
    final topLeft = tester.getTopLeft(_board);
    expect(topLeft.dx, closeTo(smallTopLeft.dx * 1.5, 1));
    expect(topLeft.dy, closeTo(smallTopLeft.dy * 1.5, 1));

    // 2560x1440 is capped at 1.6x (laid out at 1600x900, so the board also
    // gets a little more room before the scale).
    await _pump(tester, const Size(2560, 1440));
    expect(
      _globalSize(tester).width,
      greaterThanOrEqualTo(small.width * maxWideScale - 1),
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(1100, 620),
    Size(1366, 768),
    Size(1600, 900),
    Size(2560, 1440),
    Size(2560, 1080),
  ]) {
    testWidgets('no overflow at $size', (tester) async {
      await _pump(tester, size);
      expect(_board, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('right click and long press flag the cell under them', (
    tester,
  ) async {
    await _pump(tester, const Size(1920, 1080));
    await tester.tap(_tiles.at(14));
    await tester.pumpAndSettle();
    final flags = _statValue(tester, 'Flags');
    expect(flags, '0');
    // Find a patch that is still hidden: right click flags it, a long press
    // on the same patch removes the flag again.
    var flagged = -1;
    for (var i = 35; i >= 0 && flagged < 0; i--) {
      await tester.tap(_tiles.at(i), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      if (_statValue(tester, 'Flags') == '1') flagged = i;
    }
    expect(flagged, isNonNegative);
    await tester.longPress(_tiles.at(flagged));
    await tester.pumpAndSettle();
    expect(_statValue(tester, 'Flags'), '0');
  });

  testWidgets('a tap in the scaled layout digs that cell', (tester) async {
    await _pump(tester, const Size(1920, 1080));
    const armed =
        'Dig mode: tap to dig. Numbers count moles in all 8 neighbors.';
    expect(find.text(armed), findsNothing);
    await tester.tap(_tiles.at(14));
    await tester.pumpAndSettle();
    // The first dig is always safe and arms the field.
    expect(find.text(armed), findsOneWidget);
    expect(_statValue(tester, 'Moves'), '1');
  });
}
