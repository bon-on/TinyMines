# Tiny Mines quality recovery: UI verification

Base: `67ff6496d5e4ab94d71ac46e7d2221405231a1d6`, current working tree including preserved preexisting daily-practice changes. No commit or push performed by this worker.

## Delivered behavior

- R1 integration: only regular Easy creates `MineField(requireLogicalSolution: true)`. Normal/Hard use the default policy; DailyChallenge construction remains unchanged.
- R2: visible labeled Dig/Flag controls, selected-state semantics, tap-to-flag, reset to Dig on every new field. Right-click and long press remain independent flag shortcuts. Flag mode cannot dig or chord revealed tiles.
- R3: one skippable visual card demonstrates the clue and all eight surrounding patches. Play/Skip/Escape preserve tutorial persistence. Untouched fields explain the safe first dig; active fields explain the current input mode.
- R4: an unmatched clue reports its visible number and the player's placed flag count, without inspecting hidden mines. Feedback clears after four seconds or another action; hints retain their existing budget and ten-second cost.
- R5: inactive/hidden/paused stop solve time, sound and gameplay events. Resuming does not bypass help/garden/results. Lifecycle changes rebuild control gates, including when a delayed storage reply rebuilt an untouched game while backgrounded.
- Existing daily-practice reward/storage work is retained. The old landscape summary test now scrolls its existing card before pressing View board, proving the close action actually receives input.

## Executed checks

All commands executed from the TinyMines repository root.

| Command | Exit | Result |
|---|---:|---|
| `flutter test --no-pub test/quality_recovery_test.dart test/garden_screen_test.dart test/game_platform_flow_test.dart test/how_to_play_test.dart test/sound_fx_test.dart test/best_time_test.dart --reporter expanded` | 0 | 90 tests passed before the final lifecycle-rebuild case |
| `flutter test --no-pub --reporter expanded` | 0 | 147 tests passed before the final lifecycle-rebuild case |
| `flutter test --no-pub test/quality_recovery_test.dart --reporter expanded` | 0 | final 10 quality widgets passed |
| `flutter analyze --no-pub` | 0 | final tree, no issues |
| `git diff --check` | 0 | no whitespace errors |

The ten quality widgets cover real taps, long press, secondary click, input-mode isolation, chord feedback timing, tutorial blocking, lifecycle event order, controlled elapsed time and audio pause/resume, delayed tutorial storage during backgrounding, and layouts 360x760, 390x844, 844x390, 1280x720. Existing layout tests also cover 1366x768 and 800x600, and daily-practice tests exercise retry/reload/midnight/reward behavior.

## Remaining coordinator checks

Run the final full integrated suite (expected 150 tests after the two audio regressions below, if no further tests are added), Chrome SDK tests, Pages/CrazyGames/GamePix builds, harness checks and independent review. This worker ran no headless Chrome and made no platform submission. General quality rejection does not identify these changes as the reviewer's exact requested fixes or guarantee acceptance.

References used: `feature-crazygames-quality-recovery`, linked quality-recovery/CrazyGames ADRs, gameplay/tutorial contracts, manifest, constraints and golden rules. Applied packs: none. Constraints: preserve existing daily data/rewards, no dependencies, English ASCII application strings, no source edits outside assigned ownership. Conflicts or gaps: coordinator verification and subjective platform QA remain. Escalation: none.


## Independent review follow-up: delayed effects during inactivity

A Medium R5 review finding identified that music respected app visibility but `SoundFx.play` did not. A win immediately followed by inactivity could therefore emit a delayed new-best/level-up sound when the result animation finished. `SoundFx.play` now also returns while the app is not visible.

- Added a direct regression for late effects while hidden, future effects after resume, and preservation of the user's mute preference.
- Added a widget regression that wins a real generated Easy board, backgrounds the app before the summary callback, advances the result animation, checks no reward effect was played, resumes, and confirms a new-field flag action makes sound again. This test uses the portal's result-registration-disabled policy so unrelated Pages registration dialogs cannot obscure its controls.
- `flutter test --no-pub test/sound_fx_test.dart test/quality_recovery_test.dart --reporter expanded`: exit 0, final 47 tests passed.
- `flutter analyze --no-pub`: exit 0, no issues.

No other production behavior was changed for this follow-up. Coordinator re-review and final integrated evidence remain required.
