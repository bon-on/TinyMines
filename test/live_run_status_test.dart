import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/src/art/garden_palette.dart';
import 'package:tiny_mines/src/meta/garden_plots.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/meta/garden_theme.dart';
import 'package:tiny_mines/src/ui/garden_cards.dart';

final _palette = GardenPalette.of(GardenTheme.values.first);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 300, child: child)),
      ),
    ),
  );
}

String _status(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('garden-run-status')))
    .data!;

bool _earned(WidgetTester tester, GardenPlot plot) => tester
    .widget<PlotTile>(
      find.byWidgetPredicate((w) => w is PlotTile && w.plot == plot),
    )
    .earned;

void main() {
  final fresh = GardenProgress.fromJson(const {});
  final withBest = GardenProgress.fromJson(const {'bestRunStage': 3});

  group('Garden Run card (R1)', () {
    Future<void> card(
      WidgetTester tester,
      GardenProgress progress, {
      required bool playing,
      int? stage,
    }) => _pump(
      tester,
      GardenRunCard(
        palette: _palette,
        progress: progress,
        playing: playing,
        runStage: stage,
        onStart: () {},
      ),
    );

    testWidgets('a first run shows its stage, not "No run yet"', (
      tester,
    ) async {
      await card(tester, fresh, playing: true, stage: 2);
      expect(_status(tester), 'Stage 2');
      expect(find.text('No run yet'), findsNothing);
    });

    testWidgets('a later run shows its stage and the saved best', (
      tester,
    ) async {
      await card(tester, withBest, playing: true, stage: 1);
      expect(_status(tester), 'Stage 1 - best 3');
    });

    testWidgets('without a run it shows the saved best or no run', (
      tester,
    ) async {
      await card(tester, fresh, playing: false, stage: 4);
      expect(_status(tester), 'No run yet');
      await card(tester, withBest, playing: false);
      expect(_status(tester), 'Best stage 3');
    });
  });

  group('Garden plots card (R2, R3)', () {
    testWidgets('reaching stage 2 shows the Sprout bed as earned', (
      tester,
    ) async {
      await _pump(
        tester,
        GardenPlotsCard(palette: _palette, progress: fresh, runStage: 1),
      );
      expect(_earned(tester, GardenPlot.sprouts), isFalse);
      expect(find.text('0/${GardenPlots.total}'), findsOneWidget);

      await _pump(
        tester,
        GardenPlotsCard(palette: _palette, progress: fresh, runStage: 2),
      );
      expect(_earned(tester, GardenPlot.sprouts), isTrue);
      expect(_earned(tester, GardenPlot.tulips), isFalse);
      expect(find.text('1/${GardenPlots.total}'), findsOneWidget);
      expect(find.textContaining('Next: Tulip row'), findsOneWidget);
    });

    testWidgets('a run below the saved best never hides earned plots', (
      tester,
    ) async {
      await _pump(
        tester,
        GardenPlotsCard(palette: _palette, progress: withBest, runStage: 1),
      );
      expect(_earned(tester, GardenPlot.sprouts), isTrue);
      expect(_earned(tester, GardenPlot.tulips), isTrue);
    });

    testWidgets('after the run the saved best drives the card', (
      tester,
    ) async {
      final saved = GardenProgress.fromJson(const {'bestRunStage': 2});
      await _pump(
        tester,
        GardenPlotsCard(palette: _palette, progress: saved),
      );
      expect(_earned(tester, GardenPlot.sprouts), isTrue);
      expect(find.text('1/${GardenPlots.total}'), findsOneWidget);
    });
  });
}
