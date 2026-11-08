---
id: feature-next-goal-share
title: Next goal on the result card and a text-only Copy result
status: active
owner: games
related_adrs:
  - adr-share-link-per-flavor
  - adr-tiny-mines-crazygames-web
related_contracts:
  - contract-tiny-mines-gameplay
  - contract-tiny-mines-crazygames
  - contract-tiny-mines-gamepix
required_evidence:
  - flutter-analyze
  - flutter-tests
  - chrome-sdk-tests
  - crazygames-build
  - gamepix-build
  - harness-audit
  - independent-review
---

# Next goal and Copy result

## Problem

After a board or a Garden Run the result card shows XP and a level bar, but not what the player can reach next. Sister games
(MergeCamp `feature-next-goal-share`, NonoGrid daily copy) showed that a concrete next goal and a shareable result line
give a reason for one more play. Tiny Mines has neither.

## Scope

1. Next goal block (pure `nextGoals(GardenProgress)` in `lib/src/meta/next_goal.dart`, applied progress after the run):
   - level: XP missing to the next garden level; names the theme that level unlocks, if any;
   - theme: the next locked theme further away (not merged into the level goal);
   - Garden Run: first run ("Play your first Garden Run") or beating the best stage (reach best + 1);
   - garden plot (from `feature-garden-collection`): the closest unearned plot with N/total.
   Each goal has an estimated number of plays (XP goals: missing XP / 50; first run: 1; best stage: 2; plot: stages or daily
   clears still missing). The smallest is highlighted (ties: level, Garden Run, plot, theme). A Garden Run goal that asks for
   the same stage as the next run plot is dropped. Up to three goals are shown: the highlight with a title, a number line and a
   progress bar, the others as one short line each. All cases (max level themes unlocked, every plot earned) work.
2. Copy result button on the result card (not for unscored daily practice). Text only, English ASCII, no emoji:
   - regular board: `Tiny Mines - Easy 6x6` then `Cleared in 1:23 (best 1:10)` or `A mole won this time.`, then
     `Garden Lv N`;
   - daily: `Tiny Mines - Daily Garden 2026-11-09`, `Cleared in 1:05` or `A mole won today.`, `Streak: N days`;
   - Garden Run: `Tiny Mines - Garden Run`, `Reached stage S, cleared C gardens in m:ss`, `Hearts: H/3 | Best stage: B`;
   - a last line with the share link when the build has one (see the ADR); none otherwise.
   Copy uses Flutter's clipboard and, on web, a hidden textarea + `execCommand('copy')` fallback. The button shows "Copied!"
   or "Could not copy" for two seconds and never throws. Copying sends no network request, opens no page and does not change
   gameplay events.
3. Share link per build (`GamePlatform.shareLink`):
   - Pages and mobile: `https://bon-on.github.io/TinyMines/` (the documented Pages URL, `docs/pwa-github-pages.md`);
   - CrazyGames: the SDK `game.link` value only when it is an `https` URL on a CrazyGames host without port or user info,
     otherwise no link; the game never navigates to it;
   - GamePix: no link. The GamePix `main.dart.js` must contain neither `crazygames` nor `bon-on.github.io`;
     `tool/build_gamepix.sh` fails otherwise. `tool/build_crazygames.sh` fails if its `main.dart.js` contains
     `bon-on.github.io`.

## Acceptance Criteria

- B1: `nextGoals` returns the level goal with `xpForNextLevel - xpIntoLevel` missing XP and merges a theme unlocked at the next
  level; a farther theme is separate; ordering and ties are deterministic; finished collections and max-theme progress work.
- B2: The result card shows "Next goal" with the highlighted goal for regular, daily and Garden Run results, without overflow
  at 390x844, 1280x720, 1366x768 and 844x390 (the card scrolls on short screens).
- B3: Copy result puts the documented text on the clipboard for each result kind; Garden Run text includes the stage reached
  and the hearts; a clipboard failure shows "Could not copy" and nothing throws. Practice results have no Copy button.
- B4: Pages/mobile text ends with the Pages URL, GamePix text has no URL, CrazyGames uses only a valid CrazyGames `game.link`.
- B5: GamePix and CrazyGames build self-checks enforce the string rules above.

## Mapping

| Requirement | Files | Checks |
| --- | --- | --- |
| Goals | lib/src/meta/next_goal.dart, lib/src/ui/run_summary_overlay.dart | test/next_goal_test.dart, summary widget tests |
| Copy text and copier | lib/src/share/*.dart, lib/src/ui/run_summary_overlay.dart | test/result_share_test.dart |
| Links per build | lib/platform/*.dart, tool/build_*.sh | test/web/*, build self-checks |

## Constraints

No new packages, no network request, no ads, no leaderboard change, no gameplay rule change. English ASCII strings.

## Evidence

`flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`, both portal build scripts, harness audit,
independent review.
