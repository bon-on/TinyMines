---
id: adr-crazygames-quality-recovery
title: Refine regular Easy generation and first-session controls after quality rejection
status: accepted
related_specs:
  - feature-crazygames-quality-recovery
  - feature-first-run-onboarding
---

# Quality recovery

## Context

The platform supplied a generic quality rejection without a specific technical diagnosis. Reproduced first-session fairness and input weaknesses provide a concrete improvement target while retaining the existing polished garden art.

## Decision

Retain the established garden art and Minesweeper rules. Give regular Easy a bounded visible-clue-solver-verified generation policy; preserve default MineField generation, Normal/Hard and fixed daily seeds. Add an explicit touch flag mode, visible clue feedback and short visual onboarding rather than changing genre or inventing a technical rejection explanation. Match other portal games' inactivity lifecycle gating.

## Consequences

A rejected game must be updated through its supported existing portal route; do not create a duplicate submission to bypass a rejection. Technical verification and UX improvements cannot guarantee a subjective quality acceptance.

## Addendum: non-blocking onboarding

The short visual card no longer opens automatically. First-time players get a dismissible hint strip over a playable board (`feature-first-run-onboarding`); the card remains behind `?`. Garden Run is promoted with a call to action until the first run is played.
