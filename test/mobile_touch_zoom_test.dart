import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/mine_field.dart';
import 'package:tiny_mines/platform/game_platform.dart';
import 'package:tiny_mines/src/meta/garden_progress_store.dart';
import 'package:tiny_mines/src/ui/garden_board.dart';
import 'package:tiny_mines/src/ui/garden_cards.dart';

// feature-mobile-touch-zoom: board zoom and touch polish on phones.

class _Seen extends TutorialStore {
  @override
  Future<bool> hasSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

Finder get _tiles =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));
Finder get _toggle => find.byKey(const ValueKey('zoom-toggle'));
Finder get _viewer => find.byType(InteractiveViewer);

MineField _field(WidgetTester tester) =>
    tester.widget<GardenBoard>(find.byType(GardenBoard)).field;

double _scale(WidgetTester tester) => tester
    .widget<InteractiveViewer>(_viewer)
    .transformationController!
    .value
    .getMaxScaleOnAxis();

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(3),
        tutorialStore: _Seen(),
        progressStore: MemoryGardenProgressStore(),
        platform: NoopGamePlatform(allowsResultRegistration: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

/// Hidden, safe tiles whose centre is inside the zoom viewer.
List<int> _visibleSafe(WidgetTester tester) {
  final view = tester.getRect(_viewer).deflate(2);
  final field = _field(tester);
  return [
    for (var i = 0; i < field.cells.length; i++)
      if (!field.cells[i].revealed &&
          !field.cells[i].flagged &&
          !field.cells[i].mine &&
          view.contains(tester.getCenter(_tiles.at(i))))
        i,
  ];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Z1: only small-cell boards show the zoom toggle at 390x844', (
    tester,
  ) async {
    await _pump(tester);
    for (final (title, zoomable) in const [
      ('Easy 6x6', false),
      ('Normal 9x9', false),
      ('Hard 12x12', true),
      ('Expert 14x14', true),
      ('Easy 6x6', false),
    ]) {
      await _choose(tester, title);
      expect(_toggle, zoomable ? findsOneWidget : findsNothing, reason: title);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Z2/Z3: zoom in, dig and flag the cell under the finger, '
      'zoom out, and a new board starts unzoomed', (tester) async {
    await _pump(tester);
    await _choose(tester, 'Expert 14x14');
    // First dig in the middle; zooming in centres it.
    const centre = 7 * 14 + 7;
    await tester.tap(_tiles.at(centre));
    await tester.pumpAndSettle();
    final before = tester.getRect(_tiles.at(centre)).width;
    expect(before, lessThan(32));

    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(_scale(tester), greaterThan(1));
    expect(tester.getRect(_tiles.at(centre)).width, greaterThanOrEqualTo(40));
    expect(find.byTooltip('Zoom out'), findsOneWidget);
    final view = tester.getRect(_viewer);
    expect(view.contains(tester.getCenter(_tiles.at(centre))), isTrue);

    final safe = _visibleSafe(tester);
    expect(safe.length, greaterThanOrEqualTo(2));
    await tester.longPress(_tiles.at(safe.first));
    await tester.pumpAndSettle();
    expect(_field(tester).cells[safe.first].flagged, isTrue);
    await tester.tap(_tiles.at(safe.last));
    await tester.pumpAndSettle();
    expect(_field(tester).cells[safe.last].revealed, isTrue);
    expect(_field(tester).lost, isFalse);

    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(_scale(tester), 1);
    expect(find.byTooltip('Zoom in'), findsOneWidget);

    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(_scale(tester), greaterThan(1));
    await tester.tap(find.byTooltip('Restart'));
    await tester.pumpAndSettle();
    expect(_scale(tester), 1);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving a zoomable board resets the zoom', (tester) async {
    await _pump(tester);
    await _choose(tester, 'Hard 12x12');
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(_scale(tester), greaterThan(1));
    await _choose(tester, 'Easy 6x6');
    expect(_toggle, findsNothing);
    expect(_scale(tester), 1);
  });

  testWidgets('holding a hidden tile shrinks it until release', (tester) async {
    await _pump(tester);
    double held() => tester
        .widget<AnimatedScale>(
          find
              .descendant(
                of: find.byType(GridView),
                matching: find.byKey(const ValueKey('tile-hold')),
              )
              .first,
        )
        .scale;
    expect(held(), 1);
    final gesture = await tester.startGesture(tester.getCenter(_tiles.at(0)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(held(), lessThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(held(), 1);
  });

  testWidgets('Z6: Garden Run hearts show once, above the board', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Try Garden Run'));
    await tester.pumpAndSettle();
    expect(find.byType(GardenRunHud), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GardenRunHud),
        matching: find.byIcon(Icons.favorite_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('board-hearts')),
        matching: find.byIcon(Icons.favorite_rounded),
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('a board that ends while zoomed zooms back out', (tester) async {
    await _pump(tester);
    await _choose(tester, 'Expert 14x14');
    final field = _field(tester)..plantMinesAt([0, 106]);
    await tester.tap(_tiles.at(105));
    await tester.pumpAndSettle();
    expect(field.cells[105].nearby, greaterThan(0));
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(_scale(tester), greaterThan(1));
    await tester.tap(_tiles.at(106));
    await tester.pumpAndSettle();
    expect(field.lost, isTrue);
    expect(_scale(tester), 1);
  });

  testWidgets('Z4: an unmatched Flag mode tap on a number explains the count', (
    tester,
  ) async {
    await _pump(tester);
    final field = _field(tester)..plantMinesAt([0, 2, 4, 30, 35]);
    await tester.tap(_tiles.at(7));
    await tester.pump();
    final revealed = field.cells.where((c) => c.revealed).length;
    await tester.tap(find.byKey(const ValueKey('flag-mode')));
    await tester.tap(_tiles.at(7));
    await tester.pump();
    expect(find.text('This 2 needs 2 flags (0 placed).'), findsOneWidget);
    expect(field.cells.where((c) => c.revealed).length, revealed);
    expect(field.flags, 0);
    expect(field.lost, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
