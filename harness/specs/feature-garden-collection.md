---
id: feature-garden-collection
title: Garden plot collection earned by Garden Run stages and daily clears
status: active
owner: games
related_adrs:
  - adr-tiny-mines-crazygames-web
  - adr-daily-practice
related_contracts:
  - contract-tiny-mines-gameplay
  - contract-tiny-mines-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - crazygames-build
  - gamepix-build
  - harness-audit
  - independent-review
---

# Garden plot collection

## Problem

Garden Run and the daily garden have records but nothing to collect. Sister games use small collection sets (MergeCamp
stickers, NonoGrid collection sets) as a visible long-term goal. Tiny Mines needs a collection that rewards its two distinct
modes and shows how far the player is.

## Scope

1. Eight garden plots in two sets, drawn in code (`CustomPainter`, no new asset files):
   - Run Path (Garden Run best stage): Sprout bed (stage 2), Tulip row (stage 3), Rose arch (stage 5), Sunflower patch
     (stage 7);
   - Daily Beds (scored daily clears): Mushroom ring (1), Lily pond (2), Berry bush (4), Bird bath (7).
   A plot is earned once its requirement is met and stays earned.
2. Progress: `garden_progress_v1` gains `dailyClears` (scored daily wins) and `rewardedSets` (set ids already paid). Missing
   or invalid values fall back: `dailyClears` is at least the number of won entries in the saved `daily` map (so old saves get
   credit), `rewardedSets` ignores unknown ids. Plots are derived from `bestRunStage` and `dailyClears`; no per-plot list is
   stored. Practice, already-recorded dailies and empty runs change nothing.
3. Set reward: when a set is complete and not yet rewarded, the next scored result (board, daily or run) adds a one-time XP
   bonus (Run Path 100 XP, Daily Beds 150 XP) through the existing XP/level/theme system and marks the set as rewarded.
4. Result card: "New plot: <name> (N/8)" for plots earned by this result (numbered one by one when several are earned) and "Set complete: <set> +X XP" for paid sets.
5. Collection view "Garden plots N/8" with the eight plots (earned in color, others as a dim outline with their requirement)
   and a next-goal line ("Next: reach stage 5 in Garden Run"). Shown in the My Garden sheet (narrow screens) and in the wide
   layout's right column. It never blocks the board.
6. Cloud save: the progress JSON already goes through `shared_preferences`, which the CrazyGames build routes to the Data
   module (`feature-crazygames-cloud-save`); no separate key.

## Acceptance Criteria

- C1: Plots and sets follow the table; `earned`, `next` and N/8 are correct at 0, partial and full progress.
- C2: A scored daily win increments `dailyClears` once; practice, a repeated daily and a daily loss do not. Garden Run
  `bestRunStage` drives the run plots.
- C3: Completing a set pays its bonus exactly once (also after reload); legacy saves that already qualify receive it at the
  next scored result; the bonus can level up and unlock a theme like any XP.
- C4: Old JSON without the new fields loads with derived `dailyClears`; corrupt values do not break loading; the JSON round
  trip keeps both fields.
- C5: The collection view and result pills render at 390x844, 1280x720, 1366x768 and 844x390 without overflow; every plot
  paints in all four themes without exceptions.

## Mapping

| Requirement | Files | Checks |
| --- | --- | --- |
| Plots, sets, rewards | lib/src/meta/garden_plots.dart, lib/src/meta/garden_progress.dart | test/garden_plots_test.dart |
| Art and view | lib/src/art/plot_art.dart, lib/src/ui/garden_cards.dart, lib/main.dart | widget/paint tests |
| Result pills, next goal | lib/src/ui/run_summary_overlay.dart, lib/src/meta/next_goal.dart | summary widget tests |

## Constraints

No new packages or asset files, English ASCII strings, no change to scoring, best times, daily scoring rules or Garden Run
rules. Storage stays tolerant and backward compatible.

## Evidence

`flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`, both portal build scripts, harness audit,
independent review, temporary screenshots.
