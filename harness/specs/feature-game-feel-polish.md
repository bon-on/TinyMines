---
id: feature-game-feel-polish
title: Game feel, Garden Run moments, stable layout and a lighter portal bundle
status: active
owner: games
related_adrs:
  - adr-crazygames-quality-recovery
  - adr-tiny-mines-crazygames-web
related_contracts:
  - contract-tiny-mines-gameplay
  - contract-tiny-mines-crazygames
  - contract-tiny-mines-gamepix
required_evidence:
  - flutter-analyze
  - flutter-tests
  - chrome-sdk-tests
  - crazygames-build
  - gamepix-build
  - harness-audit
  - independent-review
---

# Game feel polish

## Problem

CrazyGames rejected the game twice with the generic "overall quality" note. A local play audit of 6a3139c (headless
Chrome, GamePix flavour, 1280x720, 1366x768, 390x844, 844x390) found:

- W1: clue numbers appear instantly under the grass ripple; only the grass has motion, so a cascade feels flat.
- W2: a dug mole has a ring and dirt but no reaction of the mole itself.
- W3: Garden Run stage starts, stage clears, boss gardens and plot rewards are only a line of status text; the plot is
  only mentioned on the summary card after the run.
- W4: on 390x844 the board shrinks after the first dig because the status line and the tip body change between one
  and two lines.
- W5: Flag mode is visible only on the button, not where the player taps.
- W6: on 844x390 the board is about 190 px (12x12 cells about 15 px) because the difficulty picker and Dig/Flag sit
  above it.
- W7: 12x12 clue digits on a 390 px phone are about 10 px.
- W8: the HTML loader is dark grey with a generic spinner; the first frame does not read as a garden.
- W9: portal bundles ship the skwasm and wimp engines (about 14 MB) that a dart2js CanvasKit build never loads.

## Scope

Effects, layout and build trimming only. No rule, generation, scoring, reward, save-format or portal SDK change. No
new package or asset.

## Acceptance Criteria

- G1: A dig that opens numbered cells pops each clue pebble in (overshoot scale) after that cell's grass leaves, in
  the same ripple order. The effect is one-shot; the effect ticker stops when the queue is empty.
- G2: A dug mole (game-ending or Garden Run heart loss) jumps out of its hole with a short squash in addition to the
  existing ring, dirt and shake.
- G3: Garden Run shows a short non-blocking banner (IgnorePointer, about 1.5 s, one at a time) over the board for:
  each stage start ("Stage N", size and moles), boss stage start ("Boss garden!"), stage clear ("Stage N cleared!",
  next stage) and boss clear ("Boss garden cleared!", "+1 heart" only when a heart was restored). When a stage
  starts that earns a Run Path plot for the first time (stage equals the plot requirement and the saved best stage
  is lower), the banner names the plot and draws it, and the new-best sound plays (muted by the user or the portal
  like every other sound). Plot rewards are still saved only when the run ends.
- G4: On narrow layouts the status line is always two lines tall and the tip body is always two lines tall, so the
  board size does not change after the first dig, between tips, or for feedback messages.
- G5: In Flag mode the board frame is flag-coloured with a soft glow; Dig mode and finished boards show the normal
  frame.
- G6: On short landscape screens (height < 520) Dig/Flag and a vertical difficulty picker sit left of the board; the
  board is at least 220 px at 844x390, and side columns scale down instead of overflowing.
- G7: Clue digits take a larger share of small cells (under 28 px: 0.56, under 40 px: 0.5, otherwise 0.44 of the
  cell).
- G8: The HTML loader uses a sky and grass background with the title and "A cozy garden dig"; it still hides on the
  first Flutter frame. The GamePix index stays free of external URLs.
- G9: Both portal build scripts delete `canvaskit/skwasm*` and `canvaskit/wimp*` after checking the build config
  names no wasm renderer; the game still boots from the trimmed bundle.
- G10: No overflow at 1280x720, 1366x768, 390x844 and 844x390 for Easy and Hard 12x12; all existing tests pass.

## Mapping

| Requirement | Files | Checks |
| --- | --- | --- |
| G1, G2, G3 | lib/src/ui/board_fx.dart, lib/src/art/garden_tile_art.dart, lib/main.dart | test/game_feel_test.dart, test/garden_run_screen_test.dart |
| G4, G5, G6, G7, G10 | lib/main.dart, lib/src/ui/onboarding_strip.dart, lib/src/ui/garden_board.dart, lib/src/ui/garden_ui.dart | test/game_feel_test.dart |
| G8 | web/index.html | build scripts, headless boot |
| G9 | tool/build_crazygames.sh, tool/build_gamepix.sh | build scripts, headless boot and network list |

## Constraints

No new dependencies, assets or looping animations. Effects never delay rule application or input. Mute rules from
`feature-sound-effects` apply unchanged.

## Evidence

- `reports/game-feel-polish-verification.md`
- flutter analyze, flutter test, `flutter test --platform chrome test/web`, both portal build scripts, harness audit,
  independent review.
