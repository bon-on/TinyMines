---
id: feature-crazygames-quality-recovery
title: Fair Easy fields and clearer first-session garden controls
status: active
owner: games
related_adrs:
  - adr-crazygames-quality-recovery
  - adr-tiny-mines-crazygames-web
related_contracts:
  - contract-tiny-mines-gameplay
  - contract-how-to-play-tutorial
required_evidence:
  - flutter-analyze
  - flutter-tests
  - chrome-sdk-tests
  - pages-build
  - crazygames-build
  - gamepix-build
  - harness-audit
  - independent-review
---

# CrazyGames quality recovery

## Problem

The submitted Tiny Mines build was rejected with only: "The overall quality of the game does not yet meet the expectations of our platform". Submission date 05.11.2026, submitted build a252f3a6-7c0f-4cc2-a772-60c014bd5e80, game fccd2987-6b5f-49b3-9b77-100fa62e336a. The reviewer did not identify a particular bug. The following improvements address reproduced first-session weaknesses, without claiming they were the reviewer's exact reason.

Visible-clue exhaustive analysis of actual Easy6x6/5 boards (seeds0..29, first reveal21) found forced guesses in seeds0,5,17. Existing touch flagging requires a long press, unmatched chord attempts return silently, and three modal tutorial pages delay interaction. Current garden art is already coherent and is retained.

## Scope

Improve regular Easy fairness, touch input, onboarding and inactive behavior; preserve the garden identity, other difficulty rules, saved progress and existing daily practice.

## Acceptance Criteria

- R1: Regular Easy remains6x6 with5 mines and a safe first cell/neighborhood, but its first reveal selects a board that a deterministic visible-clue logical solver can finish without guesses. Use bounded candidate generation plus a verified bounded fallback; never silently return an unverified board. Avoid instantly solved first-reveal boards. Normal/Hard and dated DailyChallenge layouts/seeds remain unchanged. Existing opt-out MineField constructor behavior remains compatible for old tests/daily; expose `requireLogicalSolution: false` optional constructor parameter, enabled by the screen ONLY for regular Easy. No new package dependencies.
- R2: Visible, labeled Dig/Flag controls allow touch users to flag with a tap. Default/reset mode is Dig. Right-click and long press continue to flag regardless of selected mode. In Flag mode, tapping revealed tiles never digs/chords. Switching modes does not reveal a tile or lose flags. Controls fit360x760,390x844,844x390 and desktop1280x720.
- R3: First-run guidance is short, visual, skippable and explains that a number counts mines in all eight surrounding cells. Show a clear safe-opening prompt and contextual input guidance during play. Preserve tutorial persistence and reopen-help behavior; never allow a tutorial input to reveal a hidden board tile or start a clock behind an overlay.
- R4: An unmatched chord gives brief, accurate feedback using only the visible clue and placed flags. Existing hint budget/+10second cost, scoring, rewards and loss conditions remain unchanged.
- R5: App inactivity/hidden/paused stops gameplay events, solve clock and audio, resuming only while playing with no modal/menu/results. No duplicate events. Preserve all preexisting daily-practice changes and data formats.
- R6: Title-only submission covers omit the previous local promotional taglines, while preserving original media. Normal Pages/mobile no-op platform and portal SDK/cloud/mute policies remain intact. Rebuild all distributions after review; prepare an accurate fix note and revised build for the existing rejected game. No duplicate-game resubmission to evade review, no final submission without a supported portal route.

## Requirement mapping

| Requirement | Owner/files | Check |
|---|---|---|
| R1 | engine worker: mine_field.dart + pure helper/tests | seeded cases/all36 openings, first-safe/exact5, solver proof, bounded adversarial RNG/fallback, Daily/Normal/Hard regression |
| R2-R5 | UI worker: main.dart, how_to_play.dart, src/ui and widget tests | real tap/longpress/rightclick/mode, chord feedback, tutorial/swallow, lifecycle/clock, layouts/daily reward regressions |
| R6 | coordinator | full analyze/tests/Chrome/Pages/CG/GamePix/audit, independent review, source/ZIP identity, portal evidence |

## References / limits

Official guidance: https://docs.crazygames.com/requirements/quality/ (fast visual onboarding, clear controls/goals, balanced challenge). This spec explicitly refines the earlier retention restriction against generation changes for regular Easy only; dimensions, mine count, reveal/chord/flag rules and existing dated daily layout are preserved. No claim of guaranteed platform acceptance.

## Constraints

No new dependencies or genre change. Easy dimensions/mine count and all existing reveal, flag, chord, hint and reward rules remain. Default generation, Normal/Hard and dated daily seeds are preserved. Original media remains available.

## Evidence

- `reports/fair-easy-generation.md` and `reports/quality-recovery-ui.md`
- Final quality recovery verification report; full VM/Chrome tests and all three web builds
- `node <harness-lab>/dist/index.js verify . harness/verify.json --output build/quality-evidence/vm` and matching check-evidence
- Independent review and audit Critical0
