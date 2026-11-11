# GamePix listing text (2026-11)

Text for the GamePix game form. ASCII only, English. It describes the GamePix
build (`tool/build_gamepix.sh`): no ads, no leaderboard, no result upload and
no outbound links.

## Description (447 / 500 characters, minimum 100)

```text
Tiny Mines is a cozy garden take on classic minesweeper. Dig patches, read the number pebbles and flag the hidden moles. Your first dig is always safe, and a short tip strip teaches the basics on your first board. Play Easy 6x6, Normal 9x9 or Hard 12x12, or try Garden Run: gardens grow from 5x5 to 12x12 and a mole costs one of your 3 hearts instead of the whole run. Clear the daily garden, earn XP, unlock garden themes and grow 8 garden plots.
```

## How to Play (478 / 500 characters)

```text
Tap a patch to dig. A number shows how many moles touch it, diagonals included. Flag a sure mole with right-click, long-press or Flag mode. Tap a number whose flags are all placed to dig the rest around it. Clear every safe patch to win. Stuck? The lightbulb hint reveals one safe patch (+10 s outside Garden Run). In Garden Run a mole costs a heart; clear the boss gardens at stages 5 and 10 to win one back. The daily garden gives one scored try a day, then unscored practice.
```

Lengths were counted with Python `len()` on the exact text above (no trailing
newline); both are pure ASCII.

## Fact check

| Claim | Source in the repo |
| --- | --- |
| First dig is always safe | `MineField` first reveal; status text "your first dig is safe" (`lib/main.dart`) |
| Tip strip on the first board | `feature-first-run-onboarding` (strip until closed or the first board ends) |
| Easy 6x6, Normal 9x9, Hard 12x12 | `lib/src/game/difficulty.dart` |
| Garden Run 5x5 to 12x12, 3 hearts, a mole costs a heart | `lib/src/game/garden_run.dart` (`_table`, `startHearts`), `feature-garden-run` |
| Boss gardens at stages 5 and 10 win a heart back | `GardenRun.bossStages`, status "Boss garden cleared! +1 heart." |
| Daily garden: one scored try a day, then practice | `feature-daily-practice`, `adr-daily-practice` |
| XP, theme unlocks | `garden_progress.dart`; themes Spring, Autumn (Lv 3), Winter (Lv 6), Night (Lv 10) |
| 8 garden plots | `lib/src/meta/garden_plots.dart` (Run Path 4 + Daily Beds 4) |
| Flag by right-click, long-press or Flag mode; chord on a number | `garden_board.dart` (`onSecondaryTap`, `onLongPress`), onboarding tip text |
| Hint reveals one safe tile, +10 s outside Garden Run | `_useHint`, `_hintPenaltySeconds` (`lib/main.dart`) |
| No ads, no leaderboard in this build | `feature-tiny-mines-gamepix` (no SDK, `allowsResultRegistration == false`) |

Not claimed on purpose: keyboard play, leaderboards, sharing links, cloud
saves (CrazyGames only), sound details.
