---
id: feature-daily-practice
title: Retry completed daily gardens without changing the scored result
status: active
related_adrs:
  - adr-daily-practice
  - adr-tiny-mines-crazygames-web
related_contracts:
  - contract-tiny-mines-gameplay
---

# Daily practice

## Problem

A recorded daily result previously prevented another attempt, leaving no safe way to practice the same board without risking repeated scored rewards.

## Scope

Permit explicit unscored retries of the captured daily board while preserving the first recorded result and all progress accounting.

## Acceptance Criteria
- After a daily result, offer Practice same board. Rebuild that exact dated daily board and its opening, including when the calendar changes while the result is open.
- Practice is explicitly labeled unscored. It never changes XP, best times, counts, daily result, streak or unlocks and never offers leaderboard submission.
- The recorded daily result remains available after reload; its daily entry point offers unscored practice. A new date still offers its normal scored daily attempt.
- A duplicated scored daily result is also idempotent in the progress model. A slow initial progress read cannot open a second scored attempt before the existing result is known.
- Practice can be repeated, exited for a regular board, and operated by touch or focused keyboard controls. Existing timers/hints retain their rules.
- Tests cover original loss followed by practice win, repeated practice, reload, midnight, pending progress and regular mode reward recovery. Analyze, all VM/Chrome tests, Pages/portal builds and harness audit pass.

## Mapping
| Requirement | Files | Checks |
| --- | --- | --- |
| Unscored accounting | garden_progress.dart | progress unit tests |
| Same dated board and entry points | main.dart, garden_cards.dart, run_summary_overlay.dart | widget result/reload/date tests |
| Release regression | reports/daily-practice-verification.md | analyze, tests, builds, audit |

## Constraints
No dependencies, no mine generation changes, no portal uploads. Existing daily scoring applies only to the first recorded result. This clarifies retention-polish's once-per-day rule while permitting explicit unscored retries.

## Evidence

- `reports/daily-practice-verification.md`
- Progress unit tests, daily reload/midnight widget tests, integrated VM/Chrome suites and web build checks
