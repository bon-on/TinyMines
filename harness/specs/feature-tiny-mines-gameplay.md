---
id: feature-tiny-mines-gameplay
title: Tiny Mines board rules, desktop input, hint cost and best times
status: active
owner: games
related_adrs:
  - adr-spec-driven-delivery
related_contracts:
  - contract-tiny-mines-gameplay
required_evidence:
  - flutter-tests
  - harness-audit
---

# Feature: Tiny Mines board rules, desktop input and hint cost

## Problem
Tiny Mines could only flag with a long press, which desktop browsers do not
offer comfortably, and had no way to clear around a solved number. Hints
revealed a safe tile for free, so hinted clears ranked the same as clean ones
on the time leaderboard.

## Scope
- Keep the board rules in a widget-free `MineField` class so they can be unit
  tested.
- Flag with long press or right-click (secondary tap).
- Tapping a revealed number whose flag count matches clears its unflagged
  neighbors (chord). Wrong flags can still set off a mine.
- Each hint adds a fixed time penalty to the clock, shown in the hint tooltip.
- Best clear time per difficulty is stored locally (shared_preferences) and
  shown as a HUD metric; storage failures never break play.
- On web the Flutter view is embedded in the `#game-host` element below the
  hub bar (web/index.html), so the header row is never covered. Right-click
  flags, so the browser context menu is disabled on web.
- After a loss, flags that sat on safe tiles are marked as wrong flags.
- The play column is centered with a max width of 560 px; tiles show a click
  cursor on desktop and scale numbers/icons with tile size so 12x12 stays
  readable on phone portrait (390x844) and desktop landscape (1280x720).

## Acceptance Criteria
- The first reveal never lands on a mine or a mine-adjacent cell.
- Right-click toggles a flag on an unrevealed cell; revealed cells cannot be
  flagged, and flagged cells cannot be revealed.
- Chord does nothing until the flags around the number equal the number, then
  reveals the remaining neighbors; a wrong flag makes chord explode a mine.
- A new clear time lower than the stored one replaces it for that difficulty;
  slower clears do not. Hint penalty seconds count toward the stored time.
- `MineField.wrongFlags` is empty during play and lists flagged safe tiles
  once the game is lost.
- A hint reveals a safe unrevealed tile and adds `_hintPenaltySeconds` to the
  elapsed time used for the leaderboard result.
- Flutter tests and harness audit pass.

## Constraints
- Hard changes from 12x12/28 mines (19.4% density) to 12x12/26 (18.1%): 28
  was close to expert density on a board with few safe openings, so Hard stays
  winnable without guessing as often. Easy and Normal, board sizes and hint
  counts are unchanged. No 16x16 Expert: it would shrink tiles below ~28 px
  at 390 px width, hurting touch accuracy.
- The leaderboard result is still taken from game state, never player input.

## Evidence
- flutter test
- harness audit
