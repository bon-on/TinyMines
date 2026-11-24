# Theme reward reveal verification — 2026-11-24

Spec: `harness/specs/feature-theme-reward-reveal.md`. Base commit: `7f013ab`.

| Check | Command | Result |
|---|---|---|
| Analyze | `flutter analyze` | exit 0, no issues |
| Tests | `flutter test` | exit 0, 406 passed |
| Independent review | code-reviewer | approve with comments; README, doc comment and old spec levels updated, screen-level R3 test added |
| Browser check | local web build in Chrome, progress seeded at 95 XP | a Garden Run ending at Lv 2 showed the Autumn reveal; "Use Autumn" restyled the whole garden and the button read "Using Autumn" |

Requirement coverage:

- R1: `test/theme_reward_reveal_test.dart` (levels 1/2/4/6, Autumn at 100 XP), `test/garden_progress_test.dart`, `test/next_goal_test.dart`.
- R2, R4: `test/theme_reward_reveal_test.dart` (reveal shown, none without an unlock, highest revealed with pills for the rest, fits 844x390, 560x315 and 390x700).
- R3: `test/garden_screen_test.dart` "the result reveal switches and saves a new theme" (real screen, store saves `autumn`), plus the widget test for the "Using" state.
- R5: full suite, including `run_first_launch_test` short-card checks.

Not verified: real portal QA, native devices, and a keyboard-only path that Tabs to "Use" and presses Enter (the button disables
itself, so a second Enter may need a Tab first).
