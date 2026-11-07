# Tiny Mines quality recovery verification — 2026-11-07

## Outcome and scope

The rejected submission only supplied the generic overall-quality feedback; it did not identify an SDK failure. The recovery retains the garden art/genre and fixes reproduced first-session fairness and input weaknesses. No platform acceptance is claimed.

- Regular Easy remains6x6/5 with safe first-cell/neighborhood and now uses bounded visible-clue-solvable generation;48candidates then a verified fallback for each first cell. No instant first-reveal win. Normal/Hard/Daily default generation is unchanged.
- Dig/Flag tap modes preserve long press/right click. One visual eight-neighbor tutorial replaces three modal pages; contextual opening and chord feedback are visible.
- Inactivity pauses timer/events/music and suppresses delayed reward effects. Original daily-practice/accounting edits remain preserved.
- Separate title-only cover variants preserve all old media.

## Executed verification

| Check | Result |
|---|---|
| flutter analyze --no-pub | PASS, no issues |
| Final full VM test suite | PASS,150tests |
| Muted Chrome test/web, timeout60s | PASS,18tests |
| Pages release /TinyMines/ | PASS |
| CrazyGames build script/self-check | PASS,45files,31,210,383uncompressedbytes |
| GamePix build/self-check | PASS,44files;CrazyGames strings0 |
| Harness audit | PASS,Critical0,6existing workflow/backlink warnings |
| Harness verify/check-evidence | PASS; VM execution and source/log hashes recorded in build/quality-evidence/vm |
| git diff --check | PASS |

Generator checks:3,600generatedboards,720games by an independent visible-clue driver,36fallbacks,48attempt adversarial bound. Warmed VM worst-path average1.26ms/max2.77ms; physical mobile performance is not measured.

## Independent review

Entire working tree reviewed against67ff6496d5e4ab94d71ac46e7d2221405231a1d6, including preexisting daily practice and marketing scripts. One Medium finding (delayed summary reward SFX after blur) was fixed with a visibility guard and two regressions. Re-review:approve,no remaining findings. Later canonical Markdown heading/backlink formatting was a trivial documentation correction; separate code review was skipped for that formatting-only pass.

## Artifacts and limits

CandidateZIP,covers,metadata and detailed media provenance: `_marketing/TinyMines/quality-recovery-2026-11-07/` at the workspace root. Candidate source head is the base commit plus preserved working-tree changes; candidate.json records build-input and ZIP hashes. Native signing/device runs and subjective platform re-review remain outside these local checks. Current gameplay clips are complete:18.433seconds each, silent H.264,1920x1080 and1080x1620, matching title-only cover opening. Actual mouse inputs show safe opening, Dig/Flag switching and hints; a full clear is not claimed. Clock jumps are the unchanged +10second hint penalties, not video acceleration.

No duplicate-game submission or platform message was sent. The existing rejected game identity remains fccd2987-6b5f-49b3-9b77-100fa62e336a. Source is not committed/pushed, preserving the user's preexisting dirty work.

References used: feature-crazygames-quality-recovery and linked ADR, gameplay/tutorial/platform contracts, daily-practice spec/ADR, constraints/golden rules; official quality/game-cover guidance. Applied packs:none. Conflicts or gaps: existing harness workflow/backlink warnings and external re-review. Escalation:none.
