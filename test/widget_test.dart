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
}
