---
id: contract-how-to-play-tutorial
title: Deliver a skippable first-run tutorial that never affects play
status: active
related_specs:
  - feature-how-to-play-tutorial
  - feature-retention-polish
  - feature-crazygames-quality-recovery
evidence_files:
  - reports/how-to-play-tutorial-verification.md
---

# Contract: How-to-play tutorial

## Goal
Explain the goal and controls once, let players skip, and let them reopen it.

## Done Criteria
- A short visual first-run card with Skip/Play and `?` reopen; the quality-recovery revision supersedes the original three-page introduction.
- Seen flag `tutorial_seen_v1` persists; storage failures never break play.
- Game input and the clock are paused while the overlay is open.
- Widget tests cover the behaviors in the feature spec.
- Flutter tests and harness audit pass.

## Verification
- flutter test
- harness audit

## Evidence References
- reports/how-to-play-tutorial-verification.md
