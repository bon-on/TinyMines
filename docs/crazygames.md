# CrazyGames upload

A web build made with `--dart-define=CRAZYGAMES=true` uses the CrazyGames HTML5 SDK v3. Builds without that flag (GitHub Pages, mobile) never touch the SDK.

## Build

```sh
tool/build_crazygames.sh
```

Output:

- `build/crazygames/`: bundle folder
- `build/tiny-mines-crazygames.zip`: zip for the portal upload

The script runs `flutter build web --release --base-href / --no-web-resources-cdn --dart-define=CRAZYGAMES=true`, then:

1. sets `<base href="./">`;
2. inserts the SDK script before the Flutter loader (this shell uses an inline loader, not `flutter_bootstrap.js`);
3. removes the Bon-on hub navigation bar and sets its height to 0 (the portal forbids outbound links);
4. deletes `*.symbols`, checks at most 1500 files and 50MB, and zips the folder.

## Tests

```sh
flutter test                              # game flow with a fake platform (VM)
flutter test --platform chrome test/web   # SDK adapter against a fake window.CrazyGames
```

## Local check

```sh
cd build && python3 -m http.server 8765
# open http://localhost:8765/crazygames/index.html
```

On `localhost` the SDK environment is `local`; the console shows `Requesting gameplay start`/`stop` logs.

## SDK events

| When | Call |
|---|---|
| App start | `SDK.init()`; the SDK is disabled unless `environment` is `crazygames` or `local` |
| Tutorial check done, no overlay | `gameplayStart()` (first launch: only after the overlay closes) |
| How-to-play overlay opens | `gameplayStop()` |
| Overlay closes | `gameplayStart()` |
| Game over / field cleared | `gameplayStop()` |
| Restart, new field, difficulty switch | `gameplayStart()` |
| Garden Run: run starts / stage cleared | `gameplayStart()` (already active) / no call, the next stage follows without a stop |
| Garden Run: last heart lost | `gameplayStop()` |
| Garden Run: leave or restart | the run is paid out once; normal start/stop transitions apply |
| App inactive / hidden / paused | `gameplayStop()`; solve clock and music pause |
| App resumed with no help/garden/result overlay | `gameplayStart()`; active solve clock resumes |

Calls are sent on transitions only. Leaderboard registration prompts are disabled in this build, and there are no ads.

Sound: effects are muted while `SDK.game.settings.muteAudio` is true (read on every sound), in addition to the player's own sound toggle.

## Upload checklist

- [ ] Submit through Basic Launch (ads are off there).
- [ ] Orientation: both supported. Wide viewports show the garden and tools beside the board.
- [ ] Input: choose Dig or Flag, then click/tap a tile. Right click and long press always toggle a flag. Enter/Escape work on help/results; cells use pointer input.
- [ ] Updated title-only covers are prepared in `../_marketing/TinyMines/quality-recovery-2026-11-07/`: 1920x1080, 800x1200, 800x800.
- [ ] In the portal QA tool, check loading and gameplay events.
- [ ] Progress Save: set to "Yes, using the Data Module from the CrazyGames SDK".

## Known limits

- Progress is saved through the SDK Data module (`feature-crazygames-cloud-save`). On the portal submission form, set **Progress Save** to "Yes, using the Data Module from the CrazyGames SDK"; otherwise the Data module is disabled and progress stays in browser localStorage only.
  - All preferences go into one Data module key, `prefs_v1`, as `{rev, owner, values}`, and are mirrored to localStorage. The localStorage item `cg_prefs_stamp_v1` records the owner (username, null for guests) and revision of the local copy.
  - On start the local copy wins if it belongs to the same user and its revision is equal or higher; otherwise the account copy is used. Another user's local copy is never used. Progress from before this feature is adopted only when there is no account copy yet.
  - While cloud save is active, the page reloads (`user.addAuthListener`) only when the player changes
  to a different player or logs out. If the initial user cannot be determined, account saving is not enabled.
- The board is a square grid; Easy/Normal/Hard are selectable.
- Roboto is bundled (`assets/fonts/`), so the app does not fetch it from a Google font CDN.

## Quality recovery (2026-11-07)

The rejected build received a general quality comment, with no specific SDK defect identified. The recovery preserves the garden art and daily-practice data while improving first-session play:

- Regular Easy uses verified logic-solvable layouts after a safe first opening; Normal, Hard and fixed daily layouts retain their original generation.
- Visible Dig/Flag controls support tap-to-flag on touch screens. A selected mode never changes existing tiles; every new field starts in Dig.
- A single skippable visual help card demonstrates a number and its eight surrounding patches. An untouched field clearly says the first dig is safe.
- A number tapped with mismatched flags explains how many flags it needs and how many are placed. Existing hints still cost ten seconds.
- Losing app focus stops gameplay events, solve time, music and late sound effects until play can resume without an overlay.

Local checks and independent review are recorded in `reports/quality-recovery-ui.md` and the coordinator's final recovery report. Local verification does not claim platform acceptance or completed portal QA.
