import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/platform/game_platform.dart';
import 'package:tiny_mines/src/art/garden_palette.dart';
import 'package:tiny_mines/src/art/garden_tile_art.dart';
import 'package:tiny_mines/src/meta/garden_progress_store.dart';
import 'package:tiny_mines/src/meta/garden_theme.dart';
import 'package:tiny_mines/src/ui/board_fx.dart';
import 'package:tiny_mines/src/ui/garden_board.dart';

import 'support/fake_stopwatch.dart';

/// feature-game-feel-polish: number pop, banners, flag-mode frame and
/// stable board size.

class _Tutorial extends TutorialStore {
  _Tutorial(this.seen);
  final bool seen;
  @override
  Future<bool> hasSeen() async => seen;
  @override
  Future<void> markSeen() async {}
}

Finder get _tiles =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));
Finder get _board => find.byKey(const ValueKey('garden-board'));

Future<void> _pump(WidgetTester tester, Size size, {bool seen = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(1),
        progressStore: MemoryGardenProgressStore(),
        tutorialStore: _Tutorial(seen),
        stopwatch: FakeStopwatch(),
        now: () => DateTime(2026, 11, 2, 9),
        platform: const NoopGamePlatform(allowsResultRegistration: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('small cells get a larger clue', () {
    expect(GardenTileArt.numberShare(22), greaterThan(0.5));
    expect(
      GardenTileArt.numberShare(22),
      greaterThan(GardenTileArt.numberShare(34)),
    );
    expect(GardenTileArt.numberShare(60), 0.44);
  });

  testWidgets('a revealed clue keeps the effect running for its pop', (
    tester,
  ) async {
    final fx = BoardFx();
    addTearDown(fx.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox.square(
          dimension: 200,
          child: BoardFxLayer(
            fx: fx,
            palette: GardenPalette.of(GardenTheme.spring),
            size: 2,
            gap: 4,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    fx.reveal([(cell: 0, delayMs: 0)], numbers: {0: 2});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Past the 280 ms grass pop, the pebble is still growing.
    expect(fx.isActive, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(fx.isActive, isFalse);

    fx.banner(const FxBanner(kind: FxBannerKind.stage, title: 'A'));
    fx.banner(const FxBanner(kind: FxBannerKind.cleared, title: 'B'));
    await tester.pump();
    expect(fx.bannerState?.banner.title, 'B');
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 16));
    expect(fx.bannerState, isNull);
    expect(find.text('B'), findsNothing);
  });

  testWidgets('Flag mode colours the board frame', (tester) async {
    await _pump(tester, const Size(390, 844), seen: true);
    GardenBoard board() => tester.widget<GardenBoard>(find.byType(GardenBoard));
    expect(board().flagMode, isFalse);
    await tester.tap(find.byKey(const ValueKey('flag-mode')));
    await tester.pump();
    expect(board().flagMode, isTrue);
    await tester.tap(find.byKey(const ValueKey('dig-mode')));
    await tester.pump();
    expect(board().flagMode, isFalse);
  });

  testWidgets('the board keeps its size through the first dig and tips', (
    tester,
  ) async {
    await _pump(tester, const Size(390, 844));
    final before = tester.getSize(_board);
    await tester.tap(_tiles.at(0));
    await tester.pumpAndSettle();
    expect(tester.getSize(_board), before);
    // A long chord message does not resize it either.
    await tester.tap(find.byKey(const ValueKey('flag-mode')));
    await tester.pump();
    expect(tester.getSize(_board), before);
  });

  for (final size in const [
    Size(1280, 720),
    Size(1366, 768),
    Size(390, 844),
    Size(844, 390),
  ]) {
    testWidgets('a 12x12 board fits with readable cells at $size', (
      tester,
    ) async {
      await _pump(tester, size, seen: true);
      await tester.tap(find.text('Hard 12x12'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final cell = tester.getSize(_tiles.first);
      expect(cell.width, greaterThanOrEqualTo(size.height < 500 ? 18 : 24));
      final rect = tester.getRect(_board);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      expect(find.byKey(const ValueKey('dig-mode')), findsOneWidget);
      expect(find.byKey(const ValueKey('flag-mode')), findsOneWidget);
    });
  }

  for (final size in const [Size(844, 320), Size(844, 300), Size(1000, 300)]) {
    testWidgets('very short landscape does not overflow at $size', (
      tester,
    ) async {
      await _pump(tester, size);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Hard 12x12'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('short landscape keeps Dig/Flag beside a larger board', (
    tester,
  ) async {
    await _pump(tester, const Size(844, 390), seen: true);
    final board = tester.getRect(_board);
    final dig = tester.getRect(find.byKey(const ValueKey('dig-mode')));
    expect(board.width, greaterThanOrEqualTo(220));
    expect(dig.right, lessThanOrEqualTo(board.left));
    expect(tester.takeException(), isNull);
  });
}
