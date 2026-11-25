# Mobile touch zoom verification — 2026-11-25

Spec: `harness/specs/feature-mobile-touch-zoom.md`. Base commit: `5d16ece`.

| Check | Command | Result |
|---|---|---|
| Analyze | `flutter analyze` | exit 0, no issues |
| Tests | `flutter test` | exit 0, 413 passed |
| CrazyGames build | `bash tool/build_crazygames.sh` | built, 39 files, about 18.6 MB |
| Independent review | code-reviewer | approve with comments, no Critical/High. The Medium findings were handled: the padding item was dropped (it broke the 11 px label minimum) and the zoom now resets on board end and heart loss. Low findings: clip only while zoomed, spec wording for haptic/compact/desktop wheel, and tests for the unmatched Flag-mode chord and the board end. |

Requirement coverage:

- Z1-Z3: `test/mobile_touch_zoom_test.dart` covers:
  - toggle per difficulty at 390x844;
  - zoom in, then long-press and tap on the cell under the finger;
  - zoom out;
  - reset on Restart, on a difficulty change and at board end.
- Z4-Z5: `test/quality_recovery_test.dart` (matched Flag-mode chord, hint text) and `test/mobile_touch_zoom_test.dart`
  (unmatched Flag-mode chord feedback).
- Z6: `test/mobile_touch_zoom_test.dart`, and `test/garden_run_screen_test.dart` / `test/garden_tools_screen_test.dart`
  (hearts read from `board-hearts`).
- Layout: `test/short_viewport_layout_test.dart` passes at all 12 sizes, with the zoom toggle on Hard boards.

Mutation check: with `zoomCellThreshold = 0`, 3 of the zoom tests fail.

Headless Chrome check of the CrazyGames build at 390x844 (dpr 2): Expert shows the toggle, the first dig works, and zoom in
centres the dug area with about 44 px cells.

Not verified: real phones (pinch on iOS Safari and Android Chrome, vibration) and the portal QA preview.
