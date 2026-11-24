import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/src/art/garden_palette.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/meta/garden_theme.dart';
import 'package:tiny_mines/src/ui/run_summary_overlay.dart';

RunReport _report(int xpBefore, {int cleared = 1}) {
  final outcome =
      GardenProgress.fromJson({
        'totalXp': xpBefore,
        'runsPlayed': 1,
      }).applyGardenRun(
        GardenRunResult(
          stageReached: cleared + 1,
          stagesCleared: cleared,
          participated: true,
        ),
      );
  return RunReport.garden(
    stageReached: cleared + 1,
    stagesCleared: cleared,
    seconds: 80,
    outcome: outcome,
  );
}

/// Shows the card for [report] in a host that keeps the selected theme, like
/// the game screen does.
Future<List<GardenTheme>> _show(
  WidgetTester tester,
  RunReport report, {
  GardenTheme selected = GardenTheme.spring,
  Size size = const Size(800, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final used = <GardenTheme>[];
  var current = selected;
  await tester.pumpWidget(
    MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: RunSummaryOverlay(
            report: report,
            palette: GardenPalette.of(current),
            onPlayAgain: () {},
            onClose: () {},
            delay: Duration.zero,
            now: DateTime(2026, 11, 24, 12),
            selectedTheme: current,
            onUseTheme: (theme) {
              used.add(theme);
              setState(() => current = theme);
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return used;
}

Finder get _reveal => find.byKey(const ValueKey('theme-reveal'));

void main() {
  test('R1: themes unlock at Lv 1, 2, 4 and 6', () {
    expect(GardenTheme.values.map((t) => t.requiredLevel), [1, 2, 4, 6]);
    final fresh = GardenProgress.fromJson(const {'totalXp': 100});
    expect(fresh.level, 2);
    expect(fresh.isThemeUnlocked(GardenTheme.autumn), isTrue);
    expect(fresh.isThemeUnlocked(GardenTheme.winter), isFalse);
  });

  testWidgets('R2/R3: an unlock shows the reveal and switches on tap', (
    tester,
  ) async {
    final used = await _show(tester, _report(90));
    expect(_reveal, findsOneWidget);
    expect(
      find.descendant(of: _reveal, matching: find.text('Autumn')),
      findsOneWidget,
    );
    expect(find.text('New theme: Autumn'), findsNothing);
    await tester.ensureVisible(find.text('Use Autumn'));
    await tester.tap(find.text('Use Autumn'));
    await tester.pumpAndSettle();
    expect(used, [GardenTheme.autumn]);
    expect(find.text('Using Autumn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('R3: an already selected theme reads "Using"', (tester) async {
    await _show(tester, _report(90), selected: GardenTheme.autumn);
    expect(find.text('Using Autumn'), findsOneWidget);
    expect(find.text('Use Autumn'), findsNothing);
  });

  testWidgets('R2: a result that unlocks nothing shows no reveal', (
    tester,
  ) async {
    await _show(tester, _report(0));
    expect(_reveal, findsNothing);
  });

  testWidgets('R4: several unlocks reveal the highest, pills for the rest', (
    tester,
  ) async {
    // 90 XP + a long run lands past Lv 4: Autumn and Winter at once.
    final report = _report(90, cleared: 22);
    expect(report.outcome.newlyUnlockedThemes, [
      GardenTheme.autumn,
      GardenTheme.winter,
    ]);
    await _show(tester, report);
    expect(
      find.descendant(of: _reveal, matching: find.text('Winter')),
      findsOneWidget,
    );
    expect(find.text('New theme: Autumn'), findsOneWidget);
    expect(find.text('New theme: Winter'), findsNothing);
  });

  for (final size in const [Size(844, 390), Size(560, 315), Size(390, 700)]) {
    testWidgets('the reveal fits the card at $size', (tester) async {
      await _show(tester, _report(90), size: size);
      expect(tester.takeException(), isNull);
      expect(_reveal, findsOneWidget);
      final button = tester.getRect(find.text('New Run'));
      expect(button.bottom, lessThanOrEqualTo(size.height));
    });
  }
}
