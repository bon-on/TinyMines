---
id: feature-expert-garden
title: Expert garden, a larger guess-free difficulty
status: active
owner: games
related_adrs:
  - adr-tiny-mines-crazygames-web
  - adr-spec-driven-delivery
related_contracts:
  - contract-tiny-mines-gameplay
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - harness-audit
---

# Feature spec: Expert garden

## Problem
The hardest preset is Hard 12x12 with 26 moles (18% density), and Garden Run
ends on the same 12x12 board. Players who clear Hard have nothing harder to
play. Bigger random boards also force 50:50 guesses, which makes "harder" mean
"luckier". A guess-free generator exists only for Easy 6x6/5 moles.

## Scope
- New difficulty **Expert**: 14x14, 40 moles (20.4%), 4 hints. It is a
  normal difficulty: it appears in the picker, Records, best times and the
  result card ("Next: Expert" after Hard), and the share text title
  ("Expert 14x14").
- **Guess-free generation** for Expert: a general solver (`mine_logic.dart`)
  opens the first cell and then uses only visible information (opened
  numbers, deduced moles, the shown mole total, subset rules and exhaustive
  search per frontier group). Mole layouts are drawn at random (first cell and
  its neighbours safe) until the solver opens every safe cell, with a bounded
  number of attempts. If the bound is ever reached the last layout is used
  and a verified flag stays false; with the measured success rate this is not
  expected to happen (see Evidence).
- The opt-in is a new `MineField(guessFree: true)` flag. The existing
  `requireLogicalSolution` (Easy 6x6/5 with its verified fallback catalog),
  Normal and Hard boards, Garden Run boards and the dated daily layouts are
  unchanged.
- Win XP for Expert is 300 (Easy 30, Normal 70, Hard 150 unchanged). Hint
  rules, +10 s hint penalty, flag mode, chord and keyboard play are the same.
- The difficulty picker shows four segments; the vertical (short landscape)
  variant grows to four rows. Boards stay playable on 390x844 and 1280x720 and
  on the short-window layouts.
- Saved data: Expert uses the existing per-difficulty maps
  (`bestTimes`, `wins`, `plays` keyed by name). Old saves without Expert load
  as zero records; no migration.

## Acceptance Criteria
- Every Expert board generated for seeds 0..N from any first cell is solved
  by the solver from that opening, never needs a guess and is not solved by
  the opening alone. The solver never marks a safe cell as a mole or opens a
  mole.
- Expert is 14x14 with 40 moles and 4 hints; first reveal is never a mole and
  its neighbours are mole free; Easy/Normal/Hard sizes, mole counts, hints and
  generation are unchanged, and dated daily layouts are identical to before.
- Winning Expert records its best time, wins and plays under `expert`, pays
  300 XP and shows "Next: ..." only for difficulties that have a next one
  (Hard now leads to Expert, Expert has none).
- Old saves load; Records lists four rows; the picker and result card fit
  360x640, 390x844, 844x390, 1280x720 and 1366x768 without overflow.
- Generation of an Expert board finishes quickly: measured attempts and time
  are recorded in the verification report.

## Constraints
- No new dependencies, no network, ASCII lib strings.
- Garden Run, the daily and the leaderboard offer are not changed.
- Making Normal and Hard guess-free is a separate decision (not in scope).

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `flutter build web --release --base-href /TinyMines/`,
  `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- Measured solver success on random boards (VM, 300 boards each): 14x14/40 is
  guess-free in about 21% of draws at about 0.1 ms per attempt.
- `reports/expert-garden-verification.md`
