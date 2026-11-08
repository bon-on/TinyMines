---
id: feature-how-to-play-tutorial
title: First-run how-to-play tutorial with skip
status: active
owner: games
related_adrs:
  - adr-spec-driven-delivery
related_contracts:
  - contract-how-to-play-tutorial
required_evidence:
  - flutter-tests
  - harness-audit
---

# Feature: First-run how-to-play tutorial

## Problem
New players get no explanation of the goal or of right-click / long-press
flagging, chording and the hint cost. Players asked for a short explanation
with a way to skip it.

## Scope
- On the first launch only, a "How to play" overlay card is shown over the
  dimmed game. The quality-recovery revision uses one short visual card showing all eight neighbors, with Skip and Play buttons; the reusable stepper still supports multiple steps.
- Skip or Play closes it and stores `tutorial_seen_v1` (bool) in
  shared_preferences. Later launches go straight to the game.
- A "?" (help_outline, tooltip "How to play") header button reopens it at step
  1 at any time without resetting the game.
- Keys while open: Enter/Space next/play, Escape skip, Left/Right previous/next.
- All game input is blocked while open and the clock does not count: the timer
  stops while open and resumes on close if a game is in progress.
- Storage failures never break play: a read failure shows the tutorial, a write
  failure just closes it.
- The store is injectable (`TutorialStore`) so tests do not need real prefs.
- Text is English, card max width 360 px, scrollable for short viewports.
- Pointer input is ignored until the seen-flag read has answered; the card does not consume Tab, F5 or Ctrl/Meta/Alt shortcuts. The solve clock is stopwatch-based, so brief tutorial visits keep partial seconds.

## Acceptance Criteria
- Unset flag: overlay shown at launch and taps on tiles do nothing.
- The single visual card shows the eight-neighbor example and Play immediately; Play closes and stores the flag.
- Skip and Escape close and store the flag.
- Flag set: no overlay at launch.
- "?" reopens at step 1 and the board, moves and clock are unchanged.
- The elapsed clock does not advance while the overlay is open.
- Fits 390x844, 844x390 and 1280x720 without overflow.
- Flutter tests, analyze, web build and harness audit pass.

## Constraints
- Do not change board rules, hint penalty or leaderboard behavior.
- No new dependency beyond shared_preferences (already used).

## Evidence
- flutter test
- harness audit

## Quality recovery revision

`feature-crazygames-quality-recovery` replaces the original three-page first-run copy with one visual card and contextual in-game guidance; persistence, input isolation and clock behavior remain required.

## First-run onboarding revision

`feature-first-run-onboarding` replaces the automatic first-launch card with a non-blocking hint strip above a playable
board. The card stays reachable through `?` with the same input isolation, clock pause and keys; `tutorial_seen_v1` keeps its
meaning (first-run guidance finished) and format. Acceptance items about the overlay at launch now apply to the `?` card.
