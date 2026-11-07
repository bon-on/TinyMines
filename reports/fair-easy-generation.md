# Fair Easy generation verification

Base: `67ff6496d5e4ab94d71ac46e7d2221405231a1d6` with existing daily-practice changes preserved.

Requirement: R1 in `feature-crazygames-quality-recovery`; decision `adr-crazygames-quality-recovery`, gameplay contract and repository constraints/golden rules. Applied packs: none.

## Delivered

`MineField` has an opt-in `requireLogicalSolution` constructor flag, supported for regular Easy6x6/5 only. Default generation remains byte-for-byte in its old code path for daily seeds and other difficulties. The screen owns enabling the flag.

`FairEasyField` samples at most48 candidate placements, always excluding the first cell and its eight neighbors. An accepted candidate must leave safe cells to play after the opening and be finishable by visible-clue deductions (direct numbers, subset constraints and displayed total mine count). The proof's decision function receives no covered-cell truth. A virtual reveal reads a number only once its cell has been logically established safe. The proof never changes the real game's revealed/flagged state.

If sampling fails, one of36 preverified nonterminal emergency placements is selected for that opening, checked again before use. This catalog is independent of the RNG, returned by copy, and has exactly5 mines for every opening. It prevents infinite generation with a repetitive RNG. Existing reveal, flood, flag, chord, hint, loss and win rules are unchanged.

## Executed checks

- `dart format lib/mine_field.dart lib/fair_easy_field.dart test/fair_easy_field_test.dart` -> exit0.
- `flutter analyze --no-pub lib/mine_field.dart lib/fair_easy_field.dart test/fair_easy_field_test.dart` -> exit0, no issues.
- `flutter test --no-pub test/mine_field_test.dart test/fair_easy_field_test.dart --reporter expanded` -> exit0,16 tests passed (9 new policy tests and7 existing rule tests).
-3600 generated boards (all36 first cells x100 seeds): safe neighborhood, exact5 mines, nonterminal opening, proof finishes, no simulation leakage into the real flags.
-720 boards (all36 first cells x20 seeds): an independent player drives the real `MineField` reveal/flag API using only visible numbers and placed flags. It never reads a covered number or any cell's mine bit, and never calls the generator's proof solver. Every board completes without a hint or guess.
-All36 emergency layouts independently completed by the same visible-clue player. Caller mutation does not alter the catalog.
-Adversarial identity shuffle at opening0 exhausts exactly48 attempts (1488 bounded random calls) and uses a verified fallback.
-Reproduced old ambiguous seeds0,5,17 at opening21 are rejected by the new policy and their replacements independently complete.
-Accepted first candidates preserve the exact previous seeded placement. Default Easy/Normal/Hard placement matches legacy sampling; dated daily remains opted out.

A standalone VM timing sample (not a browser/device guarantee) measured100 warmed worst-path48-attempt fallbacks: average1.26ms, maximum2.77ms.1000 typical generated openings took162.7ms total. Timing script is a temporary local diagnostic, not a required runtime dependency.

## Limits / integration

Normal/Hard and Daily can still require guessing because their historical generation policy is deliberately preserved. Explicit `plantMinesAt` fixture layouts bypass generation policy. User mistakes or incorrectly placed flags can still cause a loss; no-guess means a logical solution exists from the safe opening, not that every move is safe. Full integrated app/web/portal checks and independent review are coordinator-owned. This work does not prove the exact subjective rejection reason or guarantee acceptance. No commits, pushes or portal changes performed.

Conflicts or gaps: no R1 implementation gap; broader R2-R6 integration remains coordinator-owned. Escalation: none.
