---
id: adr-daily-practice
title: Keep daily practice separate from scored progress
status: accepted
related_specs:
  - feature-daily-practice
  - feature-garden-collection
---

# Daily practice accounting

## Context

Completed daily gardens need replay without changing the scored result, including after reload, a slow progress read, or a date rollover.

## Decision
Use an explicit practice flag on the transient run result and screen. The captured daily day key identifies the board; never rebuild a retry from the current clock date. DailyChallenge.build remains the single board constructor.

GardenProgress.applyRun returns an unchanged progress outcome for practice and already-recorded daily results. This protects every caller, including delayed storage merges, against duplicate rewards. Do not persist a practice session as a scored attempt or add a second reward key. Existing daily records provide the practice entry after reload; reloading exits an unfinished practice into the regular landing screen.

## Consequences

Daily launch waits for progress loading. Regular games retain their existing fail-soft load behavior. The result overlay and daily card make practice explicit, while normal New Field remains available.
