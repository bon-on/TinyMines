# Run-first launch verification

Spec: `feature-run-first-launch`. Local work only; no portal upload. Built on the uncommitted Garden Run checkpoint work
(`feature-garden-run-resume`).

- `flutter analyze`: exit 1, only the pre-existing `deprecated_member_use` infos for `package:flutter/material.dart`
  (27, same count as before this change); no errors or warnings.
- `flutter build web --release --no-tree-shake-icons --no-wasm-dry-run -o <scratch>/tm_web`: exit 0 (compile check).
- `flutter test`: **not executed**. Windows Smart App Control blocks `flutter_tester.exe` on this PC. The tests below were
  written or adjusted but have not run; run `flutter test` (CI) before release.

Tests written (not executed):

- `test/run_first_launch_test.dart`: first launch opens stage 1 with the tips and one `gameplayStart`, nothing recorded,
  leaving settles once; a saved run resumes at launch without a tap; the Resume label names stage and hearts; a returning
  player keeps Classic; a dig before the progress load keeps Classic; the result card shows the daily line, focuses
  `New Run`, and fits at 844x390 and 560x315.
- `test/next_goal_test.dart`: `untilNextDaily` minute ceiling and midnight; `dailyHook` open/streak/done/lapsed; the Run
  Path plot detail counts the missing stages.
- `test/garden_run_screen_test.dart`, `test/garden_tools_screen_test.dart`: Resume finders follow the new label.

Decisions: a saved run resumes directly rather than behind a "Continue" card (no new overlay, focus or portal state);
`launchIntoRun` is on in `TinyMinesApp` and off by default in `TinyMinesScreen`, so plain board tests keep the Classic
launch. The daily line lives in the scrolling details so the XP row and pinned actions keep their place on short cards.

Not verified: real portal session timing (CrazyGames cloud save load vs. first tap), all widget tests above.

Independent review (read-only code-reviewer agent): no Critical/High/Medium findings. Low fixed: a daily finished after
midnight now shows today's open daily instead of "New daily in ~24h" (test added). Low accepted: the Resume label is rarely
visible in the shipped app because a saved run resumes at launch; it scales down in slim columns.
