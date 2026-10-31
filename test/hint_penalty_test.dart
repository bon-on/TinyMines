import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/main.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({'tutorial_seen_v1': true}),
  );

  testWidgets('a hint adds its time penalty to the clock', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: TinyMinesScreen(random: math.Random(1))),
    );

    final tiles = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(InkWell),
    );
    await tester.tap(tiles.first);
    await tester.pump();
    expect(find.text('0:00'), findsOneWidget);

    await tester.tap(find.byTooltip('Reveal one safe tile (+10s)'));
    await tester.pump();
    expect(find.text('0:10'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
