import 'package:flutter/material.dart';

import '../art/garden_palette.dart';

/// Where a first-time player is on their first board; picks the tip.
enum OnboardingStep {
  /// Nothing dug yet.
  start,

  /// The first dig happened; explain numbers and flags.
  numbers,

  /// The first flag is planted; explain the chord dig.
  chord,
}

/// Short, dismissible first-run tips shown above a playable board
/// (feature-first-run-onboarding). It never blocks input.
class OnboardingStrip extends StatelessWidget {
  const OnboardingStrip({
    super.key,
    required this.palette,
    required this.step,
    required this.onClose,
    this.compact = false,
  });

  final GardenPalette palette;
  final OnboardingStep step;
  final VoidCallback onClose;

  /// One smaller line pair for short screens.
  final bool compact;

  static (String, String) textFor(OnboardingStep step) => switch (step) {
    OnboardingStep.start => (
      'Start anywhere - your first dig is safe.',
      'Numbers count moles in all 8 patches around them.',
    ),
    OnboardingStep.numbers => (
      'A number counts the moles touching it.',
      'Flag a sure mole: right-click, long-press or Flag mode.',
    ),
    OnboardingStep.chord => (
      'Nice flag!',
      'Tap a number whose flags are all placed to dig the rest around it.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (title, body) = textFor(step);
    final titleSize = compact ? 12.5 : 14.0;
    final bodySize = compact ? 11.5 : 12.5;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: DecoratedBox(
          key: const ValueKey('onboarding-strip'),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              palette.flowerCenter.withValues(alpha: 0.28),
              palette.panel,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.flowerCenter, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              10,
              compact ? 4 : 6,
              2,
              compact ? 4 : 6,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tips_and_updates_rounded,
                  size: compact ? 18 : 22,
                  color: palette.textPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w900,
                          color: palette.textPrimary,
                        ),
                      ),
                      // Two lines tall for every tip, so the board below
                      // keeps its size when the tip changes.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              MediaQuery.textScalerOf(context).scale(bodySize) *
                              1.2 *
                              2,
                        ),
                        child: Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: bodySize,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Hide tips',
                  iconSize: 18,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  padding: EdgeInsets.zero,
                  color: palette.textSecondary,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
