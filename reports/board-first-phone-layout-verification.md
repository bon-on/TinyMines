# Board-first phone layout verification — 2026-11-25

Spec: `harness/specs/feature-board-first-phone-layout.md`. Base commit: `84b0af7`.

| Check | Command | Result |
|---|---|---|
| Analyze | `flutter analyze` | exit 0, no issues |
| Tests | `flutter test` | exit 0, 428 passed |
| CrazyGames build | `bash tool/build_crazygames.sh` | built |

Headless Chrome captures of the CrazyGames build at a width of 390, first-run Garden Run state with tips:

| Height | Before | After |
|---|---|---|
| 844 | about 366 px | about 366 px |
| 760 | not captured | about 366 px |
| 720 | about 210 px | about 366 px |
| 664 | not captured | about 330 px |
| 640 | about 300 px | not captured |

Independent review: code-reviewer approved with comments and found no Critical or High issues. Four Medium findings were
fixed:

- one-frame flicker on resize, now predicted from the measured row cost;
- CTA text scaled under 11 px with Roboto;
- the resume label under 11 px in the phone row;
- missing short, run and resize tests.

Low findings: the meta row was renamed and `fold` made required. Daily and Garden icon-only buttons and the dropped XP bar
are left for the user to confirm.

Requirement coverage:

- B1/B2/B5/B6: `test/board_first_layout_test.dart`, with the bundled Roboto loaded:
  - sizes 390x720, 390x760, 390x844, 360x700, 360x640 and 320x568, first run and returning;
  - a live Garden Run;
  - a resize sequence;
  - the CTA and resume label sizes.
- Mutation checks:
  - with `foldBoardShare = 0` the 390x720 cases fail;
  - with the fold prediction disabled the resize test fails.
- B3: the existing layout tests pass (`short_viewport_layout_test`, `garden_run_screen_test`, `onboarding_test`,
  `run_first_launch_test`, `garden_screen_test`, `garden_plots_view_test`). The garden tests now open My Garden through
  the Garden tooltip on stacked windows.

Not verified: real phones and the portal QA preview.
