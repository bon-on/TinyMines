---
id: feature-garden-run-resume
title: Resume an active Garden Run after reopening the game
status: active
related_adrs:
  - adr-garden-run-checkpoint
related_contracts:
  - contract-tiny-mines-gameplay
---

# Garden Run resume

## Problem

Closing the game during a long Garden Run loses the current stage, run tools,
and progress toward the run's record and XP.

## Scope

The Garden Run entry resumes a saved run, including its exact active board,
hearts, tools, flags and elapsed play time. Reopening during a stage reward
shows the same offer. A stage reached after a reward pick keeps the selected
tool and starts from an untouched board until the first dig.

Successful moves and flags, stage clears, tool picks and app deactivation
checkpoint a participated run. Restarting or leaving an active run for
Classic or Daily still settles it. The settlement updates XP and records and
removes the checkpoint together. An older save opens normally. A malformed
checkpoint is ignored while its surrounding progress remains usable.

## Constraints

The checkpoint uses the existing progress envelope. Classic and Daily rules
and end-of-run reward calculations stay as defined by their specs.

## Acceptance Criteria

- Exercise mid-stage reopening, reopening the tool picker, picking and
  reopening, and settling once on leaving.
- Exercise an invalid checkpoint and valid legacy progress.
- Tool choice buttons expose a tap action to assistive technology.

## Evidence

- `test/garden_run_screen_test.dart` and `test/garden_tools_screen_test.dart`
- Flutter analyze, the Flutter tests and the portal build checks
