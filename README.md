# Tiny Mines

A compact minesweeper-style logic puzzle built with Flutter for iOS, Android, and web.

## Local Web Build

```sh
flutter build web --release --base-href /TinyMines/
```

GitHub Pages deploys from `.github/workflows/deploy-pages.yml`.

## CrazyGames Web Build

`tool/build_crazygames.sh` builds `build/crazygames/` and the upload zip `build/tiny-mines-crazygames.zip` (no hub link, leaderboard or ads; SDK gameplay events). See `docs/crazygames.md`.

## GamePix Web Build

`tool/build_gamepix.sh` builds `build/gamepix/` and the upload zip `build/tiny-mines-gamepix.zip` (SDK-free; no hub link, leaderboard or ads). See `docs/gamepix.md`. Roboto is bundled in `assets/fonts/` (see `assets/fonts/Roboto_LICENSE.txt`) so web builds make no font requests.

## Tutorial

A short how-to-play card appears on first launch (skip with Esc or the Skip button). The `?` button in the header reopens it.
