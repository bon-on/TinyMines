# Garden tools verification (2026-11-15)

Spec: `harness/specs/feature-garden-tools.md`. Base commit 351bd86 (pushed).

## Commands
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub` (twice): 364 tests passed (new: `test/garden_tools_test.dart`,
  `test/garden_tools_screen_test.dart`; existing run tests construct the screen with
  `gardenTools: false` because the picker now sits between stages).
- `flutter test --no-pub --platform chrome test/web`: 21 passed.
- `flutter build web --release --base-href /TinyMines/`: built.

## Review follow-up
Independent review: approve with comments (no Critical/High). Applied: the picker waits while the
How to play or Garden card is open and opens when it closes (it used to lose keyboard focus under
the card); spec and README now say the can cascades through empty tiles (the review measured
openings above 9 tiles in 18-70% of seeds); the offer may be fewer than three when few tools are
eligible; garden-run spec points to the picker; picker semantics merged and blocked behind the card;
new tests for the deferred picker, gameplay start/stop around the picker, XP/stage on leaving, and
1366x768. Fixes were not re-reviewed.

## Known gaps
- Not played by hand; tool balance (is any tool always the best pick?) is untested.
- Offers use `math.Random()` in production, so they are not reproducible between runs.
- Tool state is not saved: reloading a run never resumed anyway.
- The picker has no skip; a player who wants no tool still picks one.
- Not tested: chord digging two moles with one clover, the last heart with no clover under tools,
  an offer of one or zero tools on screen, the can winning a stage or skipping flags, a Hint as the
  first move (keeps the can for the next stage).
- Chord digging a mole while a clover is held is covered by the same code path as a tap but has no
  dedicated test.

## Can opens one tile at a time
Decision: the watering can no longer cascades. New `MineField.revealTile` opens exactly one safe,
unflagged tile; the can opens the safest tile and its safe neighbours (at most 3x3). Spec and README
updated. `flutter analyze` clean, 366 VM tests passed (2 new in `test/reveal_tile_test.dart`).
Small change, independent review skipped.
