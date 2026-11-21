---
id: adr-garden-run-checkpoint
title: Save and settle Garden Run in the garden progress envelope
status: accepted
related_specs:
  - feature-garden-run-resume
---

# Garden Run checkpoint

## Context

Garden Run can span many stages, and a tab reload used to discard the run.

## Decision

Store the active run as an optional versioned value within
`garden_progress_v1`. Serialize writes in screen order. Settling updates
records and clears the checkpoint in the same save. A separate checkpoint key
would leave a gap between rewarding a run and clearing its saved state.

Save the board's cells directly so an interrupted board does not depend on
the runtime PRNG or its position. Between stages a checkpoint contains
the next stage and its already-drawn offer. During a stage it contains the
board, including exploded moles, and the stage clock. Time away is excluded.

## Consequences

Existing saves need no migration. In-progress moves add small, ordered writes
to the existing progress entry. A settled run removes its saved board and
tools together with the update to XP and records.
