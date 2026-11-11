---
id: contract-tiny-mines-crazygames
title: Tiny Mines CrazyGames web distribution contract
status: active
related_specs:
  - feature-tiny-mines-crazygames
  - feature-short-viewport-layout
  - feature-sound-effects
  - feature-retention-polish
  - feature-crazygames-cloud-save
  - feature-garden-run
  - feature-next-goal-share
  - feature-garden-collection
  - feature-game-feel-polish
evidence_files:
  - docs/crazygames.md
  - reports/tiny-mines-crazygames-verification.md
---

# Contract: Tiny Mines CrazyGames web distribution

## Goal
Produce an upload-ready CrazyGames web bundle from the same Flutter codebase.

## Scope
- `GamePlatform` interface, no-op implementation and `dart:js_interop` CrazyGames adapter under `lib/platform/`.
- Gameplay start/stop calls from the game screen on transitions.
- `tool/build_crazygames.sh` and `docs/crazygames.md`.

Excluded: gameplay changes, ads, portal upload. (Data/User modules are covered only for progress saving by `feature-crazygames-cloud-save`.)

## Done Criteria
- `flutter analyze`, `flutter test` and `flutter test --platform chrome test/web` pass.
- `tool/build_crazygames.sh` succeeds and its index.html checks pass.
- The GitHub Pages build contains no CrazyGames SDK script.
- Results are recorded in `reports/tiny-mines-crazygames-verification.md`.

## Verification
```sh
flutter analyze
flutter test
flutter test --platform chrome test/web
tool/build_crazygames.sh
flutter build web --release --base-href /TinyMines/
node <harness-lab>/dist/index.js audit . --format md
```

## Evidence References
- docs/crazygames.md
- reports/tiny-mines-crazygames-verification.md
