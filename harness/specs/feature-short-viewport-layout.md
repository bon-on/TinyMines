---
id: feature-short-viewport-layout
title: Short viewport layout - board first in small portal iframes
status: active
owner: games
related_adrs:
  - adr-tiny-mines-crazygames-web
related_contracts:
  - contract-tiny-mines-gamepix
  - contract-tiny-mines-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - chrome-sdk-tests
  - gamepix-build
  - crazygames-build
  - harness-audit
  - independent-review
---

# Feature: Short viewport layout

## Problem
The layout chose the side-panel (wide) arrangement only for windows at least
760 px wide and 1.25 times wider than tall. Every other window used the
one-column phone arrangement. In the GamePix preview "Small" frame (620x349)
and other short landscape iframes (600x338, 560x315, 667x375) the header,
stats, difficulty, Garden Run entry, Dig/Flag, status and footer rows needed
more than the window height: the board box was 0 px and the column overflowed
by 43-103 px. At 640x480 (the GamePix minimum) the board was 63 px (9 px at
12x12) and the first-run screen overflowed by 14 px. Short portrait phones
were cramped too: at 320x568 the first-run board was 79 px and a Garden Run
board 97 px (6 px cells at 12x12). The earlier checks only covered 1280x720,
1366x768, 390x844 and 844x390 (and 844x320/844x300/1000x300 for overflow).
The sister game NonoGrid had the same bug in the same frame.

## Scope
Layout selection (`screenLayoutFor` in `lib/main.dart`)
- `wide` (unchanged): width >= 760 and width >= 1.25 x height.
- `compact` (new): any other window wider than tall, e.g. 620x349, 600x338,
  560x315, 640x480, 667x375. Board first: a 160 px left column (level badge
  and title; How to play, Sound, Hint and Restart as 38 px icon buttons with
  tooltips; Garden Run entry or a compact run status "Stage N / Run m:ss" with
  the BOSS tag; Mines/Flags/Moves/Time/Best tiles; a three-line status; the
  New Field / Next stage / New Run button after a board), the board in the
  middle with the first-run tip strip above it, and a 118 px right column
  (Dig, Flag, the vertical difficulty picker, Daily and Garden). Both columns
  are laid out at their width and only scale down (FittedBox) when taller
  than the window.
- `stacked` for portrait and square windows. Windows under 700 px tall
  (`shortStackedHeight`) fold the controls: one row with the level badge, the
  Garden Run entry (or run status), Daily and Garden as icon buttons; one row
  with Dig and Flag as icon toggles (tooltips "Dig"/"Flag", semantics keys
  `dig-mode`/`flag-mode` with the selected state) beside the difficulty
  picker; no XP footer; the compact tip strip takes the status line's place
  while it is shown (feedback and the end of a board still show the status).
  Taller stacked windows (390x844) keep the existing arrangement.
- Icon buttons smaller than 44 px use their visual size as the tap target
  (`MaterialTapTargetSize.shrinkWrap`); 44 px and larger keep the padded
  48 px target.

Board fit
- The board stays square and is sized to the box left for it (unchanged
  `_board`); it is never drawn over neighbouring controls. Garden Run keeps
  its large hearts row above the board in every layout.
- 12x12 cells (Hard and Garden Run stage 10 on) are at least 14 px at every
  supported size.

Result card
- On card boxes under 300 px tall (620x349, 600x338, 560x315) the card hides
  the tile art and uses regular (not large) stat tiles; on windows under
  380 px tall it uses slimmer margins, so the XP row shows above the pinned
  actions.

Out of scope: game rules, saves, generators, dailies, scoring, portal SDKs,
portal websites, new dependencies. The wide layout (844x390 and up) is
unchanged.

## Acceptance Criteria
- A1: `screenLayoutFor` returns `compact` for 620x349, 600x338, 560x315,
  640x480, 667x375; `wide` for 844x390, 932x430, 1280x720, 1366x768;
  `stacked` for 360x640, 390x844, 320x568, 800x800.
- A2: `test/short_viewport_layout_test.dart` at 620x349, 600x338, 560x315,
  640x480, 667x375, 844x390, 932x430, 360x640, 390x844, 320x568, 1280x720
  and 1366x768 in four states (first run with tip strip and Garden Run call
  to action; returning player Easy; Hard 12x12; Garden Run): no Flutter error
  or overflow; the board lies inside the window and does not intersect
  Dig, Flag, the difficulty picker, any icon button, the tip strip, the
  status line, the call to action, the hearts row or the level badge; those
  controls are fully on screen; the board side is at least 240 px at
  620x349 (230 at 600x338, 210 at 560x315, 280 at 640x480, 260 at 667x375,
  250 at 844x390, 280 at 932x430, 260 at 360x640, 320 at 390x844, 200 at
  320x568, 420 at 1280x720, 460 at 1366x768); Hard 12x12 cells and the
  Garden Run 12x12 cell size are at least 14 px; a tap on the first tile
  digs.
- A3: A real Garden Run played to stage 10 (12x12 boss) at 620x349, 560x315
  and 320x568: 144 tiles, cells >= 14 px, BOSS tag visible, no overlap.
- A4: At 620x349, 560x315 and 320x568 Dig/Flag toggles work (flag mode is
  selected in semantics and a tap flags without digging), the Garden overlay
  and How to play open without errors, and after a lost board the result
  card shows "+N XP" above "New Field", which is on screen and closes the
  card.
- A5: Existing tests keep passing (390x844, 844x390, 1280x720, 1366x768 and
  800x1400 layouts, onboarding, Garden Run, game feel).
- A6: Real screenshots of the GamePix build in headless Chrome (audio muted)
  at the twelve sizes of A2 for the first run, the Garden Run entry screen,
  an Easy and a Hard board, a Garden Run stage 10 (12x12) board and the
  result card show the board first with no overlap or overflow (manual, not
  committed; recorded in `reports/short-viewport-layout-verification.md`).
- A7: `flutter analyze`, `flutter test`, `flutter test --platform chrome
  test/web`, `tool/build_gamepix.sh` and `tool/build_crazygames.sh` (self
  checks pass; the GamePix build has no `crazygames` or `bon-on.github.io`
  string) and the harness audit (Critical 0) pass.

## Constraints
- No new dependency; no change to game rules, saves, generators or dailies.
- Icon-only buttons keep their label as tooltip and semantics label.
- Portal UI language is English.

## Mapping

| Requirement | Files | Checks |
| --- | --- | --- |
| Layout selection, compact and short stacked layouts | lib/main.dart | test/short_viewport_layout_test.dart (A1-A4) |
| Selected icon toggle, small tap targets | lib/src/ui/garden_ui.dart | test/short_viewport_layout_test.dart (A4) |
| Result card on short frames | lib/src/ui/run_summary_overlay.dart | test/short_viewport_layout_test.dart (A4) |
| Real browser check | build/gamepix | reports/short-viewport-layout-verification.md (A6) |

## Evidence
- flutter analyze
- flutter test (incl. test/short_viewport_layout_test.dart)
- flutter test --platform chrome test/web
- tool/build_gamepix.sh and tool/build_crazygames.sh
- node <harness-lab>/dist/index.js audit . --format md
- reports/short-viewport-layout-verification.md
