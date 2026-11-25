---
id: feature-board-first-phone-layout
title: Board-first phone layout with thumb-reach controls
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

# Board-first phone layout

## Problem

On 2026-11-25 the user found the board small next to the controls above it on a phone. Headless captures of the
CrazyGames build at a width of 390 showed:

| Window height | Layout | Board side |
|---|---|---|
| 844 | regular stacked | about 366 px (full width) |
| 720 | regular stacked | **about 210 px** |
| 640 | short stacked | about 300 px |

- **Cause:** windows from 700 px tall used the regular stacked layout. It stacks the title, stats, difficulty, the Garden Run
  strip, Dig/Flag, the tip strip, the hearts, the status line and the XP footer, and the board gets only what is left.
- **Who it hits:** phone browsers whose visible height is 650-750 px.
- Dig/Flag sat above the board, far from the thumb.

## Scope

Stacked layout (`_narrowLayout` in `lib/main.dart`, portrait and square windows)

- **Top:**
  - title and tool buttons;
  - stats;
  - the meta row: level badge, the Garden Run entry or live run status, and Daily and Garden as icon buttons;
  - unfolded only: the full-label difficulty picker.
- **Tip strip:** compact, and shown above the board while onboarding.
- **Below the board, in thumb reach:**
  - Unfolded: a Dig/Flag row (labelled buttons) with the zoom toggle, then the status line.
  - Folded: one row with the Dig, Flag (and zoom) icons beside the short-label difficulty picker. While the tips show, the
    status line is hidden (feedback and the end of a board still show it).
- **Removed rows:** the separate Garden Run strip and the XP footer. The level stays in the badge; XP stays on the result
  card and in My Garden.
- **Meta row text:**
  - Unfolded: the one-line run status (`GardenRunHud`) and long entry labels ("Garden Run - best stage N",
    "Garden Run - 3 hearts").
  - Folded: the two-line run status and short labels ("Garden Run - best N", "Garden Run").
- **When the layout folds:**
  - always below `shortStackedHeight` (700 px);
  - also when the unfolded board side comes out under `foldBoardShare` (0.9) of the available width.
- **Fold prediction:** the unfolded layout measures the height its rows cost around the board. It keys that cost by what
  changes it: the tip strip, a run (hearts row), the end-of-board button, and the width. Later builds predict the fold for
  any height from that cost, so resizing (for example a phone URL bar) draws the right layout in the first frame. Only the
  first visit to a new key draws one unfolded frame.
- **Compact "Try Garden Run" card:** 2 px vertical padding and 1.1 line height, so its two lines fit a slim row at full
  size; the subtitle ellipsizes instead of scaling.
- **Resume label:** the phone meta row uses "Resume Garden Run - stage N" without the hearts, so it stays at 11 px or more
  on 360 px phones. Wide layouts keep the hearts.

## Constraints

- The board stays square: the grids are N x N, and rectangular boards would change the rules.
- Game rules, saves, scoring, portal SDK use and the wide/compact layouts stay unchanged.
- `feature-short-viewport-layout` checks still hold for every stacked size:
  - no overflow;
  - the board does not intersect the controls;
  - labels are at least 11 px;
  - minimum board sides.
- The `feature-mobile-touch-zoom` toggle stays next to Dig/Flag.

## Acceptance Criteria

- B1: At 390x720 the board side is at least 0.9 x (390 - 24) px, both in the first-run Garden Run state and on Easy.
- B2: Dig and Flag sit below the board in every stacked window (390x720 to 320x568, and during a Garden Run).
- B5: Resizing between heights draws the final layout in the first frame at the new size.
- B6: With real Roboto, the first-run card subtitle (from 360 px wide) and the phone resume label (360 px) render at 11 px
  or more.
- B3: All existing layout, onboarding, Garden Run and garden tests pass. Tests that opened the garden by its label now use the
  Garden tooltip on stacked windows.
- B4: `flutter analyze` and `flutter test` pass.

## Requirement-to-check map

- B1, B2, B5, B6: `test/board_first_layout_test.dart` (loads the bundled Roboto).
- B3, B4: CI test command.

## Evidence

- reports/board-first-phone-layout-verification.md
