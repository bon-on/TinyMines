# Verification: Expert garden

- Spec: `harness/specs/feature-expert-garden.md`; ADR `adr-tiny-mines-crazygames-web` (spec linked), contract `contract-tiny-mines-gameplay`.
- Date: 2026-11-14. Base: `3f08249`.

## What changed
- New `Difficulty.expert` (14x14, 40 moles, 4 hints, 300 XP per win).
- `lib/src/game/mine_logic.dart`: general guess-free solver (visible clues, shown mole total, subset rules, exhaustive search per frontier group of at most 28 cells).
- `lib/src/game/fair_field.dart`: draws layouts until the solver finishes the board (first cell and neighbours safe), at most 400 draws.
- `MineField(guessFree: true)` opt-in, used only for Expert. Easy keeps `requireLogicalSolution`; Normal, Hard, Garden Run and dated daily layouts do not use it.
- Picker has four segments (label padding 6 -> 2 so the full "Expert 14x14" title stays at least 11 px at 390 px); the vertical variant is four rows tall. Records lists Expert.

## Measurements
Solver success on random boards (VM, 300 boards per size, random first cell):
6x6/5 81%, 9x9/12 68%, 12x12/26 40%, 14x14/34 44%, 14x14/38 27%, 14x14/40 21%, 16x16/44 46%, 16x16/48 29%. One solve costs about 0.1 ms on the VM.
14x14/40 was chosen: the highest density that still tiles at about 25 px on a 390 px phone and still generates fast.

Expert generation in the Chrome (dart2js) test, 40 boards: 15.3 ms per board on average, worst 81 ms, 4.9 draws on average, all verified. Success rate implies the 400-draw bound is practically unreachable; if it ever were, the last layout is used and `guessFreeVerified` is false (not shown to the player).

## Checks run
| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No issues |
| `flutter test --no-pub` | 341 passed (new: `expert_garden_test.dart` with solver, generator, difficulty, progress and 5 layout sizes) |
| `flutter test --no-pub --platform chrome test/web` | 21 passed, including `expert_generation_test.dart` |
| `flutter build web --release --base-href /TinyMines/` | Built, no CrazyGames SDK in `index.html` |
| `tool/build_crazygames.sh`, `tool/build_gamepix.sh` | Built; self-checks passed |
| Local Chrome render of the CrazyGames build | Picker shows four segments, Records shows an Expert row, the Expert board is 14x14 with Mines 40 |

## Not verified
- Digging an Expert board in a real browser: the browser tool's clicks did not reach the Flutter tiles on any difficulty (Easy behaved the same), so tile taps were only verified by widget tests.
- Real phone feel: tiles are about 25 px wide at 390 px and 17 px on an 844x390 landscape window.
- Whether players want Expert, and whether guess-free Hard/Normal would help (not done, out of scope).
- Leaderboard offer: Expert wins are offered like every other difficulty (existing behaviour, only on the Pages build).
