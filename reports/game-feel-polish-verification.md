# Game feel polish verification (2026-11-11)

Spec: `feature-game-feel-polish`. Base: 6a3139c. No portal was contacted and nothing was submitted.

## Play audit (before)

Headless Chrome over CDP against a local GamePix-flavour release build, at 1280x720, 1366x768, 390x844 (DPR 2) and
844x390 (DPR 2). Screenshots were temporary and are not committed. Findings W1-W9 are listed in the spec. In short:
clues appeared without motion, Garden Run moments were status text only, the phone board shrank after the first dig,
the 844x390 board was about 190 px, 12x12 digits were about 10 px on a phone, the loader was a dark generic spinner,
and portal bundles carried about 14 MB of unused wasm engines.

## Changes

| Spec item | Change |
| --- | --- |
| G1 | Clue pebbles pop in (easeOutBack) after each cell's grass, following the ripple. |
| G2 | The dug mole jumps out of its hole with a squash. |
| G3 | Garden Run banners: stage start, boss start, stage clear, boss clear (+1 heart only when healed), first-time plot with its art and the new-best sound. |
| G4 | Status line and tip body reserve two lines; the board size no longer changes after the first dig. |
| G5 | Flag mode tints and glows the board frame. |
| G6 | Short landscape: Dig/Flag and a vertical difficulty picker left of the board; side columns scale instead of overflowing. |
| G7 | Larger clue share on small cells. |
| G8 | Sky-and-grass HTML loader with the tagline. |
| G9 | Portal build scripts delete `canvaskit/skwasm*` and `canvaskit/wimp*` after a renderer check. |

## Results (local)

| Check | Result |
| --- | --- |
| `flutter analyze` | no issues |
| `flutter test` | 258 passed (new: `test/game_feel_test.dart`, two banner tests in `test/garden_run_screen_test.dart`) |
| `flutter test --platform chrome test/web` | 20 passed |
| `tool/build_crazygames.sh` | passed; 39 files, 18,576 KB (was 45 files, about 30.6 MB) |
| `tool/build_gamepix.sh` | passed; 38 files, 18,560 KB, zip 7,240 KB; 0 `crazygames` / `bon-on.github.io` strings |
| Headless boot of both trimmed bundles | first frame in about 0.3-0.6 s on a warm local server; 14-15 requests, about 9.1 MB transferred (same as before; only `canvaskit/chromium/*` is fetched in Chrome) |
| Board at 844x390 | about 300 px (was about 190 px); 12x12 cells at least 18 px in the widget test |
| Board at 390x844, 12x12 | about 26 px cells, digits at 0.56 of the cell |

## Not verified

- Real phones (iOS Safari, Android Chrome) and touch feel; the headless runs used mouse events.
- Safari and Firefox load `canvaskit/canvaskit.wasm` (kept); booting the trimmed bundle was only checked in Chrome.
- Portal iframe behaviour, the CrazyGames QA tool and SDK mute in the portal.
- Covers and video in `../_marketing/TinyMines/` were left untouched.
