---
id: feature-tiny-mines-crazygames
title: Tiny Mines CrazyGames web distribution
status: active
owner: games
related_adrs:
  - adr-tiny-mines-crazygames-web
related_contracts:
  - contract-tiny-mines-crazygames
required_evidence:
  - flutter-tests
  - flutter-analyze
  - crazygames-web-build
  - harness-audit
---

# Feature: Tiny Mines CrazyGames web distribution

## Problem
The GitHub Pages build cannot be uploaded to the CrazyGames portal as is: the portal needs its HTML5 SDK v3 gameplay events, a relative-path bundle, and forbids outbound links.

## Scope
- Only a web bundle built with `--dart-define=CRAZYGAMES=true` uses the CrazyGames SDK. The default GitHub Pages build (`--base-href /TinyMines/`) and native builds keep a no-op platform and behave exactly as before.
- SDK events (`GamePlatform.gameplayStart` / `gameplayStop`), sent only on transitions:
  - start once the first-run tutorial check has answered and no overlay is open;
  - stop when the how-to-play overlay opens, start when it closes;
  - stop on game over / field cleared, start again on restart, new field or difficulty switch.
- SDK failures (script missing, `init()` rejects or hangs, environment `disabled`, call throws) downgrade to no-op and never break play.
- No outbound links in the CrazyGames bundle: the Bon-on hub navigation bar (`feature-game-hub-navigation`) and its reserved height are removed by the build script; the leaderboard prompt (`feature-post-game-leaderboard`) is skipped via `GamePlatform.allowsResultRegistration == false`.
- No ads of any kind in the CrazyGames bundle (Basic Launch forbids them). The game has no ad network.
- `tool/build_crazygames.sh` produces `build/crazygames/` and `build/tiny-mines-crazygames.zip` with `<base href="./">`, the SDK script before the Flutter loader, `*.symbols` removed, at most 1500 files and 50MB.

Out of scope: gameplay or rules changes, rewarded/banner ads, portal upload. (The Data/User modules were introduced later, only for progress saving, in `feature-crazygames-cloud-save`.)

## Acceptance Criteria
- `flutter analyze` and `flutter test` pass; `flutter test --platform chrome test/web` passes.
- The bundle `index.html` contains `<base href="./">` and `https://sdk.crazygames.com/crazygames-sdk-v3.js` exactly once, before the Flutter loader script.
- The bundle `index.html` has no `games-nav-bar` element and no `bon-on.github.io` link; the nav height variable is `0px`.
- The GitHub Pages build has no SDK script and still shows the hub navigation bar.
- Widget tests with a recording fake platform verify call order including the tutorial overlay, and that the leaderboard prompt is skipped when `allowsResultRegistration` is false and shown when true.
- `body` has `user-select: none` and touch rules in `web/index.html`.

## Constraints
- Gameplay must work offline without the SDK.
- No new pub dependencies (`dart:js_interop` only).
- Portal-specific code stays behind `GamePlatform`; game screens never import the CrazyGames adapter.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `tool/build_crazygames.sh`
- `node <harness-lab>/dist/index.js audit . --format md`
- `reports/tiny-mines-crazygames-verification.md`
