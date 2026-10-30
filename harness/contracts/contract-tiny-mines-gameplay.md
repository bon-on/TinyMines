---
id: contract-tiny-mines-gameplay
title: Deliver desktop-friendly Tiny Mines input and fair hint cost
status: active
related_specs:
  - feature-tiny-mines-gameplay
evidence_files:
  - reports/tiny-mines-gameplay-verification.md
---

# Contract: Tiny Mines gameplay

## Goal
Make Tiny Mines playable with a mouse and keep hinted clears from ranking like
clean ones.

## Done Criteria
- Right-click flags, chord clears solved numbers, and hints cost time.
- `MineField` unit tests cover first-reveal safety, chord, flags, hints and win.
- Best time per difficulty persists locally and shows in the HUD; wrong flags
  are marked after a loss; layout is centered with a max width.
- Flutter tests and harness audit pass.

## Verification
- flutter test
- harness audit

## Evidence References
- reports/tiny-mines-gameplay-verification.md
