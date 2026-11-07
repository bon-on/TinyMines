# Garden Run verification

Spec: `feature-garden-run`. Local work only; no portal upload.

- `flutter analyze`: no issues
- `flutter test`: 187 passed (unit: stage table, hearts, hints, XP, progress JSON; widget: mole/heart, auto next stage, summary, XP once, layouts at 1280x720, 1366x768, 390x844 with a 12x12 board)
- `flutter test --platform chrome test/web`: passed
- `tool/build_crazygames.sh`, `tool/build_gamepix.sh`: self checks passed
- harness audit: Critical 0

Decisions: run hints carry no time penalty (run times are not ranked); a run reached stage counts the stage in play, or the cleared one when leaving during the celebration pause. Closing the tab mid-run pays nothing (no resume).

Not covered by tests: lifecycle pause during a run, leaving to the daily board, overlays open during auto-advance.
