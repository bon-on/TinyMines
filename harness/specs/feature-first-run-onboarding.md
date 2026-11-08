---
id: feature-first-run-onboarding
title: Non-blocking first-run onboarding and a prominent Garden Run call to action
status: active
owner: games
related_adrs:
  - adr-crazygames-quality-recovery
  - adr-tiny-mines-crazygames-web
related_contracts:
  - contract-how-to-play-tutorial
  - contract-tiny-mines-gameplay
required_evidence:
  - flutter-analyze
  - flutter-tests
  - chrome-sdk-tests
  - crazygames-build
  - gamepix-build
  - harness-audit
  - independent-review
---

# First-run onboarding and Garden Run call to action

## Problem

CrazyGames rejected Tiny Mines for overall quality (the reviewed build predates Garden Run). Reviewers judge the first
impression within seconds. On a first launch the "How to play" modal still covers the board, so the first thing a reviewer
sees is a dimmed screen and a card to dismiss. Garden Run, the mode that sets the game apart from plain minesweeper clones,
is one button among many and nothing points a new player to it.

## Scope

1. First launch (tutorial flag `tutorial_seen_v1` unset or unreadable): no modal. The board is visible and playable at once.
   A short hint strip sits right above the board:
   - before the first dig: "Start anywhere - your first dig is safe." plus "Numbers count moles in all 8 patches around them.";
   - after the first dig: how numbers and flags work ("A number counts moles touching it. Flag a sure mole: right-click,
     long-press or Flag mode.");
   - after the first flag: chord tip ("Tap a number whose flags are all placed to dig the rest around it.").
   The strip has a close button (tooltip "Hide tips") and never blocks input. It ends (and stores the flag) when closed,
   when the first board ends, or when the full How to play card is opened and closed.
2. Returning players (flag set) see no strip. The `?` button still opens the full How to play card at any time with its
   existing behavior (input isolation, paused clock, keys). The card is no longer opened automatically.
3. Backward compatible storage: the same `tutorial_seen_v1` bool is read and written; read failures behave as unseen (strip
   shown), write failures are ignored. No new key.
4. Garden Run call to action: while the player has never finished a Garden Run (`runsPlayed == 0`), the Garden Run entry is
   shown as a highlighted card "Try Garden Run: 3 hearts, bigger gardens" with a start button, on first launch and on every
   layout (narrow: replaces the plain entry button above the board; wide: the left column card). After a regular
   (not daily) board win while `runsPlayed == 0` (so from the first such win on), the result card shows the same call to
   action as a button. None of these
   block board input. Once a run has been played the entry returns to the regular card with the best stage.
5. The board taps made while the flag read is pending are still remembered and applied once it answers (it no longer opens a
   card that would discard them).

## Acceptance Criteria

- A1: Unset flag: no How to play card at launch, the hint strip is visible and the first board tap digs immediately (clock
  starts). Flag set: no strip.
- A2: The strip text changes after the first dig and after the first flag; closing it hides it and stores the flag; the
  first finished board also stores the flag. A storage read failure shows the strip, a write failure does not break play.
- A3: `?` opens the full card; while open the board ignores input and the clock is paused; closing resumes.
- A4: With `runsPlayed == 0` the "Try Garden Run" call to action is visible on 390x844 and 1280x720 and starts a run; after
  one finished run it is replaced by the best-stage entry. After the first regular win (runsPlayed 0) the result card has a
  "Try Garden Run" button that starts a run.
- A5: No overflow at 390x844, 1280x720, 1366x768 and 844x390 with the strip and call to action visible.
- A6: Existing tutorial, gameplay event, daily practice and Garden Run tests keep passing (tests that asserted the automatic
  modal are updated to the new first-run behavior).

## Mapping

| Requirement | Files | Checks |
| --- | --- | --- |
| Strip, flag storage, pending tap | lib/main.dart, lib/src/ui/onboarding_strip.dart | test/how_to_play_test.dart, test/onboarding_test.dart |
| Call to action | lib/src/ui/garden_cards.dart, lib/src/ui/run_summary_overlay.dart, lib/main.dart | test/onboarding_test.dart |
| Layout | lib/main.dart | overflow tests at four sizes, temporary screenshots |

## Constraints

No new packages, English ASCII strings, no change to board rules, hint cost, scoring, Garden Run rules, portal events or
storage formats. No endless animation.

## Evidence

`flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`, `tool/build_crazygames.sh`,
`tool/build_gamepix.sh`, harness audit, independent review, temporary screenshots at the four sizes.
