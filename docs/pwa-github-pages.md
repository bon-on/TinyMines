# Tiny Mines PWA GitHub Pages

## URL

```text
https://bon-on.github.io/TinyMines/
```

## Local Build

```sh
flutter build web --release --base-href /TinyMines/
```

The workflow in `.github/workflows/deploy-pages.yml` runs tests, builds `build/web/`, and deploys with GitHub Pages Actions.
