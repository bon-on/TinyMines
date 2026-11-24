---
id: feature-run-first-launch
title: Launch into Garden Run, a daily return hook and the next action on result cards
status: active
owner: games
related_adrs:
  - adr-garden-run-checkpoint
  - adr-daily-practice
  - adr-crazygames-quality-recovery
related_contracts:
  - contract-tiny-mines-gameplay
  - contract-tiny-mines-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - independent-review
---

# Launch into the run, daily hook and next action

## Problem

CrazyGames average playtime, D1 retention and the share of players past one minute are low. Every launch opens a Classic
6x6 board even when the player has a saved Garden Run (only a button label hints at it) or has never tried Garden Run, the
mode with the longest sessions. Result cards give no reason to come back tomorrow, and on short screens the next goal is
easy to miss.

## Scope

1. Launch (`TinyMinesApp`, the production entry; `TinyMinesScreen.launchIntoRun`, off by default so the plain board tests
   keep their Classic launch, as `gardenTools` does for tools). Once the stored progress has loaded:
   - a saved checkpoint (`runCheckpoint != null`) resumes that Garden Run directly, through the existing
     `_resumeOrStartGardenRun` path (board, hearts, tools, clock or the open tool offer). A direct resume is chosen over a
     "Continue" card: it adds no new overlay state, no extra tap and no new gameplay start/stop transition;
   - a player with `runsPlayed == 0` and no checkpoint starts Garden Run stage 1 instead of Classic;
   - otherwise the Classic board stays.
   The switch only replaces the untouched launch board: not after a dig, flag or hint, a queued pre-check tap, a difficulty or
   daily choice, an open card (How to play, Garden) or a finished board. The Classic launch board is never recorded or
   settled; the run is settled once, as before. The portal sees one gameplay session (no stop/start pair caused by the
   switch; the tool picker of a resumed offer stops gameplay as the picker always does). The resumed run clock waits for the
   first-run check. First-run tips (`feature-first-run-onboarding`) show over the run board unchanged.
2. Resume labels include the saved stage and hearts, e.g. `Resume Garden Run - stage 4, 2 hearts` (singular `1 heart`).
3. Result cards (Classic, Daily, practice and Garden Run) show one compact daily line (`daily-hook`) from the injectable
   clock (`TinyMinesScreen.now`):
   - just recorded: `Daily streak: 3 days. New daily in 5h 12m.`;
   - done today: `Daily done - 3-day streak. New daily in 5h 12m.`;
   - open, streak alive: `Play today's daily to keep your 3-day streak (5h 12m left).`;
   - open, no streak: `Today's daily garden is open (5h 12m left).`
   The time is the ceiling in minutes to the next local midnight (`Xh Ym`, or `Ym` under an hour). Without a clock (direct
   widget use) only the recorded line shows, with "Come back tomorrow!". The line sits in the scrolling details, so the pinned
   actions and the XP row keep their place on short screens.
4. Next action: the primary `New Run` / `New Field` button is the visually primary action and gets keyboard focus when the
   card appears (requested when the card is first built, not while it is still hidden). The Next goal block stays; a Run
   Path plot goal names the stages still missing past the best stage: `Reach stage 5 - 2 more stages - 2/8 plots`.

Out of scope: gameplay rules, rewards, storage format, new keys, ads, portal SDK calls.

## Acceptance Criteria

- L1: With `launchIntoRun`, fresh progress opens Garden Run stage 1 (5x5) after load; the platform reports a single
  `gameplayStart`; no Classic play, XP or run is recorded.
- L2: With a checkpoint, launch shows the saved board, stage and hearts without a tap; leaving settles it once.
- L3: `runsPlayed > 0` without a checkpoint keeps Classic. A dig made before the progress load keeps Classic.
- L4: Resume labels show stage and hearts.
- D1: `dailyHook` and `untilNextDaily` return the documented strings for done/open/streak states and the minute ceiling.
  Result cards show the line with the injected clock; no overflow at 844x390 and 560x315.
- N1: The primary button holds primary focus once the card is shown; the run plot goal detail counts missing stages.

## Mapping

| Requirement | Files | Checks |
| --- | --- | --- |
| Launch into run, labels | lib/main.dart, lib/src/ui/garden_cards.dart | test/run_first_launch_test.dart, test/garden_run_screen_test.dart |
| Daily hook | lib/src/meta/next_goal.dart, lib/src/meta/daily_challenge.dart, lib/src/ui/run_summary_overlay.dart | test/next_goal_test.dart, test/run_first_launch_test.dart |
| Focus, next goal | lib/src/ui/run_summary_overlay.dart, lib/src/meta/next_goal.dart | test/run_first_launch_test.dart, test/next_goal_test.dart |

## Constraints

No new dependencies, no storage changes, English ASCII strings. Daily accounting stays as in `adr-daily-practice`; the run
checkpoint and its single settlement stay as in `adr-garden-run-checkpoint`.

## Evidence

- `reports/run-first-launch-verification.md`
- `flutter analyze`, `flutter test`, `flutter build web`

## Note - 2026-11-24

The result card drops its art and uses small stat tiles whenever the card is shorter than 380 px (was 320 px). That now
includes landscape phones such as 844x390, where the +XP row had slipped under the pinned actions. 932x430 keeps the full
card and is checked by the same "daily line fits a short card" test.
