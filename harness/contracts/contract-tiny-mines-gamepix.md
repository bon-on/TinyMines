---
id: contract-tiny-mines-gamepix
title: Tiny Mines GamePix web distribution contract
status: active
related_specs:
  - feature-tiny-mines-gamepix
  - feature-short-viewport-layout
  - feature-next-goal-share
  - feature-game-feel-polish
evidence_files:
  - docs/gamepix.md
  - reports/tiny-mines-gamepix-verification.md
---

# Contract: Tiny Mines GamePix web distribution

## Goal
Produce an upload-ready, SDK-free GamePix web bundle from the same Flutter codebase.

## Scope
- `--dart-define=GAMEPIX=true` selects `NoopGamePlatform(allowsResultRegistration: false)` in `lib/platform/game_platform_factory_web.dart`.
- Bundled Roboto font (`assets/fonts/`), CSS loader in `web/index.html`.
- `tool/build_gamepix.sh` and `docs/gamepix.md`.

Excluded: gameplay changes, GamePix SDK, ads, portal upload.

## Done Criteria
- `flutter analyze`, `flutter test` and `flutter test --platform chrome test/web` pass.
- `tool/build_gamepix.sh` succeeds and its self-checks pass.
- `tool/build_crazygames.sh` and the GitHub Pages build still succeed.
- Results are recorded in `reports/tiny-mines-gamepix-verification.md`.

## Verification
```sh
flutter analyze
flutter test
flutter test --platform chrome test/web
tool/build_gamepix.sh
tool/build_crazygames.sh
node <harness-lab>/dist/index.js audit . --format md
```

## Evidence References
- docs/gamepix.md
- reports/tiny-mines-gamepix-verification.md
