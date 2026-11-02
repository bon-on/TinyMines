import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/src/art/garden_palette.dart';
import 'package:tiny_mines/src/art/garden_scenery.dart';
import 'package:tiny_mines/src/art/garden_tile_art.dart';
import 'package:tiny_mines/src/meta/garden_theme.dart';

void main() {
  for (final theme in GardenTheme.values) {
    testWidgets('every tile look paints in ${theme.label}', (tester) async {
      final palette = GardenPalette.of(theme);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned.fill(child: GardenScenery(palette: palette)),
              Wrap(
                children: [
                  for (final look in TileLook.values)
                    for (final n
                        in look == TileLook.soil
                            ? List<int>.generate(9, (i) => i)
                            : const [0])
                      for (final size in const [14.0, 48.0])
                        SizedBox.square(
                          dimension: size,
                          child: CustomPaint(
                            painter: GardenTilePainter(
                              palette: palette,
                              look: look,
                              nearby: n,
                              seed: n * 3 + 2,
                            ),
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('palette lookups cover every theme and number', () {
    for (final theme in GardenTheme.values) {
      final p = GardenPalette.of(theme);
      for (var n = 1; n <= 8; n++) {
        expect(p.pebble(n), isNot(p.pebbleInk(n)));
      }
    }
    expect(GardenPalette.of(GardenTheme.night).isNight, isTrue);
    expect(GardenPalette.of(GardenTheme.winter).isFrost, isTrue);
  });

  test('tile painter repaints only on change', () {
    const a = GardenTilePainter(
      palette: GardenPalette.spring,
      look: TileLook.covered,
    );
    const b = GardenTilePainter(
      palette: GardenPalette.spring,
      look: TileLook.covered,
    );
    const c = GardenTilePainter(
      palette: GardenPalette.spring,
      look: TileLook.soil,
      nearby: 2,
    );
    expect(a.shouldRepaint(b), isFalse);
    expect(a.shouldRepaint(c), isTrue);
  });
}
