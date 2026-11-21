---
id: feature-large-screen-scale
title: Large screen scale - the wide layout grows with fullscreen and big windows
status: active
owner: games
related_adrs:
  - adr-tiny-mines-crazygames-web
related_contracts:
  - contract-tiny-mines-crazygames
  - contract-tiny-mines-gamepix
required_evidence:
  - flutter-analyze
  - flutter-tests
  - crazygames-build
  - harness-audit
  - independent-review
---

# Feature: Large screen scale

## Problem
The wide layout is sized in fixed logical pixels: side columns at most 300 px, the board at most 580 px. In the
CrazyGames desktop frame (about 1100x620) it fills the window well, but in fullscreen (1920x1080) or a big browser
window the board covers about a quarter of the screen, the side panels look tiny and most of the screen is sky.
CrazyGames reviews in fullscreen too and rejected the game twice for overall quality.

## Scope
1. Wide windows larger than the 1280x720 design size lay the wide layout out at `size / scale` and scale it up
   uniformly, `scale = min(width / 1280, height / 720)` clamped to 1..1.6. Everything grows together (board, panels,
   text), so the arrangement is the same as at 1280x720.
2. Windows at or below 1280x720 (both ways), the compact and the stacked layouts are unchanged.
3. Input (taps, right click, long press, keys) works unchanged in the scaled layout. Overlays above the layout
   (tutorial, result card, tool picker, garden) and tooltips stay at their own size (out of scope; they are centered
   cards that already fit any window).
4. The scaled widget structure is used at every size (scale 1 included) so entering or leaving fullscreen does not
   remount the layout.

## Acceptance Criteria
- 1920x1080: the board is at least 1.4x the size it has at 1280x720 and the layout has the 1280x720 arrangement.
- 1100x620 and 1280x720: identical to before (scale 1).
- 2560x1440 is capped at 1.6x; no overflow at any tested size.
- Tapping a cell in the scaled layout digs that cell.

## Constraints
- No new package or asset. No change to the compact or stacked layouts.

## Plan and check mapping
| Requirement | Files | Verification |
|---|---|---|
| Scale rule and scaled wide layout | `lib/main.dart` | `test/large_screen_scale_test.dart` |

## Evidence
- `flutter analyze`, `flutter test`, `tool/build_crazygames.sh`, screenshots at 1100x620 and 1920x1080 in Chrome.
