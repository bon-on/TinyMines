---
id: feature-garden-tools
title: Garden tools, a pick-one-of-three reward between Garden Run stages
status: active
owner: games
related_adrs:
  - adr-tiny-mines-crazygames-web
  - adr-spec-driven-delivery
related_contracts:
  - contract-tiny-mines-gameplay
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
---

# Feature spec: Garden tools

## Problem
Minesweeper is everywhere and a Garden Run stage is the same board with more moles, so a run has
no decisions between boards and no reason to start another one. The run needs a build-your-run
layer that is the game's own.

## Scope
After every cleared Garden Run stage the player picks one of three garden tools; the choice
carries through the rest of that run. Tools are automatic (no new buttons), so layouts are unchanged.

| Tool | Effect | Offered when |
| --- | --- | --- |
| Sunflower | +1 heart now | hearts below 3 |
| Lantern | +2 hints now (up to 7 in a run) | hints below 7 |
| Lucky clover | the next mole dug costs no heart (stacks to 2) | fewer than 2 clovers |
| Watering can | after the first dig of a later stage, the safest tile and the safe tiles around it are dug; at most 3x3, opened one tile at a time with no cascade (stacks to 2) | fewer than 2 cans |

- The offer is up to three distinct eligible tools, drawn with a random source. With fewer eligible
  tools fewer are shown, and with none the next stage starts at once. The picker is a modal card
  (keys 1-3, taps); the next stage starts after a pick. If the How to play or Garden card is open
  when the stage ends, the picker opens when that card closes. "Next stage" and the 1.8 s
  auto-advance now open the picker.
- Run-scoped tools are kept in the active run checkpoint (feature-garden-run-resume).
- Out of scope: changes to stage table, hearts
  cap, boss rules, XP, records, the daily, Normal/Hard/Expert, board generation.

## Acceptance Criteria
- The picker offers three distinct tools (fewer only when fewer are eligible) and never an ineligible one (no Sunflower at full
  hearts, nothing at its cap). It opens after every cleared stage and blocks board input.
- Sunflower and Lantern apply at once; hearts never exceed 3. Clover absorbs a dug mole (also a
  chord's mole) so no heart is lost; one clover per mole. The mole is still shown as blasted and
  the stage goes on. A mole that costs the last heart still ends the run when no clover is left.
- The can digs only safe, unflagged tiles around the safest tile (one tile at a time, no cascade),
  once per charge, after the first dig of a stage (a Hint used as the stage's first move keeps the
  charge for the next stage); it can win the stage; it never digs a mole.
- Leaving the run, restarting it or losing discards tools and closes the picker.
- Run XP, `bestRunStage`, `runsPlayed`, plots and the stage table are unchanged.
- 1280x720, 1366x768 and 390x844 layouts have no overflow with the picker open.

## Plan / check mapping
| Requirement | Files | Verification |
| --- | --- | --- |
| Tool rules and offers | `lib/src/game/garden_tools.dart`, `garden_run.dart` | `test/garden_tools_test.dart` |
| Picker overlay | `lib/src/ui/tool_picker.dart` | `test/garden_tools_screen_test.dart` |
| Run flow, clover, can | `lib/main.dart` | `test/garden_tools_screen_test.dart` |

## Constraints

Save tool charges only in their active run checkpoint. A finished run never
carries its tools into a new run.

## Evidence
`flutter analyze`, `flutter test`, `flutter build web --release --base-href /TinyMines/`, review.
