---
id: feature-mobile-touch-zoom
title: Board zoom and touch polish for phones
status: active
owner: games
related_adrs:
  - adr-tiny-mines-crazygames-web
related_contracts:
  - contract-tiny-mines-gameplay
required_evidence:
  - flutter-analyze
  - flutter-tests
  - crazygames-build
  - harness-audit
  - independent-review
---

# Board zoom and touch polish

## Problem

A 2026-11-25 check of the CrazyGames build at 390x844 found these touch problems:

- **Small cells.** Expert 14x14 cells are about 23 px and Hard 12x12 about 27 px, roughly half of the usual 44-48 px touch
  size. Players dig the wrong patch or flag a neighbour, and a long-press on such a small cell is hard to aim.
- **Silent long-press.** A long-press plants a flag only after about 0.5 s and nothing shows during the hold, so players do
  not learn that holding works.
- **Flag mode blocks the chord.** In Flag mode a tap on a number does nothing, so players switch back to Dig for every chord.
- **Misleading hint.** A tap on a flag in Dig mode says "Switch to Flag to remove this marker." although a long-press or a
  right-click also removes it.
- **Hearts twice.** During a Garden Run the hearts show in the run status and again in the large row above the board.
- **Tight label.** The selected "Expert 14x14" pill nearly touches the edges of its segment.

## Scope

Zoom (`lib/main.dart`, `lib/src/ui/garden_board.dart`)
- A board is *zoomable* when its cell side is under `zoomCellThreshold` (32 px). Normal 9x9 at 390x844 (about 37 px) is not.
- A zoomable board pinch-zooms and pans: an `InteractiveViewer` from 1x up to `maxBoardZoom` (3x) inside the board frame. It
  wraps the grid and the effects layer, so the effects stay on their cells. The frame does not scale. A tap or long-press on
  a zoomed board acts on the cell under the finger.
- A zoom toggle (key `zoom-toggle`, tooltip "Zoom in" or "Zoom out") shows next to Dig/Flag only while the board is zoomable:
  - at the end of the Dig/Flag row (tall stacked and wide);
  - in the Dig/Flag icon row, where all three icons are 38 px (short stacked);
  - below Flag (short-wide column);
  - in the compact column, Dig, Flag and the toggle become one row of 36 px icons, so the column does not grow.

  These sizes keep the difficulty labels at 11 px or more.
  - Zoom in scales to about 44 px cells (`clamp(44 / cell, 1.6, maxBoardZoom)`). It centres the last dug or flagged patch, or
    the board centre before the first move, clamped so the board edge never shows past the frame.
  - Zoom out returns to 1x.
  - The icon follows the current scale, including after a pinch.
- These return the board to 1x:
  - every new board (restart, difficulty, daily, Garden Run stage, checkpoint resume);
  - every change that makes the board non-zoomable;
  - the end of a board and a lost Garden Run heart, so the end effects, the heart-loss label and the stage banner are seen
    whole.
- The grid clips to the bed only while zoomed. Unzoomed, effects may spill onto the frame as before.
- On desktop, a zoomable board also zooms with the mouse wheel and pans with a trackpad scroll. Clicks and right-clicks are
  unchanged.

Touch polish
- Holding a hidden or flagged cell shrinks it slightly over the long-press time, so the hold is visible. A long-press or
  right-click flag toggle sends a light haptic (`HapticFeedback.mediumImpact`, a no-op where unsupported), and so does a
  Flag mode tap.
- In Flag mode a tap on a revealed number chords like in Dig mode. Other Flag mode taps are unchanged.
- The Dig mode hint on a flag reads "Long-press, right-click or Flag mode removes this marker."
- The run status (`GardenRunHud`) shows the stage and the run clock only. The large hearts row above the board stays the one
  hearts display, in every layout.
- Difficulty segment padding stays at 2 px. 4 and 6 px were tried, but they push the labels under the 11 px minimum of
  `feature-short-viewport-layout` (10.8 px at 390x844, 10.0 px at 560x315). The tight pill stays as a known cosmetic issue.

## Constraints

- Game rules, generators, saves, scoring, XP, dailies, portal SDK calls and checkpoints stay as they are. Zoom is view-only
  and is not saved. No new dependencies or assets.
- Layouts keep the `feature-short-viewport-layout` guarantees: no overflow, and the board does not intersect the controls.
- Keyboard play is unchanged. Mouse clicks are unchanged; only the wheel zooms, on zoomable boards.

## Acceptance Criteria

- Z1: At 390x844, Expert and Hard boards show the zoom toggle; Easy and Normal do not.
- Z2: Zoom in reaches a scale > 1 with cells of at least 40 px on screen. A tap then digs the cell under the finger, and a
  long-press flags the cell under the finger.
- Z3: Zoom out returns to scale 1. A new board after zooming starts at scale 1. A board that ends while zoomed returns to
  scale 1.
- Z4: A Flag mode tap on a number whose flags match its count opens its neighbours. If the flags do not match, the tap
  shows the R4 count feedback and changes nothing.
- Z5: A Dig mode tap on a flag shows the new hint text.
- Z6: During a Garden Run the hearts appear once, in the row above the board, and none appear in `GardenRunHud`.
- Z7: `flutter analyze` and `flutter test` pass, including the short-viewport layout checks.

## Requirement-to-check map

- Z1-Z3: `test/mobile_touch_zoom_test.dart`.
- Z4-Z5: `test/mobile_touch_zoom_test.dart`, `test/quality_recovery_test.dart`.
- Z6: `test/garden_run_screen_test.dart`, `test/garden_tools_screen_test.dart`.
- Z7: CI test command.

## Evidence

- reports/mobile-touch-zoom-verification.md
