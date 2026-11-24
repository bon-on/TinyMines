# Live run status verification — 2026-11-24

Spec: `harness/specs/feature-live-run-status.md`. Base commit: `cf9fa10`.

| Check | Command | Result |
|---|---|---|
| Analyze | `flutter analyze` | exit 0, no issues |
| Tests | `flutter test` | exit 0, 397 passed |
| Independent review | code-reviewer | High (panels one stage ahead during the tool picker) fixed with a shared `_runStageReached` rule and screen tests, then re-reviewed |

Requirement coverage:

- R1: `test/live_run_status_test.dart` (card states) and `test/garden_tools_screen_test.dart` group "live run status" (Stage 1 while
  the picker is open, Stage 2 after the pick, Stage 1 when a checkpoint with a pending offer is resumed).
- R2: the same screen tests check 0/8 while the picker is open and 1/8 once stage 2 loads with the "New plot" banner.
- R3: saving and the panels share `_runStageReached`; `test/live_run_status_test.dart` checks the saved best alone.

Also in this change: three tests that failed on `cf9fa10` now pass. Two leaked a semantics handle (testWidgets already enables
semantics). The result card at 844x390 hid the +XP row under the pinned actions; the card's compact mode now starts below
380 px (note in `feature-run-first-launch.md`), and 932x430 joined the short-card test.

Found in a 2026-11-24 Chrome playtest of a local web build (fresh storage, 1562x784 window, 390x700 and 800x450 frames).
Not verified: real portal QA and native devices.
