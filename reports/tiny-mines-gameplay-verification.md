# Tiny Mines gameplay verification

Spec: `harness/specs/feature-tiny-mines-gameplay.md`

## Checks
- `flutter analyze`: no issues.
- `flutter test`: 13 tests pass, including `test/mine_field_test.dart`
  (first-reveal safety over 50 seeds, flag-then-tap before the first reveal,
  chord with correct and wrong flags, flag rules, hint candidate, win
  detection) and `test/hint_penalty_test.dart` (hint adds the time penalty).
- Added `test/best_time_test.dart`: best-time store, wrong flags, HUD best
  metric and Hard mine count (26). See flutter test output for totals.
- Harness audit: no critical findings.

## Not verified
- Right-click flagging and chord in a real desktop browser.
