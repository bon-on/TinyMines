# Short viewport layout - verification (2026-11-11)

Spec: `harness/specs/feature-short-viewport-layout.md`. Base commit: `62f0e6a`.

## Cause

`_buildGame` chose the side-panel layout only for width >= 760 and
width >= 1.25 x height. Every narrower landscape window (GamePix "Small"
620x349, 640x480, 667x375 ...) fell back to the one-column phone layout,
whose title, stats, difficulty, Garden Run entry, Dig/Flag, status and XP
footer rows need about 480 px around the board. Measured before the change
(widget tests, same states as below):

| Window | Board before | Problem |
|---|---|---|
| 620x349 | 0 px | RenderFlex overflow 69 px |
| 600x338 | 0 px | overflow 80 px |
| 560x315 | 0 px | overflow 103 px |
| 667x375 | 0 px | overflow 43 px |
| 640x480 | 63 px (Garden Run 9 px, first run 0 px) | first run overflow 14 px |
| 360x640 | 147 px first run, 169 px Garden Run (12 px cells at 12x12) | cramped |
| 320x568 | 79 px first run, 97 px Garden Run (6 px cells at 12x12) | unplayable at 12x12 |

The older GamePix check (`reports/tiny-mines-gamepix-verification.md`)
recorded 640x480 as fine; it was not (first run overflowed, the board was
63 px).

## Board size after the change (widget tests, px)

Board = framed board side. "12x12 cell" is the Hard cell, or for Garden Run
the cell a 12x12 stage gets in that box (every stage uses the same box).

| Window | Layout | First run (strip) | Easy | Hard (12x12 cell) | Garden Run (12x12 cell) |
|---|---|---|---|---|---|
| 620x349 | compact | 267 | 302 | 302 (20.2) | 279 (18.2) |
| 600x338 | compact | 256 | 282 | 282 (18.6) | 268 (17.3) |
| 560x315 | compact | 233 | 242 | 242 (15.5) | 242 (15.3) |
| 640x480 | compact | 322 | 322 | 322 (21.7) | 322 (21.6) |
| 667x375 | compact | 293 | 349 | 349 (23.9) | 305 (20.2) |
| 844x390 | wide (unchanged) | 298 | 310 | 310 (20.8) | 260 (16.7) |
| 932x430 | wide (unchanged) | 338 | 350 | 350 (23.9) | 300 (19.8) |
| 360x640 | stacked, folded | 336 | 336 | 336 (22.8) | 309 (20.5) |
| 390x844 | stacked (unchanged) | 351 | 366 | 366 (25.2) | 366 (25.0) |
| 320x568 | stacked, folded | 275 | 287 | 287 (19.0) | 237 (14.9) |
| 1280x720 | wide (unchanged) | 464 | 534 | 534 (38.5) | 484 (34.3) |
| 1366x768 | wide (unchanged) | 512 | 580 | 580 (42.4) | 532 (38.2) |

No Flutter error or overflow in any of the 48 cases. A real Garden Run
played to stage 10 (12x12 boss) in widget tests at 620x349, 560x315 and
320x568 has cells of at least 14 px and no overlap.

## Manual screenshots (not committed)

GamePix build (`tool/build_gamepix.sh`) served by `python3 -m http.server`
on 127.0.0.1, fresh headless Chrome per scenario (`--headless=new
--mute-audio`), CDP device metrics at all twelve sizes above. Taps were sent
with CDP mouse events at positions read from the Flutter semantics tree.
States: first launch (tip strip and "Try Garden Run"), returning player
(Garden Run entry button), an Easy board after the first dig, a Hard 12x12
board after the first dig, the result card after a lost Hard board, and a
Garden Run played by a small solver to stage 10 (12x12 boss board).

All 72 final shots (build at `e3f9b6a`) show the board first, no overlap or
overflow, Dig/Flag, the difficulty, Daily and Garden reachable, the strip
above the board, and the 12x12 cells tappable (the stage 10 boss board was
dug in the browser at every size). The result card shows "+N XP" and the
next goal above New Field on 620x349, 600x338 and 560x315 (no tile art
there). The compact run status reads "Stage 10 BOSS / Run m:ss" at full
size.

Known limits: on 560x315 the left and right columns scale to about 0.9;
the "Try Garden Run" subtitle is cut with an ellipsis in the slim column
(the full text is the semantics label); at 844x390 (wide, unchanged) the
side panels are small, as before.

## Checks

| Command | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 322 passed (incl. 58 in `short_viewport_layout_test.dart`) |
| `flutter test --platform chrome test/web` | 20 passed |
| `tool/build_gamepix.sh` | pass; `crazygames` strings in `main.dart.js`: 0; no `bon-on.github.io` |
| `tool/build_crazygames.sh` | pass |
| harness audit | Critical 0 (6 older warnings: agent entry files, maintenance.json, ADR backlinks of older specs) |

## Review

Independent code-reviewer on `a413cd5`: approve with comments, no Critical
or High. Medium findings fixed in `e3f9b6a`: the BOSS tag was about 7 px in
the short stacked meta row (now the hearts-free stage/clock status), the
difficulty labels were about 9 px at 320x568 (now name-only labels with the
full title as tooltip and semantics label, asserted >= 11 px), the slim
result card did not apply at 620x349/600x338 (threshold raised to a 320 px
card box), and the overlay test did not assert that the overlays opened
(now asserted; this exposed a test remount bug that was fixed). Low notes
accepted: 38-42 px tap targets in the compact and short layouts (above the
24 px WCAG 2.5.8 minimum), level badge hidden during a run on short stacked
windows (documented in the spec), slightly different entry labels between
layouts. Near-square desktop windows (for example 800x700) now get the
compact layout without the theme and XP panels; themes and level stay
reachable through the Garden overlay.

## Not verified

Real phones and tablets, Safari/iOS, Firefox, the real GamePix and
CrazyGames iframes (their preview chrome and safe areas), touch input on a
real device, keyboard-only play in the compact layout (focus reaches the
side columns after the board tiles), real audio output.
