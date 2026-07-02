import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/main.dart';

void main() {
  testWidgets('Tiny Mines renders the game board', (tester) async {
    await tester.pumpWidget(const TinyMinesApp());
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Tiny Mines'), findsOneWidget);
    expect(find.text('Mines'), findsOneWidget);
  });
}
