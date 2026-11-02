# Verification: retention and polish (feature-retention-polish)

## Commands
- `flutter analyze`: no issues
- `flutter test`: all tests pass (art for every tile look x theme, progress/XP/daily/streak
  logic, store corruption fallback and legacy best-time migration, screen at 1280x720,
  1366x768, 390x844, 360x760, 844x390 and 800x600 without overflow, summary, daily, first click)
- `flutter test --platform chrome test/web`: pass (includes the CrazyGames settings listener)
- `flutter build web --release --base-href /TinyMines/`: built
- `tool/build_crazygames.sh`, `tool/build_gamepix.sh`: self-checks pass
- `node <harness-lab>/dist/index.js audit . --format md`: Critical 0

## Visual check
Temporary golden tests rendered the tile art sheet (4 themes), the wide and narrow
screens mid-run, the blast, loss summary, win bloom, win summary, garden sheet and the
tutorial; a headless Chrome (muted) screenshot of the GamePix build confirmed real-font
rendering at 1280x720. The temporary tests were deleted afterwards.

## First click investigation
No rule-level cause was found (`MineField.reveal` plants mines away from the first cell and
reveals it). The screen, however, ignored every pointer event until the first-run tutorial
check answered, so a returning player's very first tap on a slow storage read was dropped
silently. Board taps made during that window are now remembered and applied when the check
answers "seen" (and discarded if the tutorial opens). Covered by
`test/garden_screen_test.dart` ("first click" group).

## Not applicable
Tiny Mines has no ads, so pausing music around ads does not apply.
