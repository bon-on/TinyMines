---
id: adr-share-link-per-flavor
title: Choose the copied-result link per build flavor through GamePlatform
status: accepted
related_specs:
  - feature-next-goal-share
---

# Share link per build flavor

## Context

Copied results end with a link so friends can find the game. The three web builds have different rules: GitHub Pages may
point at its own page, CrazyGames forbids sending players off-portal, and GamePix forbids external links and must not contain
portal or Bon-on URLs at all.

## Decision

- `GamePlatform.shareLink` (nullable) supplies the link; the result text omits the line when it is null. The link is text
  only: the game never opens it.
- Pages and mobile use `NoopGamePlatform(shareLink: pagesShareLink)` with `https://bon-on.github.io/TinyMines/`.
- CrazyGames reads `CrazyGames.SDK.game.link` on demand and accepts it only as an `https` URL on a CrazyGames host (no port,
  no user info); anything else yields no link.
- GamePix uses a `NoopGamePlatform` without a link. The web factory selects the platform with compile-time constants in a
  single conditional expression so the Pages link and the CrazyGames adapter are tree-shaken from the GamePix bundle; the
  build script verifies `main.dart.js` contains neither `crazygames` nor `bon-on.github.io`.

## Consequences

Each portal keeps its link policy without runtime configuration. A change of the Pages URL or the SDK contract needs only
the constant or the adapter to change; the build checks catch leaks.
