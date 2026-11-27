---
id: feature-garden-overlay-close
title: My Garden sheet can always be closed on short phones
status: active
owner: games
related_adrs:
  - adr-tiny-mines-crazygames-web
related_contracts:
  - contract-tiny-mines-gameplay
required_evidence:
  - flutter-analyze
  - flutter-tests
  - independent-review
---

# Feature Spec: My Garden sheet can always be closed on short phones

## Problem
On a phone browser (2026-11-28 report from GamePix mobile play), opening My Garden (flower button) during a Garden Run covered the screen and the player could not find a way back to the run.
The sheet only had a "Close" text button at the end of its scrolling content. When the visible height is short (browser bars, portal header; reproduced at 360x560), the panel fills the screen, the Close button is scrolled out of view, and the tappable barrier around the panel is only 14 px wide.

## Scope
- Pin the "My Garden" title row above the scrolling content, with a 44x44 close (X) button at its right edge (tooltip "Close", key `garden-close`).
- Keep the bottom "Close" button, the barrier tap and Escape/Enter closing.
- Out of scope: other overlays (result card, tool picker, how to play) and the sheet's contents.

## Acceptance Criteria
- G1: At 360x560, 320x480 and 560x315, during a Garden Run, the X button is fully on screen without scrolling and tapping it closes the sheet back to the same run (hearts still shown).
- G2: At the existing short sizes (620x349, 560x315, 320x568) the X button is on screen and at least 44 px wide.
- G3: Existing garden sheet behavior (pauses clock, blocks the board, Escape closes) still passes.
- G4: `flutter analyze` and `flutter test` pass.

## Constraints
- No new dependencies or assets. No gameplay, save or SDK changes.

## Requirement-to-check map
- G1, G2: `test/short_viewport_layout_test.dart`.
- G3: `test/garden_screen_test.dart`.
- G4: CI test command.

## Evidence
- Headless Chrome screenshots of the GamePix build at 360x560 before and after.
