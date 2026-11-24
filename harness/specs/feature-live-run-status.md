---
id: feature-live-run-status
title: Show the live Garden Run stage and the plots it has reached
status: active
owner: games
related_adrs:
  - adr-tiny-mines-crazygames-web
related_contracts:
  - contract-tiny-mines-gameplay
required_evidence:
  - flutter-analyze
  - flutter-tests
  - harness-audit
  - independent-review
---

# Live Garden Run status

## Problem

A 2026-11-24 playtest of a fresh install showed two side panels that contradict the board during a run:

- The Garden Run card says "No run yet" while stage 1 or 2 of the first run is being played, because it only shows the saved
  best stage.
- Reaching stage 2 announces "New plot: Sprout bed", but the Garden plots card keeps the plot locked (0/8) until the run ends,
  because the run's best stage is saved only at the end (feature-garden-collection).

The first minute is when a new player decides to keep playing, so the panels should confirm progress as it happens.

## Scope

- Garden Run card: while a run is on the table, show the current stage (and the saved best once there is one) instead of the
  saved best alone.
- Garden plots card: count plots reached by the current run's stage as earned for display, so the count, tiles, set lines and
  "Next" goal match the banner.

## Constraints

- Display only. Saving, XP, set bonuses and the run-end result card keep their current rules (feature-garden-collection,
  feature-garden-run). No new dependencies or assets.
- The classic boards and the daily garden keep their behavior. The narrow layout's garden sheet uses the same plots card rule.

## Acceptance Criteria

- R1: During a run the Garden Run card reads "Stage N" (or "Stage N - best B" when a saved best exists) and never "No run yet".
  Without a run it still reads "Best stage B" or "No run yet".
- R2: When the run reaches a stage that earns a Run Path plot, the Garden plots card shows that plot as earned and its count and
  "Next" goal move on at the same time as the banner.
- R3: After the run ends the cards show the saved values, which already include the run's best stage.
- R4: `flutter analyze` and `flutter test` pass.

## Requirement-to-check map

- R1-R3: `test/live_run_status_test.dart`.
- R4: CI test command.

## Evidence

- reports/live-run-status-verification.md
