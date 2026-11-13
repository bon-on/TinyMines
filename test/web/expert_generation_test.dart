// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/src/game/fair_field.dart';

void main() {
  test('Expert generation is guess-free and fast in the browser build', () {
    final watch = Stopwatch()..start();
    var attempts = 0;
    var worst = 0;
    const boards = 40;
    for (var seed = 0; seed < boards; seed++) {
      final each = Stopwatch()..start();
      final random = math.Random(seed);
      final layout = FairField.generate(
        size: 14,
        mineCount: 40,
        start: random.nextInt(196),
        random: random,
      );
      expect(layout.verified, isTrue, reason: 'seed $seed');
      attempts += layout.attempts;
      if (each.elapsedMilliseconds > worst) worst = each.elapsedMilliseconds;
    }
    // ignore: avoid_print
    print(
      'EXPERT web: ${watch.elapsedMilliseconds / boards} ms/board avg, '
      'worst $worst ms, ${attempts / boards} attempts avg',
    );
    expect(worst, lessThan(1500));
  });
}
