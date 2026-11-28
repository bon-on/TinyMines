import 'dart:math';

import 'garden_run.dart';

/// A reward picked between Garden Run stages (feature-garden-tools).
enum GardenTool {
  sunflower('Sunflower', '+1 heart now'),
  lantern('Lantern', '+2 hints now'),
  clover('Lucky clover', 'The next mole you dig costs no heart'),
  can('Watering can', 'After your next first dig, a safe patch opens');

  const GardenTool(this.label, this.blurb);

  final String label;
  final String blurb;
}

/// Offer rules for [GardenTool]s. Pure so it can be tested without widgets.
class GardenTools {
  const GardenTools._();

  /// How many tools one offer shows.
  static const int offerSize = 3;

  /// Hints a run may hold once Lanterns are in play.
  static const int maxHints = 7;
  static const int lanternHints = 2;

  /// Stored (consumable) tools stack up to this many.
  static const int maxCharges = 2;

  static bool eligible(GardenTool tool, GardenRunState run) => switch (tool) {
    GardenTool.sunflower => run.hearts < GardenRun.maxHearts,
    GardenTool.lantern => run.hints < maxHints,
    GardenTool.clover => run.clovers < maxCharges,
    GardenTool.can => run.cans < maxCharges,
  };

  /// A tool is offered after every [offerEvery]-th cleared stage (2, 4, 6…):
  /// one after every stage made long runs too easy.
  static const int offerEvery = 2;

  /// Whether the stage just cleared (the run now has [cleared] clears)
  /// earns a tool offer when offers come every [every] clears.
  static bool offersAfter(int cleared, {int every = offerEvery}) {
    assert(every > 0, 'offers need a positive cadence');
    return every > 0 && cleared > 0 && cleared % every == 0;
  }

  /// Up to [offerSize] distinct eligible tools, chosen with [random].
  static List<GardenTool> offer(GardenRunState run, Random random) {
    final pool = [
      for (final tool in GardenTool.values)
        if (eligible(tool, run)) tool,
    ]..shuffle(random);
    return pool.take(offerSize).toList(growable: false);
  }
}
