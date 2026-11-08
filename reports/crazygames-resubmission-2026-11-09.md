# CrazyGames resubmission candidate (2026-11-09)

Reviewer feedback on the rejected build: "The overall quality of the game does not yet meet the expectations of our
platform". The reviewed build predates Garden Run. This candidate targets first impression, distinctiveness and reasons to
replay. It does not claim to know the reviewer's exact reasons and cannot guarantee acceptance.

Specs: `feature-first-run-onboarding`, `feature-next-goal-share`, `feature-garden-collection` (plus the earlier
`feature-garden-run`). ADR: `adr-share-link-per-flavor`.

## Changes for reviewers

- The board is playable on the first frame. There is no modal on first launch. A short, dismissible tip strip explains the
  safe first dig and the numbers, then flags, then chording. The full how-to-play card is behind `?`.
- Garden Run is promoted with a "Try Garden Run: 3 hearts, bigger gardens" call to action. It shows on the first screen
  and on the result card until the first run is played. In a run, a mole costs a heart instead of the board, stages grow
  from 5x5 to 12x12, and boss gardens heal.
- The result card shows a Next goal: the next level and theme, the Garden Run target, or the closest garden plot. Its
  actions stay pinned on short screens.
- Copy result copies text only and never navigates anywhere:
  - in the CrazyGames build, the text includes the SDK `game.link` only when it is an https CrazyGames URL;
  - in the GamePix build, the text has no link.
- Garden plots: eight plots drawn in code, in two sets.
  - Run Path is earned by reaching Garden Run stages 2, 3, 5 and 7.
  - Daily Beds is earned by 1, 2, 4 and 7 scored daily clears.
  - Completing a set pays a one-time XP bonus.
  - Plots are saved in `garden_progress_v1`, which the Data module already syncs.

## Store text draft (ASCII)

Description:

> Dig a cozy garden, follow the number clues and clear every safe patch without waking a mole. Try Garden Run: three
> hearts carry you through ever bigger gardens, a mole costs a heart instead of the board, and boss gardens heal. Play the
> daily garden, grow your garden level, unlock seasonal themes and collect eight hand-drawn garden plots. Easy fields are
> checked to be solvable with logic.

Controls:

> Mouse or touch: choose Dig or Flag, then tap a patch. Right-click or long press also toggles a flag. Each number counts
> moles in all eight surrounding patches. Tap a revealed number after placing that many flags around it to open the
> remaining neighbors. Hints reveal a safe patch.

The covers and video in `../_marketing/TinyMines/` were not regenerated in this change (see "Not verified").

## Verification (local, HEAD of this change)

| Check | Result |
| --- | --- |
| `flutter analyze` | no issues |
| `flutter test` | 247 passed |
| `flutter test --platform chrome test/web` | 20 passed (including the share link from a fake `game.link`) |
| `tool/build_crazygames.sh` | passed; no `bon-on.github.io` in the bundled JS |
| `tool/build_gamepix.sh` | passed; 0 `crazygames` / `bon-on.github.io` strings in the bundled JS |
| `flutter build web --release --base-href /TinyMines/` | passed; `main.dart.js` contains the Pages link once |
| Harness audit | Critical 0; the 6 warnings were already present at 3e71242 |
| Layout | widget tests and temporary screenshots, not committed, at 390x844, 1280x720, 1366x768 and 844x390: first launch, after the first dig, result card and collection, all without overflow |
| Independent review | code-reviewer: no Critical or High findings; the Medium and Low notes are fixed |

## Not verified

- No real-browser or portal QA was run for this candidate: CrazyGames QA tool, clipboard inside the portal iframe, and
  `game.link` on the live portal.
- Covers, video and the portal listing were not updated. Nothing was uploaded.
- Mobile native builds (iOS/Android) were not built.
