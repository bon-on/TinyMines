import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_mines/main.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({'tutorial_seen_v1': true}),
  );

  testWidgets('Tiny Mines renders the game board', (tester) async {
    await tester.pumpWidget(const TinyMinesApp());
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Tiny Mines'), findsOneWidget);
    expect(find.text('Mines'), findsOneWidget);
  });

  testWidgets('the title stays on one line at 360px width', (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TinyMinesApp());
    await tester.pump();

    final title = tester.getRect(find.text('Tiny Mines'));
    expect(title.height, lessThan(40));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
