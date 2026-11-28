import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/src/game/garden_run.dart';
import 'package:tiny_mines/src/game/garden_tools.dart';

void main() {
  test('offers come after every second cleared stage', () {
    expect(GardenTools.offerEvery, 2);
    expect(
      [for (var c = 0; c <= 6; c++) GardenTools.offersAfter(c)],
      [false, false, true, false, true, false, true],
    );
    expect(GardenTools.offersAfter(1, every: 1), isTrue);
  });

  group('offers', () {
    test('three distinct eligible tools, never an ineligible one', () {
      for (var seed = 0; seed < 60; seed++) {
        const run = GardenRunState(); // full hearts, no tools
        final offer = GardenTools.offer(run, math.Random(seed));
        expect(offer.length, 3);
        expect(offer.toSet().length, 3);
        expect(offer, isNot(contains(GardenTool.sunflower)));
      }
    });

    test('sunflower is offered once a heart is missing', () {
      final run = const GardenRunState().loseHearts();
      var seen = false;
      for (var seed = 0; seed < 40; seed++) {
        seen |= GardenTools.offer(
          run,
          math.Random(seed),
        ).contains(GardenTool.sunflower);
      }
      expect(seen, isTrue);
    });

    test('capped tools leave the pool and a small pool offers fewer', () {
      var run = const GardenRunState(clovers: 2, cans: 2, hints: 7);
      expect(GardenTools.offer(run, math.Random(1)), isEmpty);
      run = run.loseHearts();
      expect(GardenTools.offer(run, math.Random(1)), [GardenTool.sunflower]);
    });

    test('the same random source gives the same offer', () {
      const run = GardenRunState();
      expect(
        GardenTools.offer(run, math.Random(9)),
        GardenTools.offer(run, math.Random(9)),
      );
    });
  });

  group('taking a tool', () {
    test('sunflower heals one heart but never past three', () {
      final hurt = const GardenRunState().loseHearts(2);
      expect(hurt.take(GardenTool.sunflower).hearts, 2);
      const full = GardenRunState();
      expect(full.take(GardenTool.sunflower).hearts, 3);
    });

    test('lantern adds two hints up to seven', () {
      expect(const GardenRunState().take(GardenTool.lantern).hints, 5);
      expect(const GardenRunState(hints: 6).take(GardenTool.lantern).hints, 7);
      expect(const GardenRunState(hints: 7).take(GardenTool.lantern).hints, 7);
    });

    test('clover and can stack to two and clear stage keeps them', () {
      var run = const GardenRunState()
          .take(GardenTool.clover)
          .take(GardenTool.clover)
          .take(GardenTool.clover)
          .take(GardenTool.can);
      expect(run.clovers, 2);
      expect(run.cans, 1);
      run = run.clearStage();
      expect(run.clovers, 2);
      expect(run.cans, 1);
      expect(run.stage, 2);
    });

    test('using tools never goes below zero', () {
      var run = const GardenRunState(clovers: 1, cans: 1);
      run = run.useClovers(5).useCan().useCan();
      expect(run.clovers, 0);
      expect(run.cans, 0);
    });
  });
}
