---
id: feature-tiny-mines-gameplay
title: Tiny Mines board rules, desktop input and hint cost
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

## Acceptance Criteria
- The first reveal never lands on a mine or a mine-adjacent cell.
- Right-click toggles a flag on an unrevealed cell; revealed cells cannot be
  flagged, and flagged cells cannot be revealed.
- Chord does nothing until the flags around the number equal the number, then
  reveals the remaining neighbors; a wrong flag makes chord explode a mine.
- A hint reveals a safe unrevealed tile and adds `_hintPenaltySeconds` to the
  elapsed time used for the leaderboard result.
- Flutter tests and harness audit pass.

## Constraints
- Difficulty sizes, mine counts and hint counts stay as they are.
- The leaderboard result is still taken from game state, never player input.

## Evidence
- flutter test
- harness audit
